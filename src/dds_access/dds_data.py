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

from PySide6.QtCore import QObject, Signal, Slot, QThread, Qt
from cyclonedds.builtin import DcpsEndpoint, DcpsParticipant
from loguru import logger as logging
import time
import copy
from queue import Queue
from typing import Dict, List, Optional
import gc

from dds_access.builtin_observer import BuiltInObserver
from dds_access.dds_utils import getDataType
from dds_access.dds_qos import qos_match, dds_qos_policy_id
from dds_access.datatypes.entity_type import EntityType
from utils.singleton import singleton

class DataEndpoint:
    def __init__(self, endpoint: DcpsEndpoint, entity_type) -> None:
        self.endpoint: DcpsEndpoint = endpoint
        self.entity_type: EntityType = entity_type
        self.participant = None
        self.mismatches : Dict[str, List[dds_qos_policy_id]]= {}

    def isReader(self):
        return self.entity_type == EntityType.READER

    def isWriter(self):
        return self.entity_type == EntityType.WRITER

    def link_participant(self, participant: DcpsParticipant):
        if str(self.endpoint.participant_key) == str(participant.key):
            self.participant = participant


class DataTopic:
    def __init__(self, name) -> None:
        self.name = name
        self.reader_endpoints: Dict[str, DataEndpoint] = {}
        self.writer_endpoints: Dict[str, DataEndpoint] = {}

    def add_endpoint(self, endpoint: DataEndpoint):
        if endpoint.isReader():
            if str(endpoint.endpoint.key) not in self.reader_endpoints:
                self.reader_endpoints[str(endpoint.endpoint.key)] = endpoint
        else:
            if str(endpoint.endpoint.key) not in self.writer_endpoints:
                self.writer_endpoints[str(endpoint.endpoint.key)] = endpoint

        self.check_qos_mismatch(endpoint)

    def remove_endpoint(self, endpointKey: str):
        if endpointKey in self.reader_endpoints:
            for mimKey in self.reader_endpoints[endpointKey].mismatches:
                if mimKey in self.writer_endpoints:
                    if endpointKey in self.writer_endpoints[mimKey].mismatches:
                        del self.writer_endpoints[mimKey].mismatches[endpointKey]

            del self.reader_endpoints[endpointKey]
    
        if endpointKey in self.writer_endpoints:
            for mimKey in self.writer_endpoints[endpointKey].mismatches:
                if mimKey in self.reader_endpoints:
                    if endpointKey in self.reader_endpoints[mimKey].mismatches:
                        del self.reader_endpoints[mimKey].mismatches[endpointKey]

            del self.writer_endpoints[endpointKey]

    def link_participant(self, participant: DcpsParticipant):
        for reader_key in self.reader_endpoints.keys():
            self.reader_endpoints[reader_key].link_participant(participant)
        for writer_key in self.writer_endpoints.keys():
            self.writer_endpoints[writer_key].link_participant(participant)

    def hasEndpoints(self) -> bool:
        return len(self.reader_endpoints) > 0 or len(self.writer_endpoints) > 0

    def check_qos_mismatch(self, data_endpoint: DataEndpoint):

        endpoints_to_check = self.reader_endpoints
        if data_endpoint.isReader():
            endpoints_to_check = self.writer_endpoints

        for endpKey in endpoints_to_check.keys():
            endpoint_to_check = endpoints_to_check[endpKey]

            mismatches: List[dds_qos_policy_id] = []
            if data_endpoint.isReader():
                mismatches = qos_match(data_endpoint.endpoint, endpoint_to_check.endpoint)
            else:
                mismatches = qos_match(endpoint_to_check.endpoint, data_endpoint.endpoint)

            if len(mismatches) > 0:
                data_endpoint.mismatches[str(endpoint_to_check.endpoint.key)] = mismatches
                endpoint_to_check.mismatches[str(data_endpoint.endpoint.key)] = mismatches

    def get_mismatches(self) -> List[str]:
        mism_endp_keys: List[str] = []
        for endpKey in self.reader_endpoints.keys():
            if len(self.reader_endpoints[endpKey].mismatches):
                mism_endp_keys += self.reader_endpoints[endpKey].mismatches.keys()
        for endpKey in self.writer_endpoints.keys():
            if len(self.writer_endpoints[endpKey].mismatches):
                mism_endp_keys += self.writer_endpoints[endpKey].mismatches.keys()

        return list(dict.fromkeys(mism_endp_keys))

    def getEndpointWithTypeId(self, topicTypeName) -> Optional[DataEndpoint]:
        for endpKey in self.reader_endpoints.keys():
            if self.reader_endpoints[endpKey].endpoint.type_name == topicTypeName:
                if self.reader_endpoints[endpKey].endpoint.type_id:
                    return self.reader_endpoints[endpKey]
        for endpKey in self.writer_endpoints.keys():
            if self.writer_endpoints[endpKey].endpoint.type_name == topicTypeName:
                if self.writer_endpoints[endpKey].endpoint.type_id:
                    return self.writer_endpoints[endpKey]

