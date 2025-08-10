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

from PySide6.QtCore import Qt, QAbstractItemModel, Qt, Slot, Signal
from cyclonedds.builtin import DcpsParticipant
from loguru import logger as logging
from pathlib import Path
import uuid
import psutil
import socket

from dds_access import dds_data
from dds_access.dds_utils import getAppName, getHostname


class GraphModel(QAbstractItemModel):

    requestParticipants = Signal(str)
    requestDomainIds = Signal(str)

    newNodeSignal = Signal(str, str, str, str)
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
        hostName = socket.gethostname()
        self.selfName = f"{hostName}:{Path(proc.exe()).stem}:{proc.pid}"

        self.dds_data = dds_data.DdsData()

        # self to dds_data
        self.requestParticipants.connect(self.dds_data.requestParticipants, Qt.ConnectionType.QueuedConnection)
        self.requestDomainIds.connect(self.dds_data.requestDomainIds, Qt.ConnectionType.QueuedConnection)

        # From dds_data to self
        self.dds_data.new_participant_signal.connect(self.newParticipantSlot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_participant_signal.connect(self.removedParticipantSlot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.response_participants_signal.connect(self.response_participants_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_domain_signal.connect(self.newDomainSlot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_domain_signal.connect(self.removedDomainSlot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.response_domain_ids_signal.connect(self.responseDomainIdsSlot, Qt.ConnectionType.QueuedConnection)

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

        self.requestDomainIds.emit(self.currentRequestId)
        self.requestParticipants.emit(self.currentRequestId)

    @Slot(int)
    def newDomainSlot(self, domain_id: int):
        if not self.acceptDomainId(domain_id):
            return
        
        domainIdStr = f"Domain {domain_id}"
        if domain_id not in self.domainIds.keys():
            self.domainIds[domain_id] = []
            self.newNodeSignal.emit(domainIdStr, domainIdStr, "", "")

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
        nodeKey = f"{host}:{appName}"

        if nodeKey == self.selfName and self.ignoreSelf:
            return

        domainIdStr = f"Domain {domain_id}"

        if domain_id not in self.domainIds.keys():
            self.domainIds[domain_id] = [str(participant.key)]
            self.newNodeSignal.emit(domainIdStr, domainIdStr, "", "")
        else:
            if str(participant.key) not in self.domainIds[domain_id]:
                self.domainIds[domain_id].append(str(participant.key))

        if nodeKey not in self.appNames.keys():
            self.appNames[nodeKey] = {
                domain_id: [str(participant.key)]
            }
        else:
            if domain_id not in self.appNames[nodeKey]:
                self.appNames[nodeKey][domain_id] = [str(participant.key)]
            else:
                self.appNames[nodeKey][domain_id].append(str(participant.key))

        self.newNodeSignal.emit(nodeKey, appName, domainIdStr, host)

    @Slot(int, str)
    def removedParticipantSlot(self, domainId: int, participantKey: str):
        toBeRemovedApps = []
        for appName in list(self.appNames.keys()):
            if domainId in self.appNames[appName]:
                if participantKey in self.appNames[appName][domainId]:
                    self.appNames[appName][domainId].remove(participantKey)

                    # Check if appName is present in any other domain with participants
                    found_in_other_domain = any(
                        domain != domainId and len(self.appNames[appName][domain]) > 0
                        for domain in self.appNames[appName]
                    )
                    if not found_in_other_domain:
                        if len(self.appNames[appName][domainId]) == 0:
                            toBeRemovedApps.append(appName)

                    if len(self.appNames[appName][domainId]) == 0:
                        self.removeEdgeBetweenNodes.emit(appName, f"Domain {domainId}")

        for remApp in toBeRemovedApps:
            if remApp in self.appNames.keys():
                del self.appNames[remApp]
                self.removeNodeSignal.emit(remApp, "")

    @Slot(int)
    def removedDomainSlot(self, domainId: int):
        if domainId in self.domainIds.keys():
            del self.domainIds[domainId]
            self.removeNodeSignal.emit(f"Domain {domainId}", "")

    @Slot(str, list)
    def responseDomainIdsSlot(self, requestId: str, domainIds):
        if requestId != self.currentRequestId:
            return

        for domainId in domainIds:
            if self.acceptDomainId(domainId):
                if domainId not in self.domainIds.keys():
                    self.domainIds[domainId] = []
                    domainIdStr = f"Domain {domainId}"
                    self.newNodeSignal.emit(domainIdStr, domainIdStr, "", "")
