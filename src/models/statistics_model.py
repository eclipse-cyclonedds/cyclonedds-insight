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

from dds_access.dds_utils import getProperty, DEBUG_MONITORS
import random


class StatisticsModel(QObject):
    newData = Signal(str, int, int, int, int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.dgbPorts = {}

        self.dds_data = dds_data.DdsData()
        self.dds_data.new_participant_signal.connect(self.new_participant_slot, Qt.ConnectionType.QueuedConnection)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.on_timeout)
        self.timer.start(1000)


    def download_json(self, url):
        try:
            response = requests.get(url)
            response.raise_for_status()
            parsed_json = response.json()
            # print("Received JSON:", json.dumps(parsed_json, indent=4))
            return parsed_json
        except requests.exceptions.RequestException as e:
            print("HTTP Request failed:", e)
        except json.JSONDecodeError as e:
            print("Invalid JSON received:", e)
        return None

    def normalize_guid(self, guid: str) -> str:
        if ':' in guid:
            parts = guid.split(':')
            guid = f"{parts[0]:0>8}-{parts[1][:4]}-{parts[1][4:]}-{parts[2][:4]}-{parts[2][4:]:0<8}{parts[3]:0>4}"
        print("GUID:", guid, len(guid))
        return guid

    @Slot()
    def on_timeout(self):
        logging.trace("Debug monitor timer triggered")
        for (ip, port) in self.dgbPorts.keys():
            json_data = self.download_json("http://" + ip + ":" + port + "/")
            if "participants" in json_data:
                for participant in json_data["participants"]:
                    if "writers" in participant:
                        for writer in participant["writers"]:
                            guid = self.normalize_guid(writer["guid"])
                            if "rexmit_bytes" in writer:
                                color = self.dgbPorts[(ip, port)][0]
                                self.newData.emit(guid, writer["rexmit_bytes"], color[0], color[1], color[2])


    @Slot(int, DcpsParticipant)
    def new_participant_slot(self, domain_id: int, participant: DcpsParticipant):
        dbg_mon_str: str = getProperty(participant, DEBUG_MONITORS)
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
