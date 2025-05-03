"""
 * Copyright(c) 2024 Sven Trittler
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0, or the Eclipse Distribution License
 * v. 1.0 which is available at
 * http://www.eclipse.org/org/documents/edl-v10.php.
 *
 * SPDX-License-Identifier: EPL-2.0 OR BSD-3-Clause
"""

from PySide6.QtCore import Qt, QModelIndex, QAbstractListModel, Qt, QByteArray, QStandardPaths, QFile, QDir, QProcess, QThread
from PySide6.QtCore import QObject, Signal, Slot
from loguru import logger as logging
import os
import sys
import importlib
import inspect
from pathlib import Path
import uuid
import subprocess
import glob
from dataclasses import dataclass
import typing
import requests
import json
from dds_access.dispatcher import DispatcherThread
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration
import types
from PySide6.QtQml import qmlRegisterType
from models.data_tree_model import DataTreeModel, DataTreeNode
from PySide6.QtCore import Qt, QAbstractTableModel, QModelIndex, QObject, Signal, Property, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from dds_access import dds_data

from PySide6.QtCore import Qt, QAbstractListModel, QModelIndex, QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QTimer
from cyclonedds.builtin import DcpsEndpoint, DcpsParticipant

from dds_access import dds_utils
from dds_access.dds_utils import getProperty, DEBUG_MONITORS, getAppName
import random
import colorsys
import time
from threading import Lock


class PollingThread(QThread):

    onData = Signal(object, object)

    def __init__(self, domainParticipant, parent=None):
        super().__init__()
        self.running = False
        self.mutex = Lock()
        self.color_mapping = {}
        self.pollIntervalSeconds = 3

    def getRandomColor(self):
        h = random.random()
        s = random.uniform(0.5, 1.0)  # not too gray
        v = random.uniform(0.7, 1.0)  # not too dark
        r, g, b = colorsys.hsv_to_rgb(h, s, v)
        return (int(r * 255), int(g * 255), int(b * 255))

    def download_json(self, url):
        try:
            print("Downloading JSON from:", url)
            response = requests.get(url, timeout=(5, 10))
            print("Response code:", response.status_code)
            response.raise_for_status()
            parsed_json = response.json()
            return parsed_json
        except requests.exceptions.RequestException as e:
            logging.error("HTTP Request failed: " + str(e))
        except json.JSONDecodeError as e:
            logging.error("Invalid JSON received: " + str(e))
        return []

    def setDbgPorts(self, dgbPorts):
        with self.mutex:
            self.dgbPorts = dgbPorts.copy()

    def poll(self):
        logging.trace("Debug monitor timer triggered")

        aggregated_data = {}
        for (ip, port, appName) in self.dgbPorts.values():
            json_data = []
            try:
                json_data = self.download_json("http://" + ip + ":" + port + "/")
            except Exception as e:
                logging.error("Error: " + str(e))
                continue

            if "participants" in json_data:
                for participant in json_data["participants"]:
                    participant_guid = dds_utils.normalizeGuid(participant["guid"])
                    if "writers" in participant:
                        for writer in participant["writers"]:
                            guid = dds_utils.normalizeGuid(writer["guid"])
                            topic = writer["topic"]
                            topc_guid = topic
                            if "rexmit_bytes" in writer:

                                if topc_guid not in self.color_mapping:
                                    self.color_mapping[topc_guid] = self.getRandomColor()

                                if topc_guid in aggregated_data:
                                    aggregated_data[topc_guid] += writer["rexmit_bytes"]
                                else:
                                    aggregated_data[topc_guid] = writer["rexmit_bytes"]

        self.onData.emit(aggregated_data.copy(), self.color_mapping.copy())

    def run(self):
        self.running = True

        start_time = time.monotonic()
        while self.running:
            
            if time.monotonic() - start_time >= self.pollIntervalSeconds:
                with self.mutex:
                    self.poll()
                start_time = time.monotonic()  # reset the timer
            else:
                time.sleep(0.1) # fast exit

        logging.trace("Statistics-Polling thread stopped")

    def stop(self):
        self.running = False

    def stillRunning(self):
        return self.running
    
    def setInterval(self, seconds):
        self.pollIntervalSeconds = seconds

