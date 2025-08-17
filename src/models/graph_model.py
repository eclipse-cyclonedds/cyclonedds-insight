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

from PySide6.QtCore import Qt, QAbstractItemModel, Qt, Slot, Signal, QThread
from cyclonedds.builtin import DcpsParticipant
from loguru import logger as logging
from pathlib import Path
from dds_access import dds_utils
from threading import Lock
import uuid
import time
import psutil
import requests
import socket

from dds_access import dds_data
from dds_access.dds_utils import getAppName, getHostname, isVendorCycloneDDS, getProperty, DEBUG_MONITORS


class GraphStatisticThread(QThread):

    onData = Signal(int, str, str, float)
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__()
        self.running = False
        self.mutex = Lock()
        self.pollIntervalSeconds = 3
        self.sent_bytes = {}
        self.received_bytes = {}
        self.dgbPorts = {}
        self.dgbPortsRequest = {}
        self.dgbPortChangeRequest = False

    def pollData(self):
        logging.debug("GraphStatisticThread: Polling data")
        already_processed_ip_port = []
        for participant_key in self.dgbPorts.keys():
            (ip, port, _, _) = self.dgbPorts[participant_key]
            if f"{ip}:{port}" in already_processed_ip_port:
                continue
            already_processed_ip_port.append(f"{ip}:{port}")

            json_data = {}
            try:
                url = "http://" + ip + ":" + port + "/"
                response = requests.get(url, timeout=(3, 5), verify=False, headers={'Connection': 'close'})
                response.raise_for_status()
                json_data = response.json()
                # logging.trace(json.dumps(json_data, indent=4))
            except Exception as e:
                logging.error(str(e))
                continue

            if "participants" in json_data:
                for participant in json_data["participants"]:
                    pKeyCurrent = dds_utils.normalizeGuid(participant["guid"])
                    if pKeyCurrent not in self.dgbPorts:
                        continue

                    (_, _, nodeKey, domainId) = self.dgbPorts[pKeyCurrent]
                    if domainId not in self.sent_bytes.keys():
                        self.sent_bytes[domainId] = {}
                        self.received_bytes[domainId] = {}

                    if "writers" in participant:
                        for writer in participant["writers"]:
                            if "sent_bytes" in writer:
                                if nodeKey in self.sent_bytes:
                                    self.sent_bytes[domainId][nodeKey] += writer["sent_bytes"]
                                else:
                                    self.sent_bytes[domainId][nodeKey] = writer["sent_bytes"]

                    if "readers" in participant:
                        for reader in participant["readers"]:
                            if "received_bytes" in reader:
                                if nodeKey in self.received_bytes:
                                    self.received_bytes[domainId][nodeKey] += reader["received_bytes"]
                                else:
                                    self.received_bytes[domainId][nodeKey] = reader["received_bytes"]

        # Calculate bytes per second for sent and received
        bps_sent = {}
        bps_received = {}

        current_time = time.monotonic()
        if not hasattr(self, "last_poll_time"):
            self.last_poll_time = current_time
            self.last_sent_bytes = {k: v.copy() for k, v in self.sent_bytes.items()}
            self.last_received_bytes = {k: v.copy() for k, v in self.received_bytes.items()}
            return

        elapsed = current_time - self.last_poll_time
        for domain_id in self.sent_bytes:
            bps_sent[domain_id] = {}
            for nodeKey in self.sent_bytes[domain_id]:
                prev = self.last_sent_bytes.get(domain_id, {}).get(nodeKey, 0)
                curr = self.sent_bytes[domain_id][nodeKey]
                bps_sent[domain_id][nodeKey] = (curr - prev) / elapsed if elapsed > 0 else 0

        for domain_id in self.received_bytes:
            bps_received[domain_id] = {}
            for nodeKey in self.received_bytes[domain_id]:
                prev = self.last_received_bytes.get(domain_id, {}).get(nodeKey, 0)
                curr = self.received_bytes[domain_id][nodeKey]
                bps_received[domain_id][nodeKey] = (curr - prev) / elapsed if elapsed > 0 else 0

        self.last_poll_time = current_time
        self.last_sent_bytes = {k: v.copy() for k, v in self.sent_bytes.items()}
        self.last_received_bytes = {k: v.copy() for k, v in self.received_bytes.items()}

        for domain_id in bps_sent.keys():
            for nodeKey in bps_sent[domain_id].keys():
                self.onData.emit(domain_id, nodeKey, "sent", bps_sent[domain_id][nodeKey])

        for domain_id in bps_received.keys():
            for nodeKey in bps_received[domain_id].keys():
                self.onData.emit(domain_id, nodeKey, "recv", bps_received[domain_id][nodeKey])

    def run(self):
        self.running = True

        start_time = time.monotonic()
        while self.running:
            if time.monotonic() - start_time >= self.pollIntervalSeconds:
                with self.mutex:
                    self.pollData()
                    if self.dgbPortChangeRequest:
                        self.dgbPorts = self.dgbPortsRequest.copy()

                start_time = time.monotonic()  # reset the timer
            else:
                time.sleep(0.1) # fast exit

    def stop(self):
        self.running = False

    def setDbgPorts(self, dgbPorts):
        with self.mutex:
            self.dgbPortsRequest = dgbPorts.copy()
            self.dgbPortChangeRequest = True

