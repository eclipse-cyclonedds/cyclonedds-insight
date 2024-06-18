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

from PySide6.QtCore import Qt, QModelIndex, QAbstractItemModel, Qt, Slot, Signal
from cyclonedds.builtin import DcpsEndpoint, DcpsParticipant
from cyclonedds import core
import logging
import os

import dds_data
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

    participants = {}
    endpoints = {}
    domain_id = -1
    topic_name = ""
    entity_type = EntityType.UNDEFINED
    topic_has_mismatch = False
    mismatches = {}

    topicHasQosMismatchSignal = Signal(bool)

    def __init__(self, parent=None):
        super(EndpointModel, self).__init__(parent)
        logging.debug("New instance EndpointModel:" + str(self))
        self.dds_data = dds_data.DdsData()
        # From dds_data to self
        self.dds_data.new_endpoint_signal.connect(self.new_endpoint_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_endpoint_signal.connect(self.remove_endpoint_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_participant_signal.connect(self.new_participant, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_participant_signal.connect(self.removed_participant, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_mismatch_signal.connect(self.new_qos_mismatch, Qt.ConnectionType.QueuedConnection)
        self.dds_data.no_more_mismatch_in_topic_signal.connect(self.no_more_mismatch_in_topic_slot, Qt.ConnectionType.QueuedConnection)

    def index(self, row, column, parent=QModelIndex()):
        return self.createIndex(row, column)

    def rowCount(self, parent=QModelIndex()):
        return len(self.endpoints.keys())

    def parent(self, index):
        return QModelIndex()

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()
        endp_key = list(self.endpoints.keys())[row]
        endp: DcpsEndpoint = self.endpoints[endp_key]

        hostname = "Unknown"
        appname = "Unknown"
        pid = "Unknown"
        if str(endp.participant_key) in self.participants.keys():
            p = self.participants[str(endp.participant_key)]
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
            return os.path.basename(appname)
        elif role == self.EndpointHasQosMismatch:
            if endp_key in self.mismatches.keys():
                return True
            return False
        elif role == self.EndpointQosMismatchText:
            qos_mm_txt = ""
            if endp_key in self.mismatches.keys():
                qos_mm_txt += "\nQos-Mismatches:\n"
                for idx, endp_mm in enumerate(self.mismatches[endp_key].keys()):
                    for idx_mm, mm_type in enumerate(self.mismatches[endp_key][endp_mm]):
                        qos_mm_txt += "  " + str(mm_type) + " with " + str(endp_mm)
                        if idx_mm < len(self.mismatches[endp_key][endp_mm]) - 1:
                            qos_mm_txt += "\n"
                    if idx < len(self.mismatches[endp_key].keys()) - 1:
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
        self.beginResetModel()
        self.domain_id = domain_id
        self.entity_type = EntityType(entity_type)
        self.topic_name = topic_name
        self.endpoints = {}
        self.participants = {}
        self.mismatches = {}

        for parti in self.dds_data.getParticipants(domain_id):
            self.participants[str(parti.key)] = parti

        for (entity_end, endpoint) in self.dds_data.getEndpoints(domain_id):
            if entity_end == self.entity_type and endpoint.topic_name == self.topic_name:
                self.endpoints[str(endpoint.key)] = endpoint

        self.mismatches = self.dds_data.getQosMismatches(domain_id, topic_name)

        self.endResetModel()

        if len(self.mismatches.keys()) > 0:
            self.topicHasQosMismatchSignal.emit(True)
        else:
            self.topicHasQosMismatchSignal.emit(False)

    @Slot(int, DcpsEndpoint, EntityType)
    def new_endpoint_slot(self, domain_id: int, endpoint: DcpsEndpoint, entity_type: EntityType):
        if domain_id != self.domain_id:
            return
        if entity_type != self.entity_type:
            return
        if endpoint.topic_name != self.topic_name:
            return

        self.beginResetModel()
        self.endpoints[str(endpoint.key)] = endpoint
        self.endResetModel()

    @Slot(int, str)
    def remove_endpoint_slot(self, domain_id, endpoint_key):
        if domain_id != self.domain_id:
            return

        if endpoint_key in self.endpoints.keys():
            self.beginResetModel()
            del self.endpoints[endpoint_key]
            self.endResetModel()

    @Slot(int, DcpsParticipant)
    def new_participant(self, domain_id, participant: DcpsParticipant):
        if domain_id != self.domain_id:
            return

        if str(participant.key) not in self.participants.keys():
            self.beginResetModel()
            self.participants[str(participant.key)] = participant
            self.endResetModel()

    @Slot(int, str)
    def removed_participant(self, domain_id, key: str):
        if domain_id != self.domain_id:
            return

        if key in self.participants.keys():
            self.beginResetModel()
            del self.participants[key]
            self.endResetModel()

    @Slot(int, str, str, list, str)
    def new_qos_mismatch(self, domain_id, topic_name, endpoint_key, mismatches, endpoint_key_mm):
        if domain_id != self.domain_id or topic_name != self.topic_name:
            return

        self.topicHasQosMismatchSignal.emit(True)
        if endpoint_key not in self.mismatches.keys():
            self.mismatches[endpoint_key] = {}
        
        self.mismatches[endpoint_key][endpoint_key_mm] = mismatches

        if str(endpoint_key) in self.endpoints.keys():
            idx = list(self.endpoints.keys()).index(endpoint_key)
            index = self.createIndex(idx, 0)
            self.dataChanged.emit(index, index, [self.EndpointHasQosMismatch, self.EndpointQosMismatchText])

    @Slot(int, str)
    def no_more_mismatch_in_topic_slot(self, domain_id, topic_name):
        if domain_id != self.domain_id or topic_name != self.topic_name:
            return

        self.mismatches = {}
        self.topicHasQosMismatchSignal.emit(False)

        for idx, _ in enumerate(list(self.endpoints.keys())):
            index = self.createIndex(idx, 0)
            self.dataChanged.emit(index, index, [self.EndpointHasQosMismatch, self.EndpointQosMismatchText])