class StatisticsModel(QAbstractTableModel):
    newData = Signal(str, int, int, int, int)

    requestParticipants = Signal(str, int)

    RoleGUID = Qt.UserRole + 1
    RoleRexmitBytes = Qt.UserRole + 2
    RoleColorR = Qt.UserRole + 3
    RoleColorG = Qt.UserRole + 4
    RoleColorB = Qt.UserRole + 5

    def roleNames(self):
        roles = {
            Qt.DisplayRole: b'display',
            self.RoleGUID: b'guid',
            self.RoleRexmitBytes: b'rexmit_bytes',
            self.RoleColorR: b'color_r',
            self.RoleColorG: b'color_g',
            self.RoleColorB: b'color_b',
        }
        return roles

    def __init__(self, parent=None):
        super().__init__(parent)
        self.dgbPorts = {}
        self.data_list = []

        self.pollingThread = PollingThread(self)
        self.pollingThread.onData.connect(self.onAggregatedData, Qt.ConnectionType.QueuedConnection)

        self.groupBy = ""

        self.dds_data = dds_data.DdsData()
        self.requestParticipants.connect(self.dds_data.requestParticipants, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_participant_signal.connect(self.new_participant_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.response_participants_signal.connect(self.response_participants_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_participant_signal.connect(self.removed_participant_slot, Qt.ConnectionType.QueuedConnection)

        self.timer = None
        self.domainId = None
        self.request_ids = []

    @Slot(int, str)
    def startStatistics(self, domainId: int, groupBy: str):

        logging.info("Start statistics model" + str(domainId) + " " + groupBy)

        self.groupBy = groupBy
        self.domainId = domainId

        if self.pollingThread.isRunning():
            self.pollingThread.stop()
            self.pollingThread.wait()

        self.pollingThread.setDbgPorts(self.dgbPorts)
        self.pollingThread.start()

        reqId = str(uuid.uuid4())
        self.request_ids.append(reqId)
        self.requestParticipants.emit(reqId, self.domainId)

    def rowCount(self, parent=QModelIndex()):
        return len(self.data_list)

    def columnCount(self, parent=QModelIndex()):
        return 2  # guid, rexmit_bytes, color_r, color_g, color_b

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()
        if row >= len(self.data_list):
            return None
        item = self.data_list[row]
        if role == self.RoleGUID:
            return item[0]
        elif role == self.RoleRexmitBytes:
            return item[1]
        elif role == self.RoleColorR:
            return item[2]
        elif role == self.RoleColorG:
            return item[3]
        elif role == self.RoleColorB:
            return item[4]
        elif role == Qt.DisplayRole:
            column = index.column()
            return item[column]
        return None

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if role != Qt.DisplayRole:
            return None
        if orientation == Qt.Horizontal:
            headers = ["Name", "Rexmit Bytes", "Color R", "Color G", "Color B"]
            if section < len(headers):
                return headers[section]
        return None

    @Slot(object, object)
    def onAggregatedData(self, aggregated_data, color_mapping):
        logging.debug("New data received: " + str(len(aggregated_data)))
        self.beginResetModel()
        self.data_list.clear()
        for topc_guid in aggregated_data.keys():
            value = aggregated_data[topc_guid]
            (r, g, b) = color_mapping[topc_guid]
            self.newData.emit(topc_guid, value, r, g, b)
            self.data_list.append([topc_guid, value, r, g, b])
        self.endResetModel()

    @Slot(int, DcpsParticipant)
    def new_participant_slot(self, domain_id: int, participant: DcpsParticipant):

        if self.domainId != domain_id:
            return

        dbg_mon_str: str = getProperty(participant, DEBUG_MONITORS)
        appName = getAppName(participant)

        splitProtoAdr = dbg_mon_str.split("/")
        if len(splitProtoAdr) > 0:
            if splitProtoAdr[0] == "tcp":
                splitIpPort = splitProtoAdr[1].split(":")
                if len(splitIpPort) > 1:
                    ip = splitIpPort[0]
                    port = splitIpPort[1]
                    print("IP:", ip, "Port:", port)
                    self.dgbPorts[str(participant.key)] = (ip, port, appName)

        self.pollingThread.setDbgPorts(self.dgbPorts)

    @Slot(str, int, object)
    def response_participants_slot(self, request_id: str, domain_id: int, participants):

        if self.domainId != domain_id or request_id not in self.request_ids:
            return

        logging.debug(f"Statistics response aprticipants: req-id: {request_id}, Domain: {domain_id}, Participants: {len(participants)}")

        for participant in participants:
            self.new_participant_slot(domain_id, participant)

        self.request_ids.remove(request_id)

    @Slot(int, str)
    def removed_participant_slot(self, domain_id: int, participant_key: str):
        if self.domainId != domain_id:
            return

        if participant_key in self.dgbPorts:
            del self.dgbPorts[participant_key]
        
        self.pollingThread.setDbgPorts(self.dgbPorts)

    @Slot()
    def stop(self):
        logging.trace("Stop statistics model")
        if self.pollingThread:
            if self.pollingThread.stillRunning():
                self.pollingThread.stop()
                self.pollingThread.wait()

    @Slot(int)
    def setUpdateInterval(self, interval: int):
        logging.trace(f"Set update interval to {interval}")
        self.pollingThread.setInterval(interval)