class GraphModel(QAbstractItemModel):

    requestParticipants = Signal(str)
    requestDomainIds = Signal(str)

    newNodeSignal = Signal(str, str, str, str, bool)
    removeNodeSignal = Signal(str, str)
    removeEdgeBetweenNodes = Signal(str, str)
    updateEdgeSignal = Signal(str, str, str, float)

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

        self.dgbPorts = {}
        self.graphStatistics = GraphStatisticThread(self)
        self.graphStatistics.onData.connect(self.onGraphStatisticsData, Qt.ConnectionType.QueuedConnection)

    def acceptDomainId(self, domain_id: int):
        return self.domain_id == -1 or self.domain_id == domain_id

    @Slot(int, bool, bool)
    def setDomainId(self, domain_id: int, ignoreSelf: bool, speedEnabled: bool):

        logging.debug(f"init graph model {id(self)}")

        self.domain_id = domain_id
        self.ignoreSelf = ignoreSelf

        self.endpoints = {}
        self.appNames = {}
        self.currentRequestId = str(uuid.uuid4())

        self.requestDomainIds.emit(self.currentRequestId)
        self.requestParticipants.emit(self.currentRequestId)

        if speedEnabled:
            self.start()

    @Slot(int)
    def newDomainSlot(self, domain_id: int):
        if not self.acceptDomainId(domain_id):
            return
        
        domainIdStr = f"Domain {domain_id}"
        if domain_id not in self.domainIds.keys():
            self.domainIds[domain_id] = []
            self.newNodeSignal.emit(domainIdStr, domainIdStr, "", "", False)

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
            self.newNodeSignal.emit(domainIdStr, domainIdStr, "", "", False)
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

        self.newNodeSignal.emit(nodeKey, appName, domainIdStr, host, isVendorCycloneDDS(participant))

        # Extracting debug monitor address
        dbg_mon_str: str = getProperty(participant, DEBUG_MONITORS)
        splitProtoAdr = dbg_mon_str.split("/")
        if len(splitProtoAdr) > 0:
            if splitProtoAdr[0] == "tcp":
                splitIpPort = splitProtoAdr[1].split(":")
                if len(splitIpPort) > 1:
                    ip = splitIpPort[0]
                    port = splitIpPort[1]
                    self.dgbPorts[str(participant.key)] = (ip, port, nodeKey, domain_id)
        
        self.graphStatistics.setDbgPorts(self.dgbPorts)

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

        if participantKey in self.dgbPorts:
            del self.dgbPorts[participantKey]
        self.graphStatistics.setDbgPorts(self.dgbPorts)

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
                    self.newNodeSignal.emit(domainIdStr, domainIdStr, "", "", False)

    @Slot(int, str, str, float)
    def onGraphStatisticsData(self, domain_id: int, nodeKey: str, t: str, bps: float):
        logging.debug(f"GraphModel: onGraphStatisticsData domain_id: {domain_id}, nodeKey: {nodeKey}, bps: {bps}")
        self.updateEdgeSignal.emit(f"Domain {domain_id}", nodeKey, t, bps)

    @Slot()
    def start(self):
        if not self.graphStatistics.isRunning():
            logging.debug("Starting GraphStatistics thread")
            self.graphStatistics.start()
        else:
            logging.warning("GraphStatistics thread is already running.")

    @Slot()
    def stop(self):
        logging.debug("Stopping GraphStatistics thread")
        self.graphStatistics.stop()
        self.graphStatistics.wait()
        logging.debug("GraphStatistics thread stopped")
