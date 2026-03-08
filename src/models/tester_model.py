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

class SequenceItem(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    def __init__(self, presetName, parent=QObject()):
        super().__init__(parent)
        self.currentlyModifing = False
        self.presetName = presetName
        self.sequenceItems = []

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()

        if role == self.NameRole or role == Qt.DisplayRole:
            return f"{self.sequenceItems[row]}"
        
        return None

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            self.NameRole: b'name'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return len(self.sequenceItems)

    def getPresetName(self):
        return self.presetName
    
    def setPresetName(self, presetName):
        self.presetName = presetName

    def isPresetSequence(self):
        return self.dataTreeModel.rootNode.role == DataTreeModel.IsSequenceRole

    @Slot(str)
    def addSequenceItem(self, itemId):
        self.beginResetModel()
        self.sequenceItems.append(itemId)
        self.endResetModel()

    @Slot(int)
    def removeSequenceItem(self, index):
        if index < 0 or index >= len(self.sequenceItems):
            return
        self.beginResetModel()
        del self.sequenceItems[index]
        self.endResetModel()

class WriterItem:
    def __init__(self, domainId, topic_name, topic_type, qmlCode, pyCode, dataTreeModel, presetName, qos={}):
        self.domainId = domainId
        self.topic_name = topic_name
        self.topic_type = topic_type
        self.qmlCode = qmlCode
        self.pyCode = pyCode
        self.dataTreeModel = dataTreeModel
        self.presetName = presetName
        self.qos = qos
        self.isStarted = False

    def getPresetName(self):
        return self.presetName

    def setPresetName(self, presetName):
        self.presetName = presetName

    def getTopicName(self):
        return self.topic_name
    
    def getTopicType(self):
        return self.topic_type
    
    def getDomainId(self):
        return self.domainId

    def getDataTreeModel(self):
        return self.dataTreeModel
    
    def getQmlCode(self):
        return self.qmlCode

    def setIsStarted(self, isStarted):
        self.isStarted = isStarted

    def getIsStarted(self):
        return self.isStarted

class TesterModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1
    DataModelRole = Qt.UserRole + 2
    PresetNameRole = Qt.UserRole + 3
    IsPresetSequenceRole = Qt.UserRole + 4
    DescriptionRole = Qt.UserRole + 5
    IsWriterRole = Qt.UserRole + 6
    IsStarted = Qt.UserRole + 7

    showQml = Signal(str, str)
    countChanged = Signal()

    createEndpointFromTesterSignal = Signal(str, int, str, str, int, str, object, object)

    writeDataSignal = Signal(str, object)
    disposeDataSignal = Signal(str, object)
    unregisterDataSignal = Signal(str, object)

    requestQosJsonSignal = Signal(str, str)

    def getCount(self):
        return self.rowCount()

    count = Property(int, getCount, notify=countChanged)

    untitiledSequenceCount = 1
    untitiledCount = 1

    def __init__(self, threads, dataModelHandler, datamodelRepoModel, parent=QObject()):
        super().__init__()
        self.dataModelHandler = dataModelHandler
        self.datamodelRepoModel = datamodelRepoModel
        self.createEndpointFromTesterSignal.connect(self.datamodelRepoModel.createEndpointFromTester, Qt.ConnectionType.QueuedConnection)
        self.items = {}
        self.threads = threads
        self.alreadyConnectedDomains = []
        self.pendingQosRequests = {}
        self.resetExportData()

    def resetExportData(self):
        self.exportData = { "presets": [], "sequence_presets": [] }

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()

        itemId = list(self.items.keys())[row]
        item = self.items[itemId]

        if role == self.NameRole:
            return f"{item.getPresetName()}"
        if role == self.DataModelRole:
            if isinstance(item, WriterItem):
                return item.getDataTreeModel()
        if role == self.PresetNameRole:
            return item.getPresetName()
        if role == self.DescriptionRole:
            if isinstance(item, SequenceItem):
                return "Sequence"
            else:
                return f"Topic: {item.getTopicName()}, Domain: {str(item.getDomainId())}"
        if role == self.IsWriterRole:
            return isinstance(item, WriterItem)
        
        if role == self.IsStarted:
            if isinstance(item, WriterItem):
                return item.getIsStarted()
            if isinstance(item, SequenceItem):
                return self.getIsStarted(index.row())

        return None

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            self.NameRole: b'name',
            self.DataModelRole: b'dataModel',
            self.IsPresetSequenceRole: b'isPresetSequence',
            self.PresetNameRole: b'presetName',
            self.DescriptionRole: b'description',
            self.IsWriterRole: b'isWriter',
            self.IsStarted: b'isStarted'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return len(self.items.keys())

    @Slot(int, result=DataTreeModel)
    def getTreeModel(self, currentIndex: int) -> DataTreeModel:
        if currentIndex < 0:
            return
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            return item.getDataTreeModel()
        return None

    @Slot(int, result=SequenceItem)
    def getSequenceModel(self, currentIndex: int) -> SequenceItem:
        if currentIndex < 0:
            return
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, SequenceItem):
            return item
        return None

    @Slot(int, result=str)
    def getDescriptionName(self, currentIndex: int) -> str:
        if currentIndex < 0:
            return
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, SequenceItem):
            return "Sequence"
        else:
            return f"Topic: {item.getTopicName()}, Domain: {str(item.getDomainId())}"

    @Slot(int, result=bool)
    def getIsStarted(self, currentIndex: int) -> bool:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return False
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            return item.getIsStarted()
        if isinstance(item, SequenceItem):
            if len(item.sequenceItems) == 0:
                return False
            for itemCurrentId in item.sequenceItems:
                if itemCurrentId not in self.items.keys():
                    logging.warning(f"Item id {itemCurrentId} not found in items")
                    continue
                itemCurr = self.items[itemCurrentId]
                if isinstance(itemCurr, WriterItem):
                    itemStarted = itemCurr.getIsStarted()
                    if not itemStarted:
                        return False
            return True
        return False

    @Slot(int)
    def stopItem(self, currentIndex: int):
        if currentIndex < 0:
            return
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        self.beginResetModel()
        if isinstance(item, WriterItem):
            for key in self.threads.keys():
                self.threads[key].deleteWriter(mId)
            item.setIsStarted(False)
        if isinstance(item, SequenceItem):
            for itemCurrentId in item.sequenceItems:
                if itemCurrentId not in self.items.keys():
                    logging.warning(f"Item id {itemCurrentId} not found in items")
                    continue
                itemCurr = self.items[itemCurrentId]
                if isinstance(itemCurr, WriterItem):
                    for key in self.threads.keys():
                        self.threads[key].deleteWriter(itemCurrentId)
                    itemCurr.setIsStarted(False)
        self.endResetModel()

    @Slot(int)
    def startItem(self, currentIndex: int):
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]

        if isinstance(item, WriterItem):
            self.createEndpointFromTesterSignal.emit(mId, item.getDomainId(), item.getTopicName(), item.getTopicType(), 4, item.getPresetName(), {}, copy.deepcopy(item.qos))
        if isinstance(item, SequenceItem):
            for itemCurrentId in item.sequenceItems:
                if itemCurrentId not in self.items.keys():
                    logging.warning(f"Item id {itemCurrentId} not found in items")
                    continue
                itemCurr = self.items[itemCurrentId]
                if isinstance(itemCurr, WriterItem):
                    self.createEndpointFromTesterSignal.emit(itemCurrentId, itemCurr.getDomainId(), itemCurr.getTopicName(), itemCurr.getTopicType(), 4, itemCurr.getPresetName(), {}, copy.deepcopy(itemCurr.qos))

    @Slot(int, result=str)
    def getItemId(self, currentIndex: int) -> str:
        if currentIndex < 0:
            return
        return list(self.items.keys())[int(currentIndex)]

    @Slot(str, result=str)
    def getNameById(self, itemId: str) -> str:
        if itemId in self.items.keys():
            return self.items[itemId].getPresetName()
        return None

    @Slot(int, result=str)
    def getPresetName(self, currentIndex: int) -> str:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return
        mId = list(self.items.keys())[int(currentIndex)]
        return self.items[mId].getPresetName()

    @Slot(int, str)
    def setPresetName(self, currentIndex: int, presetName: str):
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        item.setPresetName(presetName)
        idx = self.index(currentIndex)
        self.dataChanged.emit(idx, idx, [self.PresetNameRole, self.NameRole])

    @Slot(int, str, str, str, object)
    def addWriter(self, id: str, domainId, topic_name, topic_type: str, qos):
        logging.info("AddWriter to TesterModel")

        if domainId not in self.alreadyConnectedDomains:
            self.writeDataSignal.connect(self.threads[domainId].write, Qt.ConnectionType.QueuedConnection)
            self.disposeDataSignal.connect(self.threads[domainId].dispose, Qt.ConnectionType.QueuedConnection)
            self.unregisterDataSignal.connect(self.threads[domainId].unregisterInstance, Qt.ConnectionType.QueuedConnection)
            self.alreadyConnectedDomains.append(domainId)

        if id in self.items.keys():
            self.items[id].setIsStarted(True)
            row = list(self.items.keys()).index(id)
            idx = self.index(row, 0)
            self.dataChanged.emit(idx, idx, [self.IsStarted, self.NameRole, self.PresetNameRole])
        else:
            self.beginResetModel()
            rootNode = self.dataModelHandler.getRootNode(topic_type)
            dataTreeModel = DataTreeModel(rootNode, parent=self)
            self.items[id] = WriterItem(domainId, topic_name, topic_type, "", None, dataTreeModel, f"Untitled-{TesterModel.untitiledCount}", qos)
            TesterModel.untitiledCount += 1
            self.items[id].setIsStarted(True)
            self.endResetModel()
            self.countChanged.emit()

    @Slot(int, QModelIndex)
    def addArrayItem(self, currentIndex: int, currentTreeIndex: QModelIndex):
        logging.debug("Add Array Item")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        dataTreeModel = item.getDataTreeModel()
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
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            dataTreeModel = item.getDataTreeModel()
            if currentTreeIndex.isValid():
                dataTreeModel.removeArrayItem(currentTreeIndex)

    @Slot(int)
    def showTester(self, currentIndex: int):
        if currentIndex < 0 and len(list(self.items.keys())) == 0:
            return
        logging.trace(f"Show Tester pressed on index: {str(currentIndex)}")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            self.showQml.emit(mId, item.getQmlCode())

    @Slot(int)
    def writeData(self, currentIndex: int):
        logging.trace(f"Write Data pressed on index: {str(currentIndex)}")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            dataTreeModel = item.getDataTreeModel()
            self.writeDataSignal.emit(mId, dataTreeModel.getDataObj())
        elif isinstance(item, SequenceItem):
            for itemCurrentId in item.sequenceItems:
                if itemCurrentId not in self.items.keys():
                    logging.warning(f"Item id {itemCurrentId} not found in items")
                    continue
                item = self.items[itemCurrentId]
                if isinstance(item, WriterItem):
                    dataTreeModel = item.getDataTreeModel()
                    self.writeDataSignal.emit(itemCurrentId, dataTreeModel.getDataObj())

    @Slot(int)
    def disposeData(self, currentIndex: int):
        logging.trace(f"Dispose Data pressed on index: {str(currentIndex)}")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            dataTreeModel = item.getDataTreeModel()
            self.disposeDataSignal.emit(mId, dataTreeModel.getDataObj())
        elif isinstance(item, SequenceItem):
            for itemCurrentId in item.sequenceItems:
                if itemCurrentId not in self.items.keys():
                    logging.warning(f"Item id {itemCurrentId} not found in items")
                    continue
                item = self.items[itemCurrentId]
                if isinstance(item, WriterItem):
                    dataTreeModel = item.getDataTreeModel()
                    self.disposeDataSignal.emit(itemCurrentId, dataTreeModel.getDataObj())

    @Slot(int)
    def unregisterData(self, currentIndex: int):
        logging.trace(f"Unregister Data pressed on index: {str(currentIndex)}")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            dataTreeModel = item.getDataTreeModel()
            self.unregisterDataSignal.emit(mId, dataTreeModel.getDataObj())
        elif isinstance(item, SequenceItem):
            for itemCurrentId in item.sequenceItems:
                if itemCurrentId not in self.items.keys():
                    logging.warning(f"Item id {itemCurrentId} not found in items")
                    continue
                item = self.items[itemCurrentId]
                if isinstance(item, WriterItem):
                    dataTreeModel = item.getDataTreeModel()
                    self.unregisterDataSignal.emit(itemCurrentId, dataTreeModel.getDataObj())

    @Slot()
    def deleteAllWriters(self):
        self.beginResetModel()
        self.items.clear()
        for key in self.threads.keys():
            self.threads[key].deleteAllWriters()
        self.endResetModel()
        self.countChanged.emit()

    @Slot(int)
    def deleteWriter(self, currentIndex: int):
        if currentIndex < 0:
            return
        logging.trace(f"Delete Writer pressed on index: {str(currentIndex)}")
        mId = list(self.items.keys())[int(currentIndex)]
        self.beginResetModel()
        del self.items[mId]
        for key in self.threads.keys():
            self.threads[key].deleteWriter(mId)
        self.endResetModel()
        self.countChanged.emit()

    @Slot(str)
    def importJson(self, filePath):
        if not os.path.isfile(filePath):
            logging.error(f"File does not exist: {filePath}")
            return
        with open(filePath, "r", encoding="utf-8") as f:
            content = f.read()
            j = json.loads(content)

            presets = j.get("presets", [])
            for preset in presets:
                _id = preset.get("id", str(uuid.uuid4()))
                presetName = preset.get("preset_name", "Unknown")
                topicType = preset.get("topic_type", "")
                domainId = preset.get("domain_id", 0)
                topicName = preset.get("topic_name", "")
                msgDict = preset.get("message", {"root": {}})["root"]
                qos = preset.get("qos", {})
                rootNode = self.dataModelHandler.getRootNode(topicType)
                dataTreeModel = DataTreeModel(rootNode, parent=self)
                if len(msgDict.keys()) > 0:
                    dataTreeModel.fromJson(msgDict, self.dataModelHandler)

                self.beginResetModel()
                self.items[_id] = WriterItem(domainId, topicName, topicType, None, None, dataTreeModel, presetName, copy.deepcopy(qos))
                self.endResetModel()
                self.countChanged.emit()

            sequence_presets = j.get("sequence_presets", [])
            for sequencePreset in sequence_presets:
                mId = sequencePreset.get("id", str(uuid.uuid4()))
                presetName = sequencePreset.get("preset_name", "Unknown")
                sequenceItem = SequenceItem(presetName)
                for itemSeqId in sequencePreset.get("sequence_items", []):
                    sequenceItem.addSequenceItem(itemSeqId)

                self.beginResetModel()
                self.items[mId] = sequenceItem
                self.endResetModel()
                self.countChanged.emit()

    @Slot(str, int)
    def exportJson(self, filePath, currentIndex: int):
        if currentIndex < 0:
            return
        self._exportJsonItem(filePath, currentIndex)

    @Slot(str)
    def exportJsonAll(self, filePath):
        self.exportCount = len(list(self.items.keys()))
        for index, _ in enumerate(list(self.items.keys())):
            self._exportJsonItem(index)

        self.exportCount = None
        qmlUtils = QmlUtils()
        qmlUtils.saveFileContent(filePath, json.dumps(self.exportData, indent=4))
        self.resetExportData()

    def _exportJsonItem(self, currentIndex: int):
        if currentIndex < 0:
            return
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]

        if isinstance(item, SequenceItem):
            self.exportData["sequence_presets"].append({
                    "id": mId,
                    "preset_name": item.getPresetName(),
                    "sequence_items": item.sequenceItems
                })
        if isinstance(item, WriterItem):
            self.exportData["presets"].append({
                    "id": mId,
                    "preset_name": item.getPresetName(),
                    "domain_id": item.getDomainId(),
                    "topic_name": item.getTopicName(),
                    "topic_type": item.getTopicType(),
                    "message": item.getDataTreeModel().toJson(),
                    "qos": item.qos
                })

    @Slot()
    def addSequence(self):
        logging.info("Add Sequence pressed")
        self.beginResetModel()
        self.items[str(uuid.uuid4())] = SequenceItem(f"Sequence-{TesterModel.untitiledSequenceCount}")
        TesterModel.untitiledSequenceCount += 1
        self.endResetModel()
        self.countChanged.emit()
