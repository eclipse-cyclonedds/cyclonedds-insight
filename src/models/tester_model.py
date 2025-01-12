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
from dds_access.dispatcher import DispatcherThread
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration
import types
from PySide6.QtQml import qmlRegisterType
from models.data_tree_model import DataTreeModel, DataTreeNode

@dataclass
class DataModelItem:
    id: str
    parts: dict


class TesterModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1
    DataModelRole = Qt.UserRole + 2

    showQml = Signal(str, str)

    writeDataSignal = Signal(str, object)

    def __init__(self, threads, dataModelHandler, parent=QObject()):
        super().__init__()
        self.dataModelHandler = dataModelHandler
        self.dataWriters = {}
        self.threads = threads
        self.alreadyConnectedDomains = []

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()

        (domainId, topic_name, _, _, _, dataModel) = self.dataWriters[list(self.dataWriters.keys())[row]]

        if role == self.NameRole:
            return f"Domain Id: {str(domainId)}, Topic Name: {topic_name}"
        if role == self.DataModelRole:
            return dataModel

        return None

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            self.NameRole: b'name',
            self.DataModelRole: b'dataModel'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return len(self.dataWriters.keys())

    @Slot(int, result=DataTreeModel)
    def getTreeModel(self, currentIndex: int) -> DataTreeModel:
        if currentIndex < 0:
            return
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, _, _, _, dataTreeModel) = self.dataWriters[mId]
        return dataTreeModel

    @Slot(int, str, str, str, str, str)
    def addWriter(self, id: str, domainId, topic_name, topic_type, qmlCode, pyCode):
        logging.info("AddWriter to TesterModel")

        self.beginResetModel()

        if domainId not in self.alreadyConnectedDomains:
            self.writeDataSignal.connect(self.threads[domainId].write, Qt.ConnectionType.QueuedConnection)
            self.alreadyConnectedDomains.append(domainId)

        rootNode = self.dataModelHandler.getRootNode(topic_type)
        dataTreeModel = DataTreeModel(rootNode, parent=self)
        self.dataWriters[id] = (domainId, topic_name, topic_type, qmlCode, None, dataTreeModel)

        self.endResetModel()

    @Slot(int, QModelIndex)
    def addArrayItem(self, currentIndex: int, currentTreeIndex: QModelIndex):
        logging.debug("Add Array Item")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, topic_type, _, _, dataTreeModel) = self.dataWriters[mId]
        if currentTreeIndex.isValid():
            item: DataTreeNode = currentTreeIndex.internalPointer()
            if item.itemArrayTypeName:
                itemNode = self.dataModelHandler.toNode(item.itemArrayTypeName, DataTreeNode("", "Array Element", DataTreeModel.IsSequenceElementRole, parent=item))
                dataTreeModel.addArrayItem(currentTreeIndex, itemNode)

    @Slot(int, QModelIndex)
    def removeArrayItem(self, currentIndex: int, currentTreeIndex: QModelIndex):
        logging.debug("Remove Array Item")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, topic_type, _, _, dataTreeModel) = self.dataWriters[mId]
        dataTreeModel.removeArrayItem(currentTreeIndex)

    @Slot(int)
    def showTester(self, currentIndex: int):
        if currentIndex < 0 and len(list(self.dataWriters.keys())) == 0:
            return
        logging.debug(f"Show Tester {str(currentIndex)}")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (domainId, topic_name, topic_type, qmlCode, mt, _) = self.dataWriters[mId]
        self.showQml.emit(mId, qmlCode)

    @Slot(int)
    def writeData(self, currentIndex: int):
        logging.debug(f"Write Data {str(currentIndex)}")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, _, _, _, dataTreeModel) = self.dataWriters[mId]
        self.writeDataSignal.emit(mId, dataTreeModel.getDataObj())

    @Slot()
    def deleteAllWriters(self):
        self.beginResetModel()
        self.dataWriters.clear()
        for key in self.threads.keys():
            self.threads[key].deleteAllWriters()
        self.endResetModel()
