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
    DataItemIdRole = Qt.UserRole + 2

    def __init__(self, presetName, description="", parent=QObject()):
        super().__init__(parent)
        self.currentlyModifing = False
        self.presetName = presetName
        self.description = description
        self.sequenceItems = []

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()

        dataItemId = self.sequenceItems[row]
        if role == self.NameRole or role == Qt.DisplayRole:
            return dataItemId
        if role == self.DataItemIdRole:
            return dataItemId
        
        return None

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            self.NameRole: b'name',
            self.DataItemIdRole: b'dataItemId'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return len(self.sequenceItems)

    def getPresetName(self):
        return self.presetName
    
    def setPresetName(self, presetName):
        self.presetName = presetName

    def getDescription(self):
        return self.description

    def setDescription(self, description):
        self.description = description

    def isPresetSequence(self):
        return self.dataTreeModel.rootNode.role == DataTreeModel.IsSequenceRole

    @Slot(str)
    def addSequenceItem(self, dataItemId):
        self.beginResetModel()
        self.sequenceItems.append(dataItemId)
        self.endResetModel()

    @Slot(int)
    def removeSequenceItem(self, index):
        if index < 0 or index >= len(self.sequenceItems):
            return
        self.beginResetModel()
        del self.sequenceItems[index]
        self.endResetModel()

