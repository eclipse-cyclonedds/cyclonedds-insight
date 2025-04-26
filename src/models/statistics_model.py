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

from dds_access.dds_utils import getProperty, DEBUG_MONITORS, getAppName
import random


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
        self.color_mapping = {}

        self.groupBy = ""

        self.dds_data = dds_data.DdsData()
        self.requestParticipants.connect(self.dds_data.requestParticipants, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_participant_signal.connect(self.new_participant_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.response_participants_signal.connect(self.response_participants_slot, Qt.ConnectionType.QueuedConnection)

        self.timer = None
        self.domainId = None
        self.request_ids = []

    @Slot(int, str)
    def startStatistics(self, domainId: int, groupBy: str):

        logging.info("Start statistics model" + str(domainId) + " " + groupBy)

        self.groupBy = groupBy
        self.domainId = domainId

        if self.timer:
            if self.timer.isActive():
                self.timer.stop()

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.on_timeout)
        self.timer.start(1000)

        reqId = str(uuid.uuid4())
        self.request_ids.append(reqId)
        self.requestParticipants.emit(reqId, self.domainId)

    def rowCount(self, parent=QModelIndex()):
        return len(self.data_list)

    def columnCount(self, parent=QModelIndex()):
        return 2  # guid, rexmit_bytes, color_r, color_g, color_b

    def getRandomColor(self):
        r = random.randint(0, 255)
        g = random.randint(0, 255)
        b = random.randint(0, 255)
        return (r, g, b)

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
            headers = ["GUID", "Rexmit Bytes", "Color R", "Color G", "Color B"]
            if section < len(headers):
                return headers[section]
        return None

    def download_json(self, url):
        try:
            response = requests.get(url)
            response.raise_for_status()
            parsed_json = response.json()
            return parsed_json
        except requests.exceptions.RequestException as e:
            print("HTTP Request failed:", e)
        except json.JSONDecodeError as e:
            print("Invalid JSON received:", e)
        return []

    def normalize_guid(self, guid: str) -> str:
        if ':' in guid:
            parts = guid.split(':')
            guid = f"{parts[0]:0>8}-{parts[1][:4]}-{parts[1][4:]}-{parts[2][:4]}-{parts[2][4:]:0<8}{parts[3]:0>4}"
        #logging.trace(f"Normalized GUID: {guid}, len: {len(guid)}")
        return guid

    @Slot()
    def on_timeout(self):
        # logging.trace("Debug monitor timer triggered")

        aggregated_data = {}
        for (ip, port) in self.dgbPorts.keys():
            json_data = self.download_json("http://" + ip + ":" + port + "/")
            if "participants" in json_data:
                for participant in json_data["participants"]:
                    participant_guid = self.normalize_guid(participant["guid"])
                    if "writers" in participant:
                        for writer in participant["writers"]:
                            guid = self.normalize_guid(writer["guid"])
                            topic = writer["topic"]
                            topc_guid = topic
                            if "rexmit_bytes" in writer:

                                if topc_guid in self.color_mapping:
                                    r, g, b = self.color_mapping[topc_guid]
                                else:
                                    self.color_mapping[topc_guid] = self.getRandomColor()

                                if topc_guid in aggregated_data:
                                    aggregated_data[topc_guid] += writer["rexmit_bytes"]
                                else:
                                    aggregated_data[topc_guid] = writer["rexmit_bytes"]

        # Update the model with the aggregated data
        self.beginResetModel()
        self.data_list.clear()
        for topc_guid in aggregated_data.keys():
            value = aggregated_data[topc_guid]
            (r, g, b) = self.color_mapping[topc_guid]
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
                    if (ip, port) in self.dgbPorts.keys():
                        if participant.key not in self.dgbPorts[(ip, port)]:
                            self.dgbPorts[(ip, port)][1].append(participant.key)
                    else:
                        r = random.randint(0, 255)
                        g = random.randint(0, 255)
                        b = random.randint(0, 255)
                        self.dgbPorts[(ip, port)] = [(r, g, b), [participant.key]]


    @Slot(str, int, object)
    def response_participants_slot(self, request_id: str, domain_id: int, participants):

        if self.domainId != domain_id or request_id not in self.request_ids:
            return

        logging.debug(f"Statistics response aprticipants: req-id: {request_id}, Domain: {domain_id}, Participants: {len(participants)}")

        for participant in participants:
            self.new_participant_slot(domain_id, participant)

        self.request_ids.remove(request_id)
