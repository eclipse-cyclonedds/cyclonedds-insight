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
import logging
import os
from pathlib import Path
import time
import uuid

import dds_data
from dds_data import DataEndpoint
from utils import EntityType


HOSTNAME_GET = core.Policy.Property("__Hostname", "")
APPNAME_GET = core.Policy.Property("__ProcessName", "")
PID_GET = core.Policy.Property("__Pid", "")
ADDRESS_GET = core.Policy.Property("__NetworkAddresses", "")


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

    topicHasQosMismatchSignal = Signal(bool)
    totalEndpointsSignal = Signal(int)

    requestEndpointsSignal = Signal(str, int, str, EntityType)
    requestMismatchesSignal = Signal(str, int, str)

    def __init__(self, parent=None):
        super(EndpointModel, self).__init__(parent)
        logging.debug(f"New instance EndpointModel: {str(self)} id: {id(self)}")

        self.endpoints = {}
        self.domain_id = -1
        self.topic_name = ""
        self.currentRequestId = str(uuid.uuid4())
        self.entity_type = EntityType.UNDEFINED
        self.topic_has_mismatch = False

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

        hostname = "Unknown"
        appname = "Unknown"
        pid = "Unknown"
        if self.endpoints[endp_key].participant is not None:
            p = self.endpoints[endp_key].participant
            hostname = p.qos[HOSTNAME_GET].value if p.qos[HOSTNAME_GET] is not None else "Unknown"
            appname = p.qos[APPNAME_GET].value if p.qos[APPNAME_GET] is not None else "Unknown"
            pid = p.qos[PID_GET].value if p.qos[PID_GET] is not None else "Unknown"

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
            return hostname
        elif role == self.ProcessIdRole:
            return pid
        elif role == self.ProcessNameRole:
            return Path(appname.replace("\\", f"{os.path.sep}")).stem
        elif role == self.EndpointHasQosMismatch:
            if len(self.endpoints[endp_key].missmatches.keys()):
                return True
            return False
        elif role == self.EndpointQosMismatchText:
            qos_mm_txt = ""
            if len(self.endpoints[endp_key].missmatches.keys()) > 0:
                qos_mm_txt += "\nQos-Mismatches:\n"
                for idx, endp_mm in enumerate(self.endpoints[endp_key].missmatches.keys()):
                    for idx_mm, mm_type in enumerate(self.endpoints[endp_key].missmatches[endp_mm]):
                        qos_mm_txt += "  " + str(mm_type) + " with " + str(endp_mm)
                        if idx_mm < len(self.endpoints[endp_key].missmatches[endp_mm]) - 1:
                            qos_mm_txt += "\n"
                    if idx < len(self.endpoints[endp_key].missmatches.keys()) - 1:
                        qos_mm_txt += "\n"
                qos_mm_txt = qos_mm_txt.replace("dds_qos_policy_id.", "")
            return qos_mm_txt

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
            self.EndpointQosMismatchText: b'endpoint_qos_mismatch_text'
        }

    @Slot(int, str, int)
    def setDomainId(self, domain_id: int, topic_name: str, entity_type: int):

        logging.debug(f"init endpoint model {id(self)}")

        self.beginResetModel()

        self.domain_id = domain_id
        self.entity_type = EntityType(entity_type)
        self.topic_name = topic_name
        self.endpoints = {}
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
            if len(endpointData.missmatches.keys()) > 0:
                for mismKey in endpointData.missmatches.keys():
                    if mismKey in self.endpoints:
                        self.endpoints[mismKey].missmatches[str(endpointData.endpoint.key)] = endpointData.missmatches[mismKey]
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
        self.endInsertRows()

        self.totalEndpointsSignal.emit(len(self.endpoints))

        if len(endpointData.missmatches.keys()) > 0:
            self.topicHasQosMismatchSignal.emit(True)

    @Slot(int, str)
    def remove_endpoint_slot(self, domain_id, endpoint_key):
        if domain_id != self.domain_id:
            return
        
        if str(endpoint_key) in self.endpoints:
            row = list(self.endpoints.keys()).index(endpoint_key)
            self.beginRemoveRows(QModelIndex(), row, row)
            del self.endpoints[endpoint_key]
            self.endRemoveRows()
            self.totalEndpointsSignal.emit(len(self.endpoints))
        else:
            for endpKey in self.endpoints.keys():
                if str(endpoint_key) in self.endpoints[endpKey].missmatches:
                    del self.endpoints[endpKey].missmatches[str(endpoint_key)]
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
