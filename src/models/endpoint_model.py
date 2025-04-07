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

from PySide6.QtCore import Qt, QModelIndex, QAbstractItemModel, Qt, Slot, Signal, QThread
from cyclonedds.builtin import DcpsEndpoint, DcpsParticipant
from cyclonedds import core
from cyclonedds import qos
from loguru import logger as logging
import os
from pathlib import Path
import time
import uuid
from typing import Optional, List

from dds_access import dds_data
from dds_access.dds_data import DataEndpoint
from dds_access.dds_utils import getProperty, getHostname, PROCESS_NAMES, PIDS, ADDRESSES
from dds_access.dds_qos import partitions_match_p
from dds_access.datatypes.entity_type import EntityType


class PartitionModel(QAbstractItemModel):

    PartitionNameRole = Qt.UserRole + 1
    PartitionMatchedRole = Qt.UserRole + 2
    PartitionSelectedRole = Qt.UserRole + 3

    def __init__(self, parent=None):
        super(PartitionModel, self).__init__(parent)
        self.partitions = {}

    def index(self, row, column, parent=QModelIndex()):
        return self.createIndex(row, column)

    def rowCount(self, parent=QModelIndex()):
        return len(self.partitions)

    def columnCount(self, index):
        return 0

    def parent(self, index):
        return QModelIndex()

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < self.rowCount()):
            return None

        row = index.row()
        partitionName = list(self.partitions.keys())[row]
        matched, selected = self.partitions[partitionName]

        if role == self.PartitionNameRole:
            return partitionName
        elif role == self.PartitionMatchedRole:
            return matched
        elif role == self.PartitionSelectedRole:
            return selected

        return None

    def roleNames(self):
        return {
            self.PartitionNameRole: b'partition_name',
            self.PartitionMatchedRole: b'partition_matched',
            self.PartitionSelectedRole: b'partition_selected',
        }

    def clearMatching(self):
        for partitionName in self.partitions.keys():
            self.partitions[partitionName] = (False, False)
            index = list(self.partitions.keys()).index(partitionName)
            self.dataChanged.emit(self.index(index, 0), self.index(index, 0), [self.PartitionMatchedRole, self.PartitionSelectedRole])

    def updatePartition(self, partitionName: str, matched: bool, selected: bool):
        self.partitions[partitionName] = (matched, selected)
        if partitionName in self.partitions:
            idx = list(self.partitions.keys()).index(partitionName)
            index = self.createIndex(idx, 0)
            self.dataChanged.emit(index, index, [self.PartitionMatchedRole, self.PartitionSelectedRole])
            return
        else:
            self.beginInsertRows(QModelIndex(), len(self.partitions) - 1, len(self.partitions) - 1)
            self.endInsertRows()