class WriterItem:
    def __init__(self, writerId, domainId, topic_name, topic_type, qmlCode, pyCode, dataTreeModels, presetName, qos={}, description="", dataItemNames=None, dataItemIds=None):
        self.writerId = writerId
        self.domainId = domainId
        self.topic_name = topic_name
        self.topic_type = topic_type
        self.qmlCode = qmlCode
        self.pyCode = pyCode
        self.dataTreeModels = dataTreeModels
        self.dataItemNames = [
            str(name).strip() or f"Data {index + 1}"
            for index, name in enumerate(dataItemNames)
        ] if isinstance(dataItemNames, list) else []
        while len(self.dataItemNames) < len(self.dataTreeModels):
            self.dataItemNames.append(f"Data {len(self.dataItemNames) + 1}")
        self.dataItemNames = self.dataItemNames[:len(self.dataTreeModels)]
        importedDataItemIds = list(dataItemIds) if isinstance(dataItemIds, list) else []
        self.dataItemIds = []
        for dataIndex in range(len(self.dataTreeModels)):
            dataItemId = writerId if dataIndex == 0 else (
                importedDataItemIds[dataIndex]
                if dataIndex < len(importedDataItemIds)
                else ""
            )
            if not dataItemId or dataItemId in self.dataItemIds:
                dataItemId = str(uuid.uuid4())
            self.dataItemIds.append(dataItemId)
        self.presetName = presetName
        self.description = description
        self.qos = qos
        self.isStarted = False

    def getPresetName(self):
        return self.presetName

    def setPresetName(self, presetName):
        self.presetName = presetName

    def getDescription(self):
        return self.description

    def setDescription(self, description):
        self.description = description

    def getTopicName(self):
        return self.topic_name
    
    def getTopicType(self):
        return self.topic_type
    
    def getDomainId(self):
        return self.domainId

    def getDataTreeModel(self, dataIndex=0):
        if dataIndex < 0 or dataIndex >= len(self.dataTreeModels):
            return None
        return self.dataTreeModels[dataIndex]

    def getDataTreeModels(self):
        return self.dataTreeModels

    def addDataTreeModel(self, dataTreeModel, name=None, dataItemId=None):
        self.dataTreeModels.append(dataTreeModel)
        self.dataItemNames.append(name or f"Data {len(self.dataTreeModels)}")
        self.dataItemIds.append(dataItemId or str(uuid.uuid4()))

    def removeDataTreeModel(self, dataIndex):
        if len(self.dataTreeModels) <= 1 or dataIndex < 0 or dataIndex >= len(self.dataTreeModels):
            return "", ""
        dataTreeModel = self.dataTreeModels.pop(dataIndex)
        del self.dataItemNames[dataIndex]
        removedDataItemId = self.dataItemIds.pop(dataIndex)
        promotedDataItemId = ""
        if dataIndex == 0:
            promotedDataItemId = self.dataItemIds[0]
            self.dataItemIds[0] = self.writerId
        dataTreeModel.deleteLater()
        return removedDataItemId, promotedDataItemId

    def getDataTreeModelCount(self):
        return len(self.dataTreeModels)

    def getDataItemName(self, dataIndex):
        if dataIndex < 0 or dataIndex >= len(self.dataItemNames):
            return ""
        return self.dataItemNames[dataIndex]

    def setDataItemName(self, dataIndex, name):
        if dataIndex < 0 or dataIndex >= len(self.dataItemNames):
            return
        self.dataItemNames[dataIndex] = name

    def getDataItemNames(self):
        return self.dataItemNames

    def getDataItemId(self, dataIndex):
        if dataIndex < 0 or dataIndex >= len(self.dataItemIds):
            return ""
        return self.dataItemIds[dataIndex]

    def getDataItemIds(self):
        return self.dataItemIds

    def getDataIndexById(self, dataItemId):
        try:
            return self.dataItemIds.index(dataItemId)
        except ValueError:
            return -1
    
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

    def _createDataTreeModel(self, topicType, messageRoot=None):
        rootNode = self.dataModelHandler.getRootNode(topicType)
        dataTreeModel = DataTreeModel(rootNode, parent=self)
        if messageRoot:
            dataTreeModel.fromJson(messageRoot, self.dataModelHandler)
        return dataTreeModel

    def _getDataReference(self, dataItemId):
        for writerId, item in self.items.items():
            if isinstance(item, WriterItem):
                dataIndex = item.getDataIndexById(dataItemId)
                if dataIndex >= 0:
                    return writerId, dataIndex
        return "", -1

    def _getImportedSequenceDataItemId(self, sequenceItem):
        if isinstance(sequenceItem, str):
            return sequenceItem
        return ""

    def _getAvailableDataReferences(self):
        references = []
        for writerId, item in self.items.items():
            if isinstance(item, WriterItem):
                for dataIndex in range(item.getDataTreeModelCount()):
                    references.append(item.getDataItemId(dataIndex))
        return references

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
            return item.getDescription()
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

    @Slot(int, int, result=DataTreeModel)
    def getTreeModel(self, currentIndex: int, dataIndex: int = 0) -> DataTreeModel:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return None
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            return item.getDataTreeModel(dataIndex)
        return None

    @Slot(int, result=int)
    def getDataItemCount(self, currentIndex: int) -> int:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return 0
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            return item.getDataTreeModelCount()
        return 0

    @Slot(result=int)
    def getAvailableDataItemCount(self) -> int:
        return len(self._getAvailableDataReferences())

    @Slot(int, result=str)
    def getAvailableDataItemName(self, availableIndex: int) -> str:
        references = self._getAvailableDataReferences()
        if availableIndex < 0 or availableIndex >= len(references):
            return ""
        return self.getDataItemDisplayName(references[availableIndex])

    @Slot(int, result=str)
    def getAvailableDataItemId(self, availableIndex: int) -> str:
        references = self._getAvailableDataReferences()
        if availableIndex < 0 or availableIndex >= len(references):
            return ""
        return references[availableIndex]

    @Slot(str, result=str)
    def getDataItemDisplayName(self, dataItemId: str) -> str:
        writerId, dataIndex = self._getDataReference(dataItemId)
        item = self.items.get(writerId)
        if not isinstance(item, WriterItem):
            return "Unknown"
        return f"{item.getPresetName()} - {item.getDataItemName(dataIndex)}"

    @Slot(int, int, result=str)
    def getDataItemName(self, currentIndex: int, dataIndex: int) -> str:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return ""
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            return item.getDataItemName(dataIndex)
        return ""

    @Slot(int, int, str)
    def setDataItemName(self, currentIndex: int, dataIndex: int, name: str):
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if not isinstance(item, WriterItem):
            return
        item.setDataItemName(dataIndex, name.strip() or f"Data {dataIndex + 1}")
        idx = self.index(currentIndex, 0)
        self.dataChanged.emit(idx, idx, [self.DataModelRole])

    @Slot(int, result=int)
    def addDataItem(self, currentIndex: int) -> int:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return -1
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if not isinstance(item, WriterItem):
            return -1

        item.addDataTreeModel(self._createDataTreeModel(item.getTopicType()))
        idx = self.index(currentIndex, 0)
        self.dataChanged.emit(idx, idx, [self.DataModelRole])
        return item.getDataTreeModelCount() - 1

    @Slot(int, int, result=int)
    def removeDataItem(self, currentIndex: int, dataIndex: int) -> int:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return -1
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if not isinstance(item, WriterItem):
            return dataIndex
        removedDataItemId, promotedDataItemId = item.removeDataTreeModel(dataIndex)
        if not removedDataItemId:
            return dataIndex

        for sequenceItem in self.items.values():
            if not isinstance(sequenceItem, SequenceItem):
                continue
            updatedReferences = [
                item.writerId if reference == promotedDataItemId else reference
                for reference in sequenceItem.sequenceItems
                if reference != removedDataItemId
            ]
            if updatedReferences != sequenceItem.sequenceItems:
                sequenceItem.beginResetModel()
                sequenceItem.sequenceItems = updatedReferences
                sequenceItem.endResetModel()

        idx = self.index(currentIndex, 0)
        self.dataChanged.emit(idx, idx, [self.DataModelRole])
        return min(dataIndex, item.getDataTreeModelCount() - 1)

    @Slot(int, result=SequenceItem)
    def getSequenceModel(self, currentIndex: int) -> SequenceItem:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return None
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, SequenceItem):
            return item
        return None

    @Slot(int, result=str)
    def getDescriptionName(self, currentIndex: int) -> str:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return ""
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, SequenceItem):
            return "Sequence"
        else:
            return f"Topic: {item.getTopicName()}  |  Type: {item.getTopicType()}  |  Domain: {item.getDomainId()}"

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
            for dataItemId in item.sequenceItems:
                itemCurrentId, _ = self._getDataReference(dataItemId)
                if itemCurrentId not in self.items:
                    logging.warning(f"Data item id {dataItemId} not found in items")
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
            stoppedWriterIds = set()
            for dataItemId in item.sequenceItems:
                itemCurrentId, _ = self._getDataReference(dataItemId)
                if itemCurrentId in stoppedWriterIds:
                    continue
                stoppedWriterIds.add(itemCurrentId)
                if itemCurrentId not in self.items:
                    logging.warning(f"Data item id {dataItemId} not found in items")
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
            startedWriterIds = set()
            for dataItemId in item.sequenceItems:
                itemCurrentId, _ = self._getDataReference(dataItemId)
                if itemCurrentId in startedWriterIds:
                    continue
                startedWriterIds.add(itemCurrentId)
                if itemCurrentId not in self.items:
                    logging.warning(f"Data item id {dataItemId} not found in items")
                    continue
                itemCurr = self.items[itemCurrentId]
                if isinstance(itemCurr, WriterItem):
                    self.createEndpointFromTesterSignal.emit(itemCurrentId, itemCurr.getDomainId(), itemCurr.getTopicName(), itemCurr.getTopicType(), 4, itemCurr.getPresetName(), {}, copy.deepcopy(itemCurr.qos))

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

    @Slot(int, result=str)
    def getDescription(self, currentIndex: int) -> str:
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return ""
        mId = list(self.items.keys())[int(currentIndex)]
        return self.items[mId].getDescription()

    @Slot(int, str)
    def setDescription(self, currentIndex: int, description: str):
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        item.setDescription(description)
        idx = self.index(currentIndex)
        self.dataChanged.emit(idx, idx, [self.DescriptionRole])

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
            dataTreeModel = self._createDataTreeModel(topic_type)
            self.items[id] = WriterItem(id, domainId, topic_name, topic_type, "", None, [dataTreeModel], f"Untitled-{TesterModel.untitiledCount}", qos)
            TesterModel.untitiledCount += 1
            self.items[id].setIsStarted(True)
            self.endResetModel()
            self.countChanged.emit()

    @Slot(int, int, QModelIndex)
    def addArrayItem(self, currentIndex: int, dataIndex: int, currentTreeIndex: QModelIndex):
        logging.debug("Add Array Item")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        dataTreeModel = item.getDataTreeModel(dataIndex)
        if dataTreeModel is None:
            return
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

    @Slot(int, int, QModelIndex)
    def removeArrayItem(self, currentIndex: int, dataIndex: int, currentTreeIndex: QModelIndex):
        logging.debug("Remove Array Item")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            dataTreeModel = item.getDataTreeModel(dataIndex)
            if dataTreeModel is None:
                return
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

    @Slot(int, int)
    def writeData(self, currentIndex: int, dataIndex: int):
        logging.trace(f"Write Data pressed on index: {str(currentIndex)}")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            dataTreeModel = item.getDataTreeModel(dataIndex)
            if dataTreeModel is not None:
                self.writeDataSignal.emit(mId, dataTreeModel.getDataObj())
        elif isinstance(item, SequenceItem):
            for dataItemId in item.sequenceItems:
                itemCurrentId, sequenceDataIndex = self._getDataReference(dataItemId)
                if itemCurrentId not in self.items:
                    logging.warning(f"Data item id {dataItemId} not found in items")
                    continue
                item = self.items[itemCurrentId]
                if isinstance(item, WriterItem):
                    dataTreeModel = item.getDataTreeModel(sequenceDataIndex)
                    if dataTreeModel is not None:
                        self.writeDataSignal.emit(itemCurrentId, dataTreeModel.getDataObj())

    @Slot(int, int)
    def disposeData(self, currentIndex: int, dataIndex: int):
        logging.trace(f"Dispose Data pressed on index: {str(currentIndex)}")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            dataTreeModel = item.getDataTreeModel(dataIndex)
            if dataTreeModel is not None:
                self.disposeDataSignal.emit(mId, dataTreeModel.getDataObj())
        elif isinstance(item, SequenceItem):
            for dataItemId in item.sequenceItems:
                itemCurrentId, sequenceDataIndex = self._getDataReference(dataItemId)
                if itemCurrentId not in self.items:
                    logging.warning(f"Data item id {dataItemId} not found in items")
                    continue
                item = self.items[itemCurrentId]
                if isinstance(item, WriterItem):
                    dataTreeModel = item.getDataTreeModel(sequenceDataIndex)
                    if dataTreeModel is not None:
                        self.disposeDataSignal.emit(itemCurrentId, dataTreeModel.getDataObj())

    @Slot(int, int)
    def unregisterData(self, currentIndex: int, dataIndex: int):
        logging.trace(f"Unregister Data pressed on index: {str(currentIndex)}")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            dataTreeModel = item.getDataTreeModel(dataIndex)
            if dataTreeModel is not None:
                self.unregisterDataSignal.emit(mId, dataTreeModel.getDataObj())
        elif isinstance(item, SequenceItem):
            for dataItemId in item.sequenceItems:
                itemCurrentId, sequenceDataIndex = self._getDataReference(dataItemId)
                if itemCurrentId not in self.items:
                    logging.warning(f"Data item id {dataItemId} not found in items")
                    continue
                item = self.items[itemCurrentId]
                if isinstance(item, WriterItem):
                    dataTreeModel = item.getDataTreeModel(sequenceDataIndex)
                    if dataTreeModel is not None:
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
        deletedDataItemIds = set()
        item = self.items.get(mId)
        if isinstance(item, WriterItem):
            deletedDataItemIds.update(item.getDataItemIds())
        self.beginResetModel()
        del self.items[mId]
        for sequenceItem in self.items.values():
            if not isinstance(sequenceItem, SequenceItem):
                continue
            sequenceItem.beginResetModel()
            sequenceItem.sequenceItems = [
                reference for reference in sequenceItem.sequenceItems
                if reference not in deletedDataItemIds
            ]
            sequenceItem.endResetModel()
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
                description = preset.get("description", "")
                topicType = preset.get("topic_type", "")
                domainId = preset.get("domain_id", 0)
                topicName = preset.get("topic_name", "")
                qos = preset.get("qos", {})
                firstMessage = preset.get("message", {"root": {}})
                additionalMessages = preset.get("messages", [])

                messages = [firstMessage] + additionalMessages

                dataTreeModels = []
                messageNames = []
                dataItemIds = []
                for index, message in enumerate(messages):
                    messageRoot = message.get("root", {}) if isinstance(message, dict) else {}
                    dataTreeModels.append(self._createDataTreeModel(topicType, messageRoot))
                    messageName = message.get("name", "") if isinstance(message, dict) else ""
                    messageNames.append(messageName or f"Data {index + 1}")
                    if index == 0:
                        dataItemIds.append(_id)
                    else:
                        messageId = message.get("id", "") if isinstance(message, dict) else ""
                        dataItemIds.append(messageId or str(uuid.uuid4()))

                self.beginResetModel()
                self.items[_id] = WriterItem(_id, domainId, topicName, topicType, None, None, dataTreeModels, presetName, copy.deepcopy(qos), description, messageNames, dataItemIds)
                self.endResetModel()
                self.countChanged.emit()

            sequence_presets = j.get("sequence_presets", [])
            for sequencePreset in sequence_presets:
                mId = sequencePreset.get("id", str(uuid.uuid4()))
                presetName = sequencePreset.get("preset_name", "Unknown")
                description = sequencePreset.get("description", "")
                sequenceItem = SequenceItem(presetName, description)
                for sequenceReference in sequencePreset.get("sequence_items", []):
                    dataItemId = self._getImportedSequenceDataItemId(sequenceReference)
                    if dataItemId:
                        sequenceItem.addSequenceItem(dataItemId)

                self.beginResetModel()
                self.items[mId] = sequenceItem
                self.endResetModel()
                self.countChanged.emit()

    @Slot(str, int)
    def exportJson(self, filePath, currentIndex: int):
        if currentIndex < 0:
            return
        self._exportJsonItem(currentIndex)

        self.exportCount = None
        qmlUtils = QmlUtils()
        qmlUtils.saveFileContent(filePath, json.dumps(self.exportData, indent=4))
        self.resetExportData()

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
                    "description": item.getDescription(),
                    "sequence_items": item.sequenceItems
                })
        if isinstance(item, WriterItem):
            messages = []
            for index, dataTreeModel in enumerate(item.getDataTreeModels()):
                message = dataTreeModel.toJson()
                message["id"] = item.getDataItemId(index)
                message["name"] = item.getDataItemName(index)
                messages.append(message)
            self.exportData["presets"].append({
                    "id": mId,
                    "preset_name": item.getPresetName(),
                    "description": item.getDescription(),
                    "domain_id": item.getDomainId(),
                    "topic_name": item.getTopicName(),
                    "topic_type": item.getTopicType(),
                    "message": messages[0],
                    "messages": messages[1:],
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

    @Slot(int)
    def duplicatePreset(self, currentIndex: int):
        if currentIndex < 0 or currentIndex >= len(self.items.keys()):
            return
        logging.info(f"Duplicate preset at index {currentIndex}")
        mId = list(self.items.keys())[int(currentIndex)]
        item = self.items[mId]
        if isinstance(item, WriterItem):
            newId = str(uuid.uuid4())
            newPresetName = f"{item.getPresetName()}-copy"
            dataTreeModels = [
                self._createDataTreeModel(item.getTopicType(), dataTreeModel.toJson()["root"])
                for dataTreeModel in item.getDataTreeModels()
            ]
            self.beginResetModel()
            duplicateDataItemIds = [newId] + [
                str(uuid.uuid4()) for _ in item.getDataTreeModels()[1:]
            ]
            self.items[newId] = WriterItem(newId, item.getDomainId(), item.getTopicName(), item.getTopicType(), item.getQmlCode(), None, dataTreeModels, newPresetName, copy.deepcopy(item.qos), item.getDescription(), item.getDataItemNames(), duplicateDataItemIds)
            self.endResetModel()
            self.countChanged.emit()
        elif isinstance(item, SequenceItem):
            newId = str(uuid.uuid4())
            newPresetName = f"{item.getPresetName()}-copy"
            self.beginResetModel()
            newSequenceItem = SequenceItem(newPresetName, item.getDescription())
            for dataItemId in item.sequenceItems:
                newSequenceItem.addSequenceItem(dataItemId)
            self.items[newId] = newSequenceItem
            self.endResetModel()
            self.countChanged.emit()
