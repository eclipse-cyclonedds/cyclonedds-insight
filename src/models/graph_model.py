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
    removeEdgeBetweenNodes = Signal(str, str)


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
        self.domainIds = {}

        self.dds_data = dds_data.DdsData()

        # self to dds_data
        self.requestEndpointsSignal.connect(self.dds_data.requestEndpointsSlot, Qt.ConnectionType.QueuedConnection)
        self.requestParticipants.connect(self.dds_data.requestParticipants, Qt.ConnectionType.QueuedConnection)

        # From dds_data to self
        self.dds_data.new_participant_signal.connect(self.newParticipantSlot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_participant_signal.connect(self.removedParticipantSlot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.response_participants_signal.connect(self.response_participants_slot, Qt.ConnectionType.QueuedConnection)


    @Slot(int)
    def setDomainId(self, domain_id: int):

        logging.debug(f"init graph model {id(self)}")

        self.domain_id = domain_id

        self.endpoints = {}
        self.hostnames = []
        self.appNames = {}

        self.currentRequestId = str(uuid.uuid4())

        self.requestParticipants.emit(self.currentRequestId)


    @Slot(str, int, object)
    def response_participants_slot(self, request_id: str, domain_id: int, participants):
        if request_id != self.currentRequestId:
            return

        for participant in participants:
            self.newParticipant(domain_id, participant)

    def acceptDomainId(self, domain_id: int):
        return self.domain_id == -1 or self.domain_id == domain_id

    @Slot(int, DcpsParticipant)
    def newParticipantSlot(self, domain_id: int, participant: DcpsParticipant):
        self.newParticipant(domain_id, participant)

    def newParticipant(self, domain_id: int, participant: DcpsParticipant):

        if not self.acceptDomainId(domain_id):
            return

        appName: str = getAppName(participant)
        host: str = getHostname(participant)
        domainIdStr = f"Domain {domain_id}"

        if domain_id not in self.domainIds.keys():
            self.domainIds[domain_id] = [str(participant.key)]
            self.newNodeSignal.emit(domainIdStr, "", "")
        else:
            if str(participant.key) not in self.domainIds[domain_id]:
                self.domainIds[domain_id].append(str(participant.key))


        if appName not in self.appNames.keys():
            self.appNames[appName] = {
                domain_id: [str(participant.key)]
            }
        else:
            if domain_id not in self.appNames[appName]:
                self.appNames[appName][domain_id] = [str(participant.key)]
            else:
                self.appNames[appName][domain_id].append(str(participant.key))

        self.newNodeSignal.emit(appName, domainIdStr, host)

    @Slot(int, str)
    def removedParticipantSlot(self, domainId: int, participantKey: str):
        print(self.appNames)
        for appName in list(self.appNames.keys()):
            if domainId in self.appNames[appName]:
                if participantKey in self.appNames[appName][domainId]:
                    self.appNames[appName][domainId].remove(participantKey)

                    if len(self.appNames[appName][domainId]) == 0:
                        del self.appNames[appName][domainId]
                        #self.removeNodeSignal.emit(appName, f"Domain {domainId}")
                        self.removeEdgeBetweenNodes.emit(appName, f"Domain {domainId}")

                        if len(self.appNames[appName].keys()) == 0:
                            del self.appNames[appName]
                            self.removeNodeSignal.emit(appName, "")

        print(self.appNames)
