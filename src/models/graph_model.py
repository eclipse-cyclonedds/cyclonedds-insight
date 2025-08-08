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
from dds_access.datatypes.entity_type import EntityType
from dds_access.dds_utils import getProperty, DEBUG_MONITORS, getAppName, getHostname


class GraphModel(QAbstractItemModel):

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

    totalEndpointsSignal = Signal(int)

    requestEndpointsSignal = Signal(str, int, str, EntityType)
    requestParticipants = Signal(str)

    newNodeSignal = Signal(str, str, str)
    removeNodeSignal = Signal(str, str)


    def __init__(self, parent=None):
        super(GraphModel, self).__init__(parent)
        logging.debug(f"New instance GraphModel: {str(self)} id: {id(self)}")

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
        self.hostnames = []
        self.appNames = {}
        self.domainIds = []

        self.dds_data = dds_data.DdsData()
        # self to dds_data
        self.requestEndpointsSignal.connect(self.dds_data.requestEndpointsSlot, Qt.ConnectionType.QueuedConnection)

        self.requestParticipants.connect(self.dds_data.requestParticipants, Qt.ConnectionType.QueuedConnection)

        # From dds_data to self
        self.dds_data.new_endpoint_signal.connect(self.new_endpoint_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_endpoint_signal.connect(self.remove_endpoint_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_participant_signal.connect(self.newParticipantSlot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_participant_signal.connect(self.removedParticipantSlot, Qt.ConnectionType.QueuedConnection)

        self.dds_data.response_participants_signal.connect(self.response_participants_slot, Qt.ConnectionType.QueuedConnection)


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

    @Slot(int)
    def setDomainId(self, domain_id: int):

        logging.debug(f"init endpoint model {id(self)}")

        self.beginResetModel()

        self.domain_id = domain_id

        self.endpoints = {}
        self.hostnames = []
        self.appNames = {}

        self.currentRequestId = str(uuid.uuid4())

        self.endResetModel()


        self.requestParticipants.emit(self.currentRequestId)

    @Slot(int, str)
    def removedParticipantSlot(self, domainId: int, participantKey: str):
        for appName in list(self.appNames.keys()):
            if participantKey in self.appNames[appName]:
                self.appNames[appName].remove(participantKey)
                if not self.appNames[appName]:
                    del self.appNames[appName]
                    self.removeNodeSignal.emit(appName, f"Domain {domainId}")

    @Slot(str, int, object)
    def response_participants_slot(self, request_id: str, domain_id: int, participants):
        if request_id != self.currentRequestId:
            return

        for participant in participants:
            self.newParticipant(domain_id, participant)

    @Slot(int, DcpsParticipant)
    def newParticipantSlot(self, domain_id: int, participant: DcpsParticipant):
        self.newParticipant(domain_id, participant)

    def newParticipant(self, domain_id: int, participant: DcpsParticipant):

        appName: str = getAppName(participant)
        host: str = getHostname(participant)

        domainIdStr = f"Domain {domain_id}"
        if domainIdStr not in self.domainIds:
            self.domainIds.append(domainIdStr)
            self.newNodeSignal.emit(domainIdStr, "", host)

        #if host not in self.hostnames:
        #    self.hostnames.append(host)
        #    self.newNodeSignal.emit(host, domainIdStr)

        if appName not in self.appNames.keys():
            self.appNames[appName] = [str(participant.key)]
            self.newNodeSignal.emit(appName, domainIdStr, host)
        else:
            if str(participant.key) not in self.appNames[appName]:
                self.appNames[appName].append(str(participant.key))

    @Slot(str, int, DataEndpoint)
    def new_endpoint_slot(self, requestId: str, domain_id: int, endpointData: DataEndpoint):
        if self.currentRequestId != requestId and requestId != "":
            return
        if domain_id != self.domain_id:
            return


    @Slot(int, str)
    def remove_endpoint_slot(self, domain_id, endpoint_key):
        if domain_id != self.domain_id:
            return