class EndpointModel(QAbstractItemModel):

    KeyRole = Qt.UserRole + 1
    ParticipantKeyRole = Qt.UserRole + 2
    ParticipantInstanceHandleRole = Qt.UserRole + 3
    TopicNameRole = Qt.UserRole + 4
    TypeNameRole = Qt.UserRole + 5
    QosRole = Qt.UserRole + 6
    TypeIdRole = Qt.UserRole + 7
    HostnameRole = Qt.UserRole + 8
    ProcessIdRole = Qt.UserRole + 9
    ProcessNameRole = Qt.UserRole + 10
    EndpointHasQosMismatch = Qt.UserRole + 11
    EndpointQosMismatchText = Qt.UserRole + 12
    AddressesRole = Qt.UserRole + 13
    PartitionsRole  = Qt.UserRole + 14
    HasPartitionsRole = Qt.UserRole + 15

    topicHasQosMismatchSignal = Signal(bool)
    totalEndpointsSignal = Signal(int)

    requestEndpointsSignal = Signal(str, int, str, EntityType)
    requestMismatchesSignal = Signal(str, int, str)


    def __init__(self, parent=None):
        super(EndpointModel, self).__init__(parent)
        logging.debug(f"New instance EndpointModel: {str(self)} id: {id(self)}")

        self.endpoints = {}
        self.partitions = {}
        self.selectedPartition = None
        self.selectedPartitionEndpKey: str = ""
        self.domain_id = -1
        self.topic_name = ""
        self.currentRequestId = str(uuid.uuid4())
        self.entity_type = EntityType.UNDEFINED
        self.topic_has_mismatch = False
        self.topicTypes = []

        self.dds_data = dds_data.DdsData()
        # self to dds_data
        self.requestEndpointsSignal.connect(self.dds_data.requestEndpointsSlot, Qt.ConnectionType.QueuedConnection)
        # From dds_data to self
        self.dds_data.new_endpoint_signal.connect(self.new_endpoint_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_endpoint_signal.connect(self.remove_endpoint_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.no_more_mismatch_in_topic_signal.connect(self.no_more_mismatch_in_topic_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.publish_mismatch_signal.connect(self.publish_mismatch_slot, Qt.ConnectionType.QueuedConnection)

    def index(self, row, column, parent=QModelIndex()):
        return self.createIndex(row, column)

    def rowCount(self, parent=QModelIndex()):
        return len(self.endpoints.keys())

    def columnCount(self, index):
        return 0

    def parent(self, index):
        return QModelIndex()

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < self.rowCount()):
            return None

        row = index.row()
        endp_key = list(self.endpoints.keys())[row]

        endp: DcpsEndpoint = self.endpoints[endp_key].endpoint
        p: Optional[DcpsParticipant] =  self.endpoints[endp_key].participant

        if role == self.KeyRole:
            return str(endp.key)
        elif role == self.ParticipantKeyRole:
            return str(endp.participant_key)
        elif role == self.ParticipantInstanceHandleRole:
            return str(endp.participant_instance_handle)
        elif role == self.TopicNameRole:
            return str(endp.topic_name)
        elif role == self.TypeNameRole:
            return str(endp.type_name)
        elif role == self.QosRole:
            split = ""
            for idx, q in enumerate(endp.qos):
                split += "  " + str(q)
                if idx < len(endp.qos) - 1:
                    split += "\n"
            return split
        elif role == self.TypeIdRole:
            return str(endp.type_id)
        elif role == self.HostnameRole:
            return getHostname(p)
        elif role == self.ProcessIdRole:
            return getProperty(p, PIDS)
        elif role == self.ProcessNameRole:
            appname: str = getProperty(p, PROCESS_NAMES)
            return Path(appname.replace("\\", f"{os.path.sep}")).stem
        elif role == self.AddressesRole:
            return getProperty(p, ADDRESSES)
        elif role == self.EndpointHasQosMismatch:
            if len(self.endpoints[endp_key].mismatches.keys()):
                return True
            return False
        elif role == self.EndpointQosMismatchText:
            qos_mm_txt = ""
            if len(self.endpoints[endp_key].mismatches.keys()) > 0:
                qos_mm_txt += "\nQos-Mismatches:\n"
                for idx, endp_mm in enumerate(self.endpoints[endp_key].mismatches.keys()):
                    for idx_mm, mm_type in enumerate(self.endpoints[endp_key].mismatches[endp_mm]):
                        qos_mm_txt += "  " + str(mm_type) + " with " + str(endp_mm)
                        if idx_mm < len(self.endpoints[endp_key].mismatches[endp_mm]) - 1:
                            qos_mm_txt += "\n"
                    if idx < len(self.endpoints[endp_key].mismatches.keys()) - 1:
                        qos_mm_txt += "\n"
                qos_mm_txt = qos_mm_txt.replace("dds_qos_policy_id.", "")
            return qos_mm_txt
        elif role == self.PartitionsRole:
            return self.partitions[endp_key]
        elif role == self.HasPartitionsRole:
            return self.partitions[endp_key].rowCount() > 0

        return None

    def roleNames(self):
        return {
            self.KeyRole: b'endpoint_key',
            self.ParticipantKeyRole: b'endpoint_participant_key',
            self.ParticipantInstanceHandleRole: b'endpoint_participant_instance_handle',
            self.TopicNameRole: b'endpoint_topic_name',
            self.TypeNameRole: b'endpoint_topic_type',
            self.QosRole: b'endpoint_qos',
            self.TypeIdRole: b'endpoint_type_id',
            self.HostnameRole: b'endpoint_hostname',
            self.ProcessIdRole: b'endpoint_process_id',
            self.ProcessNameRole: b'endpoint_process_name',
            self.EndpointHasQosMismatch: b'endpoint_has_qos_mismatch',
            self.EndpointQosMismatchText: b'endpoint_qos_mismatch_text',
            self.AddressesRole: b'addresses',
            self.PartitionsRole: b'partitions',
            self.HasPartitionsRole: b'has_partitions',
        }

    def updateMatchedPartitions(self):
        if self.selectedPartition is None:
            return
        for endp_key in list(self.endpoints.keys()):
            endp: DcpsEndpoint = self.endpoints[endp_key].endpoint
            if qos.Policy.Partition in endp.qos:
                for i in range(len(endp.qos[qos.Policy.Partition].partitions)):
                    pat = str(endp.qos[qos.Policy.Partition].partitions[i])
                    selected = False
                    if pat == self.selectedPartition:
                        matched = True
                        selected = True if endp_key == self.selectedPartitionEndpKey else False
                    else:
                        if self.entity_type == EntityType.READER:
                            matched = partitions_match_p([pat], [self.selectedPartition])
                        else:
                            matched = partitions_match_p([self.selectedPartition], [pat])
                    self.partitions[endp_key].updatePartition(pat, matched, selected)

    @Slot()
    def clearPartitionMatching(self):
        self.selectedPartition = None
        self.selectedPartitionEndpKey = ""
        for endp_key in list(self.endpoints.keys()):
            self.partitions[endp_key].clearMatching()

    @Slot(str, str)
    def setSelectedPartition(self, partitionName: str, currentEndpKey: int):
        logging.debug(f"set selected partition to {partitionName}, current endp-key: {currentEndpKey}")
        self.selectedPartition = partitionName
        self.selectedPartitionEndpKey = currentEndpKey
        self.updateMatchedPartitions()

    @Slot(int, str, int)
    def setDomainId(self, domain_id: int, topic_name: str, entity_type: int):

        logging.debug(f"init endpoint model {id(self)}")

        self.beginResetModel()

        self.domain_id = domain_id
        self.entity_type = EntityType(entity_type)
        self.topic_name = topic_name
        self.endpoints = {}
        self.partitions = {}
        self.selectedPartitionEndpKey = ""
        self.selectedPartition = None
        self.currentRequestId = str(uuid.uuid4())

        self.endResetModel()

        self.totalEndpointsSignal.emit(len(self.endpoints))
        self.requestEndpointsSignal.emit(self.currentRequestId, domain_id, self.topic_name, self.entity_type)

    @Slot(str, int, DataEndpoint)
    def new_endpoint_slot(self, requestId: str, domain_id: int, endpointData: DataEndpoint):
        if self.currentRequestId != requestId and requestId != "":
            return
        if domain_id != self.domain_id:
            return
        if self.topic_name != endpointData.endpoint.topic_name:
            return

        if (endpointData.isReader() and EntityType.WRITER == self.entity_type) or (endpointData.isWriter() and EntityType.READER == self.entity_type):
            if len(endpointData.mismatches.keys()) > 0:
                for mismKey in endpointData.mismatches.keys():
                    if mismKey in self.endpoints:
                        self.endpoints[mismKey].mismatches[str(endpointData.endpoint.key)] = endpointData.mismatches[mismKey]
                        idx = list(self.endpoints.keys()).index(mismKey)
                        index = self.createIndex(idx, 0)
                        self.dataChanged.emit(index, index, [self.EndpointHasQosMismatch, self.EndpointQosMismatchText])
            return
        if str(endpointData.endpoint.key) in self.endpoints:
            return
        
        endp_keys = list(self.endpoints.keys())
        row = 0
        while row < len(endp_keys) and endp_keys[row] != str(endpointData.endpoint.key):
            row += 1

        self.beginInsertRows(QModelIndex(), row, row)
        self.endpoints[str(endpointData.endpoint.key)] = endpointData
        self.topicTypes.append(endpointData.endpoint.type_name)
        self.partitions[str(endpointData.endpoint.key)] = PartitionModel(self)
        if qos.Policy.Partition in endpointData.endpoint.qos:
            for i in range(len(endpointData.endpoint.qos[qos.Policy.Partition].partitions)):
                pat = str(endpointData.endpoint.qos[qos.Policy.Partition].partitions[i])
                self.partitions[str(endpointData.endpoint.key)].updatePartition(pat, False, False)
        self.endInsertRows()

        self.totalEndpointsSignal.emit(len(self.endpoints))

        if len(endpointData.mismatches.keys()) > 0:
            self.topicHasQosMismatchSignal.emit(True)

        if self.selectedPartition is not None:
            self.updateMatchedPartitions()

    @Slot(int, str)
    def remove_endpoint_slot(self, domain_id, endpoint_key):
        if domain_id != self.domain_id:
            return
        
        if str(endpoint_key) in self.endpoints:
            row = list(self.endpoints.keys()).index(endpoint_key)
            self.beginRemoveRows(QModelIndex(), row, row)
            self.topicTypes.remove(self.endpoints[endpoint_key].endpoint.type_name)
            del self.endpoints[endpoint_key]
            self.endRemoveRows()
            self.totalEndpointsSignal.emit(len(self.endpoints))
        else:
            for endpKey in self.endpoints.keys():
                if str(endpoint_key) in self.endpoints[endpKey].mismatches:
                    del self.endpoints[endpKey].mismatches[str(endpoint_key)]
                    idx = list(self.endpoints.keys()).index(endpKey)
                    index = self.createIndex(idx, 0)
                    self.dataChanged.emit(index, index, [self.EndpointHasQosMismatch, self.EndpointQosMismatchText])

    @Slot(int, str, list)
    def publish_mismatch_slot(self, domain_id, topicName, mismatches):
        if domain_id != self.domain_id or topicName != self.topic_name:
            return

        if len(mismatches) > 0:
            self.topicHasQosMismatchSignal.emit(True)
            for mismaEndKey in mismatches:
                if str(mismaEndKey) in self.endpoints.keys():
                    idx = list(self.endpoints.keys()).index(mismaEndKey)
                    index = self.createIndex(idx, 0)
                    self.dataChanged.emit(index, index, [self.EndpointHasQosMismatch, self.EndpointQosMismatchText])

    @Slot(int, str)
    def no_more_mismatch_in_topic_slot(self, domain_id, topic_name):
        if domain_id != self.domain_id or topic_name != self.topic_name:
            return

        self.topicHasQosMismatchSignal.emit(False)

        for idx, _ in enumerate(list(self.endpoints.keys())):
            index = self.createIndex(idx, 0)
            self.dataChanged.emit(index, index, [self.EndpointHasQosMismatch, self.EndpointQosMismatchText])

    @Slot(result=list)
    def getAllTopicTypes(self):
        return list(set(self.topicTypes))