class DataDomain:
    def __init__(self, domain_id: int, queue) -> None:
        self.domain_id = domain_id
        self.topics: Dict[str, DataTopic] = {}
        self.endpointToTopic = {} # shortcut for deletion where only endp key is available
        self.participants = {}
        self.pending_participant_updates = {}
        self.obs_thread = BuiltInObserver(domain_id, queue)
        self.obs_thread.start()

    def add_participant(self, participant: DcpsParticipant):
        self.participants[str(participant.key)] = participant
        if str(participant.key) in self.pending_participant_updates:
            self.update_participant(self.pending_participant_updates[str(participant.key)])
            del self.pending_participant_updates[str(participant.key)]
        for topic in self.topics.keys():
            self.topics[topic].link_participant(participant)

    def update_participant(self, update_participant: DcpsParticipant) -> Optional[DcpsParticipant]:
        if str(update_participant.key) in self.participants:
            self.participants[str(update_participant.key)].qos += update_participant.qos
            return self.participants[str(update_participant.key)]
        else:
            self.pending_participant_updates[str(update_participant.key)] = update_participant
            return None

    def remove_participant(self, key: str):
        if key in self.participants:
            del self.participants[key]
        if key in self.pending_participant_updates:
            del self.pending_participant_updates[key]

    def add_endpoint(self, dataEndpoint: DataEndpoint):
        self.endpointToTopic[str(dataEndpoint.endpoint.key)] = str(dataEndpoint.endpoint.topic_name)
        if str(dataEndpoint.endpoint.topic_name) not in self.topics:
            self.topics[str(dataEndpoint.endpoint.topic_name)] = DataTopic(str(dataEndpoint.endpoint.topic_name))

        if str(dataEndpoint.endpoint.participant_key) in self.participants:
            dataEndpoint.link_participant(self.participants[str(dataEndpoint.endpoint.participant_key)])

        self.topics[str(dataEndpoint.endpoint.topic_name)].add_endpoint(dataEndpoint)

    def remove_endpoint(self, endpoint_key: str):
        if endpoint_key in self.endpointToTopic:
            topicName = self.endpointToTopic[endpoint_key]
            if topicName in self.topics:
                self.topics[topicName].remove_endpoint(endpoint_key)
                del self.endpointToTopic[endpoint_key]

                if not self.topics[topicName].hasEndpoints():
                    del self.topics[topicName]

    def has_topic(self, topicName: str) -> bool:
        return topicName in self.topics

    def get_topic_name(self, endpointKey: str) -> bool:
        if endpointKey in self.endpointToTopic:
            return self.endpointToTopic[endpointKey]
        return ""

    def getTopic(self, topicName: str) -> Optional[DataTopic]:
        if self.has_topic(topicName):
            return self.topics[topicName]
        else:
            return None

    def getEndpoints(self, topicName: str, entity_type: EntityType):
        if topicName in self.topics:
            if entity_type == EntityType.READER:
                return self.topics[topicName].reader_endpoints
            else:
                return self.topics[topicName].writer_endpoints
        return {}

    def getEndpointsByParticipantKey(self, participantKey: str) -> List[DataEndpoint]:
        endpoints = []
        if participantKey in self.participants:
            for topic in self.topics.keys():
                for endpKey in self.topics[topic].reader_endpoints.keys():
                    if str(self.topics[topic].reader_endpoints[endpKey].endpoint.participant_key) == participantKey:
                        endpoints.append(self.topics[topic].reader_endpoints[endpKey])
                for endpKey in self.topics[topic].writer_endpoints.keys():
                    if str(self.topics[topic].writer_endpoints[endpKey].endpoint.participant_key) == participantKey:
                        endpoints.append(self.topics[topic].writer_endpoints[endpKey])
        return endpoints

    def __del__(self):
        self.obs_thread.stop()
        self.obs_thread.wait()

