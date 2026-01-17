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
from dds_access.dispatcher import DispatcherThread
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration
import types
from PySide6.QtQml import qmlRegisterType
from models.data_tree_model import DataTreeModel, DataTreeNode
from utils.qml_utils import QmlUtils

import json


@dataclass
class DataModelItem:
    id: str
    parts: dict


class TesterModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1
    DataModelRole = Qt.UserRole + 2
    PresetNameRole = Qt.UserRole + 3

    showQml = Signal(str, str)

    writeDataSignal = Signal(str, object)
    disposeDataSignal = Signal(str, object)
    unregisterDataSignal = Signal(str, object)

    requestQosJsonSignal = Signal(str, str)

    def __init__(self, threads, dataModelHandler, parent=QObject()):
        super().__init__()
        self.dataModelHandler = dataModelHandler
        self.dataWriters = {}
        self.threads = threads
        self.alreadyConnectedDomains = []
        self.pendingQosRequests = {}
        self.exportCount = None
        self.currentExportCount = 0
        self.resetExportData()

    def resetExportData(self):
        self.exportData = { "presets": [] }

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()

        (domainId, topic_name, _, _, _, dataModel, presentName) = self.dataWriters[list(self.dataWriters.keys())[row]]

        if role == self.NameRole:
            return f"{presentName}, Topic: {topic_name}, Domain: {str(domainId)}"
        if role == self.DataModelRole:
            return dataModel
        if role == self.PresetNameRole:
            return presentName

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
        (_, _, _, _, _, dataTreeModel, _) = self.dataWriters[mId]
        return dataTreeModel

    @Slot(int, result=str)
    def getPresetName(self, currentIndex: int) -> str:
        if currentIndex < 0:
            return
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, _, _, _, _, presetName) = self.dataWriters[mId]
        return presetName

    @Slot(int, str)
    def setPresetName(self, currentIndex: int, presetName: str):
        if currentIndex < 0:
            return
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (domainId, topic_name, topic_type, qmlCode, mt, dataTreeModel, _) = self.dataWriters[mId]
        self.dataWriters[mId] = (domainId, topic_name, topic_type, qmlCode, mt, dataTreeModel, presetName)
        idx = self.index(currentIndex)
        self.dataChanged.emit(idx, idx, [self.PresetNameRole, self.NameRole])

    @Slot(int, str, str, str, str, str, str, object)
    def addWriter(self, id: str, domainId, topic_name, topic_type, qmlCode, pyCode, presetName, msgDict):
        logging.info("AddWriter to TesterModel")

        self.beginResetModel()

        if domainId not in self.alreadyConnectedDomains:
            self.writeDataSignal.connect(self.threads[domainId].write, Qt.ConnectionType.QueuedConnection)
            self.disposeDataSignal.connect(self.threads[domainId].dispose, Qt.ConnectionType.QueuedConnection)
            self.unregisterDataSignal.connect(self.threads[domainId].unregisterInstance, Qt.ConnectionType.QueuedConnection)
            self.requestQosJsonSignal.connect(self.threads[domainId].requestQosJson, Qt.ConnectionType.QueuedConnection)
            self.threads[domainId].responseQosJson.connect(self.receiveQosJson, Qt.ConnectionType.QueuedConnection)
            self.alreadyConnectedDomains.append(domainId)

        rootNode = self.dataModelHandler.getRootNode(topic_type)
        dataTreeModel = DataTreeModel(rootNode, parent=self)
        self.dataWriters[id] = (domainId, topic_name, topic_type, qmlCode, None, dataTreeModel, presetName)

        if len(msgDict.keys()) > 0:
            dataTreeModel.fromJson(msgDict, self.dataModelHandler)

        self.endResetModel()

    @Slot(int, QModelIndex)
    def addArrayItem(self, currentIndex: int, currentTreeIndex: QModelIndex):
        logging.debug("Add Array Item")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, topic_type, _, _, dataTreeModel, _) = self.dataWriters[mId]
        if currentTreeIndex.isValid():
            item: DataTreeNode = currentTreeIndex.internalPointer()
            if item.itemArrayTypeName:
                targetRole = DataTreeModel.IsSequenceElementRole
                if item.role == DataTreeModel.IsOptionalRole:
                    targetRole = DataTreeModel.IsOptionalElementRole
                itemNode = self.dataModelHandler.toNode(item.itemArrayTypeName, DataTreeNode("", "", targetRole, parent=item))
                dataTreeModel.addArrayItem(currentTreeIndex, itemNode)
            elif item.parentItem.itemArrayTypeName:
                itemNode = self.dataModelHandler.toNode(item.parentItem.itemArrayTypeName, DataTreeNode("", "", DataTreeModel.IsSequenceElementRole, parent=item))
                itemNode.itemArrayTypeName = item.parentItem.itemArrayTypeName
                dataTreeModel.addArrayItem(currentTreeIndex, itemNode)
            else:
                logging.warning("itemArrayTypeName not set")
        else:
            logging.warning("currentTreeIndex not valid")

    @Slot(int, QModelIndex)
    def removeArrayItem(self, currentIndex: int, currentTreeIndex: QModelIndex):
        logging.debug("Remove Array Item")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, topic_type, _, _, dataTreeModel, _) = self.dataWriters[mId]
        dataTreeModel.removeArrayItem(currentTreeIndex)

    @Slot(int)
    def showTester(self, currentIndex: int):
        if currentIndex < 0 and len(list(self.dataWriters.keys())) == 0:
            return
        logging.trace(f"Show Tester pressed on index: {str(currentIndex)}")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (domainId, topic_name, topic_type, qmlCode, mt, _, _) = self.dataWriters[mId]
        self.showQml.emit(mId, qmlCode)

    @Slot(int)
    def writeData(self, currentIndex: int):
        logging.trace(f"Write Data pressed on index: {str(currentIndex)}")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, _, _, _, dataTreeModel, _) = self.dataWriters[mId]
        self.writeDataSignal.emit(mId, dataTreeModel.getDataObj())

    @Slot(int)
    def disposeData(self, currentIndex: int):
        logging.trace(f"Dispose Data pressed on index: {str(currentIndex)}")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, _, _, _, dataTreeModel, _) = self.dataWriters[mId]
        self.disposeDataSignal.emit(mId, dataTreeModel.getDataObj())

    @Slot(int)
    def unregisterData(self, currentIndex: int):
        logging.trace(f"Unregister Data pressed on index: {str(currentIndex)}")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        (_, _, _, _, _, dataTreeModel, _) = self.dataWriters[mId]
        self.unregisterDataSignal.emit(mId, dataTreeModel.getDataObj())

    @Slot()
    def deleteAllWriters(self):
        self.beginResetModel()
        self.dataWriters.clear()
        for key in self.threads.keys():
            self.threads[key].deleteAllWriters()
        self.endResetModel()

    @Slot(int)
    def deleteWriter(self, currentIndex: int):
        if currentIndex < 0:
            return
        logging.trace(f"Delete Writer pressed on index: {str(currentIndex)}")
        mId = list(self.dataWriters.keys())[int(currentIndex)]
        self.beginResetModel()
        del self.dataWriters[mId]
        for key in self.threads.keys():
            self.threads[key].deleteWriter(mId)
        self.endResetModel()

    @Slot(str, int)
    def exportJson(self, filePath, currentIndex: int):
        if currentIndex < 0:
            return
        self.exportCount = 1
        self.currentExportCount = 0
        self._exportJsonItem(filePath, currentIndex)

    @Slot(str)
    def exportJsonAll(self, filePath):
        self.exportCount = len(list(self.dataWriters.keys()))
        self.currentExportCount = 0
        for index, _ in enumerate(list(self.dataWriters.keys())):
            self._exportJsonItem(filePath, index)

    def _exportJsonItem(self, filePath, currentIndex: int):
        if currentIndex < 0:
            return
        mId = list(self.dataWriters.keys())[int(currentIndex)]

        reqId = str(uuid.uuid4())
        self.pendingQosRequests[reqId] = (mId, filePath)
        self.requestQosJsonSignal.emit(reqId, mId)

    @Slot(str, object)
    def receiveQosJson(self, requestId: str, content: dict):
        logging.info(f"Received qos json for requestId {requestId}")
        if requestId in self.pendingQosRequests.keys():
            self.currentExportCount += 1
            (mId, filePath) = self.pendingQosRequests[requestId]

            (domainId, topic_name, topic_type, qmlCode, mt, dataTreeModel, presetName) = self.dataWriters[mId]

            self.exportData["presets"].append({
                    "preset_name": presetName,
                    "domain_id": domainId,
                    "topic_name": topic_name,
                    "topic_type": topic_type,
                    "message": dataTreeModel.toJson(),
                    "qos": content
                })

            doFileWrite = False
            if self.exportCount:
                if self.exportCount == self.currentExportCount:
                    doFileWrite = True

            if doFileWrite:
                self.currentExportCount = 0
                self.exportCount = None
                qmlUtils = QmlUtils()
                qmlUtils.saveFileContent(filePath, json.dumps(self.exportData, indent=4))
                self.resetExportData()
