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
import logging
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
from dds_service import WorkerThread
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration
import types
from PySide6.QtQml import qmlRegisterType

@dataclass
class DataModelItem:
    id: str
    parts: dict


class TesterModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    newDataArrived = Signal(str)
    isLoadingSignal = Signal(bool)

    showQml = Signal(str, str)

    def __init__(self, threads, parent=QObject | None) -> None:
        super().__init__()
        self.dataWriters = {}
        self.threads = threads

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> typing.Any:
        if not index.isValid():
            return None
        row = index.row()

        (domainId, topic_name, _, _, _) = self.dataWriters[list(self.dataWriters.keys())[row]]

        if role == self.NameRole:
            return f"Domain Id: {str(domainId)}, Topic Name: {topic_name}"
        elif False:
            pass

        return None

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            self.NameRole: b'name'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return len(self.dataWriters.keys())

    @Slot(int, str, str, str, str)
    def addWriter(self, domainId, topic_name, topic_type, qmlCode, pyCode):
        logging.info("AddWriter to TesterModel")
        self.beginResetModel()

        id = str(uuid.uuid4())

        module_name = id
        new_module = types.ModuleType(module_name)
        exec(pyCode, new_module.__dict__)

        mt = new_module.DataWriterModel(topic_name)
        mt.writeDataSignal.connect(self.threads[domainId].write, Qt.ConnectionType.QueuedConnection)
        
        self.dataWriters[id] = (domainId, topic_name, topic_type, qmlCode, mt)
        self.endResetModel()

    @Slot(int)
    def showTester(self, currentIndex: int):
        if currentIndex < 0 and len(list(self.dataWriters.keys())) == 0:
            return
        logging.debug(f"Show Tester {str(currentIndex)}")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (domainId, topic_name, topic_type, qmlCode, mt) = self.dataWriters[mId]
        self.showQml.emit(mId, qmlCode)

    @Slot(str, list)
    def write(self, mId, params):
        logging.debug("call write")
        print(*params)
        if mId in self.dataWriters:
            (_, _, _, _, mt) = self.dataWriters[mId]
            mt.write(*params)

    @Slot()
    def deleteAllWriters(self):
        self.beginResetModel()
        self.dataWriters.clear()
        self.endResetModel()