class BuiltInReceiver(QObject):

    newParticipantSignal = Signal(int, DcpsParticipant)
    newEndpointSignal = Signal(int, DcpsParticipant, EntityType)
    removeParticipantSignal = Signal(int, DcpsParticipant)
    removeEndpointSignal = Signal(int, DcpsParticipant)
    updateParticipantSignal = Signal(int, DcpsParticipant)

    def __init__(self, queue):
        super().__init__()
        self.queue = queue
        self.running = True

    def run(self):
        logging.info(f"Running BuiltInReceiver ... (thread: {QThread.currentThread()})")

        while self.running:
            time.sleep(2)

            while self.running:
                if self.queue.empty():
                    break

                item = self.queue.get()
                if item is None:
                    break

                for (domain_id, participant) in item.new_participants:
                    self.newParticipantSignal.emit(domain_id, participant)

                for (domain_id, participant) in item.remove_participants:
                    self.removeParticipantSignal.emit(domain_id, participant)

                for (domain_id, endpoint, entity_type) in item.new_endpoints:
                    self.newEndpointSignal.emit(domain_id, endpoint, entity_type)

                for (domain_id, endpoint) in item.remove_endpoints:
                    self.removeEndpointSignal.emit(domain_id, endpoint)

                for (domain_id, endpoint_update) in item.update_participants:
                    self.updateParticipantSignal.emit(domain_id, endpoint_update)

        logging.info("Running BuiltInReceiver ... DONE")

    def stop(self):
        self.running = False

