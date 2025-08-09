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
from loguru import logger as logging
from pathlib import Path
import uuid
import psutil

from dds_access import dds_data
from dds_access.dds_utils import getProperty, getHostname, PROCESS_NAMES, PIDS, ADDRESSES
from dds_access.datatypes.entity_type import EntityType
from dds_access.dds_utils import getProperty, DEBUG_MONITORS, getAppName, getHostname


class GraphModel(QAbstractItemModel):

    requestEndpointsSignal = Signal(str, int, str, EntityType)
    requestParticipants = Signal(str)

    newNodeSignal = Signal(str, str, str)
    removeNodeSignal = Signal(str, str)
    removeEdgeBetweenNodes = Signal(str, str)

    def __init__(self, parent=None):
        super(GraphModel, self).__init__(parent)
        logging.debug(f"New instance GraphModel: {str(self)} id: {id(self)}")

        self.domain_id = -1
        self.currentRequestId = str(uuid.uuid4())
        self.appNames = {}
        self.domainIds = {}
        self.ignoreSelf = False

        proc = psutil.Process()
        self.selfName = f"{Path(proc.name()).stem}:{proc.pid}"

        self.dds_data = dds_data.DdsData()

        # self to dds_data
        self.requestParticipants.connect(self.dds_data.requestParticipants, Qt.ConnectionType.QueuedConnection)

        # From dds_data to self
        self.dds_data.new_participant_signal.connect(self.newParticipantSlot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_participant_signal.connect(self.removedParticipantSlot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.response_participants_signal.connect(self.response_participants_slot, Qt.ConnectionType.QueuedConnection)

    def acceptDomainId(self, domain_id: int):
        return self.domain_id == -1 or self.domain_id == domain_id

    @Slot(int, bool)
    def setDomainId(self, domain_id: int, ignoreSelf: bool):

        logging.debug(f"init graph model {id(self)}")

        self.domain_id = domain_id
        self.ignoreSelf = ignoreSelf

        self.endpoints = {}
        self.appNames = {}
        self.currentRequestId = str(uuid.uuid4())

        self.requestParticipants.emit(self.currentRequestId)

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

        if not self.acceptDomainId(domain_id):
            return

        appName: str = getAppName(participant)
        host: str = getHostname(participant)
        domainIdStr = f"Domain {domain_id}"

        if appName == self.selfName and self.ignoreSelf:
            return

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
        for appName in list(self.appNames.keys()):
            if domainId in self.appNames[appName]:
                if participantKey in self.appNames[appName][domainId]:
                    self.appNames[appName][domainId].remove(participantKey)

                    if len(self.appNames[appName][domainId]) == 0:
                        del self.appNames[appName][domainId]
                        self.removeEdgeBetweenNodes.emit(appName, f"Domain {domainId}")

                        if len(self.appNames[appName].keys()) == 0:
                            del self.appNames[appName]
                            self.removeNodeSignal.emit(appName, "")
