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

from PySide6.QtCore import Qt, QModelIndex, QAbstractListModel, Qt, QByteArray, QStandardPaths, QFile, QDir, QProcess, QThread, Property
from PySide6.QtCore import QObject, Signal, Slot
from loguru import logger as logging
import os
import sys
import importlib
import copy
from pathlib import Path
import uuid
import subprocess
import glob
from dataclasses import dataclass
import typing
from dds_access.dispatcher import DispatcherThread
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration
import types
from PySide6.QtQml import qmlRegisterType
from models.data_tree_model import DataTreeModel, DataTreeNode
from utils.qml_utils import QmlUtils

import json


@dataclass
class ReaderData:
    id: str
    domainId: int
    topic_name: str
    topic_type: str
    qos: object
    stopped: bool


class ListenerModel(QAbstractListModel):
    IdRole = Qt.UserRole + 1
    TopicNameRole = Qt.UserRole + 2
    TopicTypeRole = Qt.UserRole + 3
    StoppedRole = Qt.UserRole + 4

    createEndpointSignal = Signal(str, int, str, str, int, str, object, object)

    def __init__(self, threads, parent=None):
        super().__init__(parent)

        self.threads = threads
        self.readers = {}

    def rowCount(self, parent=QModelIndex()):
        if parent.isValid():
            return 0
        return len(self.readers.keys())

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None

        _id = list(self.readers.keys())[index.row()]
        item = self.readers[_id]

        if role == self.IdRole:
            return _id
        if role == self.TopicNameRole:
            return item.topic_name
        if role == self.TopicTypeRole:
            return "Domain: " + str(item.domainId) + " | " + item.topic_type
        if role == self.StoppedRole:
            return item.stopped

        return None

    def setData(self, index, value, role=Qt.EditRole):
        if not index.isValid():
            return False

        item = self._items[index.row()]
        changed = False

        if role == self.CheckedRole:
            value = bool(value)
            if item.checked != value:
                item.checked = value
                changed = True

        if changed:
            self.dataChanged.emit(index, index, [role])
            return True

        return False

    def flags(self, index):
        if not index.isValid():
            return Qt.ItemIsEnabled
        return Qt.ItemIsEnabled | Qt.ItemIsSelectable | Qt.ItemIsEditable

    def roleNames(self):
        return {
            self.IdRole: b"readerId",
            self.TopicNameRole: b"topicName",
            self.TopicTypeRole: b"topicType",
            self.StoppedRole: b"stoppedReader"
        }

    @Slot(str)
    def deleteReader(self, _id: str):
        if _id in self.readers:
            logging.info(f"Delete reader {_id}")
            self.beginResetModel()
            del self.readers[_id]
            for key in self.threads:
                self.threads[key].deleteReader(_id)
            self.endResetModel()

    @Slot(str)
    def startReader(self, _id: str):
        if _id in self.readers:
            logging.info(f"Start reader {_id}")
            readItem = self.readers[_id]
            self.createEndpointSignal.emit(_id, readItem.domainId, readItem.topic_name, readItem.topic_type, 3, "", {}, copy.deepcopy(readItem.qos))
            self.beginResetModel()
            self.readers[_id].stopped = False
            self.endResetModel()

    @Slot(str)
    def stopReader(self, _id: str):
        if _id in self.readers:
            logging.info(f"Stop reader {_id}")
            for key in self.threads:
                self.threads[key].deleteReader(_id)
            self.beginResetModel()
            self.readers[_id].stopped = True
            self.endResetModel()

    @Slot()
    def stopAllReaders(self):
        logging.info(f"Stop all readers")
        for key in self.readers:
            if not self.readers[key].stopped:
                self.stopReader(key)

    @Slot()
    def startAllReaders(self):
        logging.info(f"Start all readers")
        for key in self.readers:
            if self.readers[key].stopped:
                self.startReader(key)

    @Slot()
    def deleteAllReaders(self):
        logging.info(f"Delete all readers")
        for key in self.threads:
            self.threads[key].deleteAllReaders()
        self.beginResetModel()
        self.readers.clear()
        self.endResetModel()

    @Slot(int, str, str, str, object)
    def addReader(self, id: str, domainId, topic_name, topic_type: str, qos):
        logging.info("AddReader to ListenerModel")
        self.beginResetModel()
        self.readers[id] = ReaderData(id, domainId, topic_name, topic_type, qos, False)
        self.endResetModel()