@singleton
class DdsData(QObject):

    # domain observer threads
    observer_threads = {}

    # signals and slots
    new_topic_signal = Signal(int, str)
    remove_topic_signal = Signal(int, str)
    new_domain_signal = Signal(int)
    removed_domain_signal = Signal(int)
    new_endpoint_signal = Signal(str, int, DataEndpoint)
    removed_endpoint_signal = Signal(int, str)
    new_participant_signal = Signal(int, DcpsParticipant)
    removed_participant_signal = Signal(int, str)
    update_participant_signal = Signal(int, DcpsParticipant)

    response_data_type_signal = Signal(str, object)
    response_endpoints_by_participant_key_signal = Signal(str, int, DataEndpoint)

    no_more_mismatch_in_topic_signal = Signal(int, str)
    publish_mismatch_signal = Signal(int, str, list)

    the_domains: Dict[int, DataDomain] = {}

    queue = Queue()

    def __init__(self):
        super().__init__()
        logging.trace("Construct DdsData")
        self.receiverThread: QThread = QThread()
        self.receiver: BuiltInReceiver = BuiltInReceiver(self.queue)
        self.receiver.moveToThread(self.receiverThread)
        self.receiver.newParticipantSignal.connect(self.add_domain_participant, Qt.ConnectionType.QueuedConnection)
        self.receiver.newEndpointSignal.connect(self.add_endpoint, Qt.ConnectionType.QueuedConnection)
        self.receiver.removeParticipantSignal.connect(self.remove_domain_participant, Qt.ConnectionType.QueuedConnection)
        self.receiver.removeEndpointSignal.connect(self.remove_endpoint, Qt.ConnectionType.QueuedConnection)
        self.receiver.updateParticipantSignal.connect(self.update_domain_participant, Qt.ConnectionType.QueuedConnection)
        self.receiverThread.started.connect(self.receiver.run)
        self.receiverThread.finished.connect(self.receiver.deleteLater)
        self.receiverThread.start()

    def join_observer(self):
        self.receiver.stop()
        self.receiverThread.quit()
        self.receiverThread.wait()
        self.the_domains.clear()
        gc.collect()

    def add_domain(self, domain_id: int):
        if domain_id in self.the_domains:
            return
        self.the_domains[domain_id] = DataDomain(domain_id, self.queue)
        self.new_domain_signal.emit(domain_id)

    @Slot(int)
    def remove_domain(self, domain_id: int):
        if domain_id in self.the_domains:
            del self.the_domains[domain_id]
            gc.collect()

        self.removed_domain_signal.emit(domain_id)

    @Slot(int, DcpsParticipant)
    def add_domain_participant(self, domain_id: int, participant: DcpsParticipant):
        logging.debug(f"Add domain participant {str(participant.key)}")

        if domain_id in self.the_domains:
            self.the_domains[domain_id].add_participant(participant)
            self.new_participant_signal.emit(domain_id, participant)

    @Slot(int, DcpsParticipant)
    def remove_domain_participant(self, domain_id: int, participant: DcpsParticipant):
        logging.debug(f"Remove domain participant: {str(participant.key)}")
        if domain_id in self.the_domains:
            self.the_domains[domain_id].remove_participant(str(participant.key))
            self.removed_participant_signal.emit(domain_id, str(participant.key))

    @Slot(int, DcpsParticipant)
    def update_domain_participant(self, domain_id: int, participant_update: DcpsParticipant):
        logging.debug(f"Update domain participant: {str(participant_update.key)}")
        if domain_id in self.the_domains:
            updated = self.the_domains[domain_id].update_participant(participant_update)
            if updated:
                self.update_participant_signal.emit(domain_id, updated)

    @Slot(int, DcpsEndpoint, EntityType)
    def add_endpoint(self, domain_id: int, endpoint: DcpsEndpoint, entity_type: EntityType):
        logging.debug(f"Add endpoint domain: {domain_id}, key: {str(endpoint.key)}, entity: {entity_type}")

        if domain_id in self.the_domains:
            topic_already_known = self.the_domains[domain_id].has_topic(str(endpoint.topic_name))
            dataEndp = DataEndpoint(endpoint, entity_type)
            self.the_domains[domain_id].add_endpoint(dataEndp)

            if not topic_already_known:
                self.new_topic_signal.emit(domain_id, endpoint.topic_name)

            self.new_endpoint_signal.emit("", domain_id, copy.deepcopy(dataEndp))

            mismatches = self.the_domains[domain_id].topics[endpoint.topic_name].get_mismatches()
            if len(mismatches) > 0:
                self.publish_mismatch_signal.emit(domain_id, endpoint.topic_name, mismatches)

    @Slot(int, DcpsEndpoint)
    def remove_endpoint(self, domain_id: int, endpoint: DcpsEndpoint):
        logging.debug(f"Remove endpoint domain: {domain_id}, key: {str(endpoint.key)}")

        if domain_id in self.the_domains:

            topicName = self.the_domains[domain_id].get_topic_name(str(endpoint.key))

            self.the_domains[domain_id].remove_endpoint(str(endpoint.key))

            self.removed_endpoint_signal.emit(domain_id, str(endpoint.key))

            if not self.the_domains[domain_id].has_topic(topicName):
                logging.info(f"Removed last endpointon topic, topic gone {topicName}")
                self.remove_topic_signal.emit(domain_id, topicName)
            else:
                self.no_more_mismatch_in_topic_signal.emit(domain_id, topicName)
                mismatches = self.the_domains[domain_id].topics[topicName].get_mismatches()
                if len(mismatches) > 0:
                    self.publish_mismatch_signal.emit(domain_id, topicName, mismatches)

    @Slot(str, int, str, EntityType)
    def requestEndpointsSlot(self, requestId: str, domain_id: int, topic_name: str, entity_type: EntityType):
        if domain_id in self.the_domains:
            endDict = self.the_domains[domain_id].getEndpoints(topic_name, entity_type)
            for key in endDict.keys():
                self.new_endpoint_signal.emit(requestId, domain_id, copy.deepcopy(endDict[key]))

    @Slot(str, int, str, str)
    def requestDataType(self, requestId, domainId, topicType, topicName):
        logging.debug(f"requestDataType {requestId}, {domainId}, {topicType}, {topicName}")
        requestedDataType = None
        if domainId in self.the_domains:
            topic = self.the_domains[domainId].getTopic(topicName)
            if topic:
                endp = topic.getEndpointWithTypeId(topicType)
                if endp:
                    requestedDataType = getDataType(domainId, endp.endpoint)
                else:
                    logging.warning("endpoint not found")
            else:
                logging.warning("topic not found")
        else:
            logging.warning("domain not found")

        self.response_data_type_signal.emit(requestId, requestedDataType)

    @Slot(str, int, str)
    def requestEndpointsByParticipantKey(self, requestId: str, domainId: int, participantKey: str):
        logging.debug(f"requestEndpointsByParticipantKey {requestId}, {domainId}, {participantKey}")
        endpoints = []
        if domainId in self.the_domains:
            endpoints = self.the_domains[domainId].getEndpointsByParticipantKey(participantKey)

        self.response_endpoints_by_participant_key_signal.emit(requestId, domainId, endpoints)
