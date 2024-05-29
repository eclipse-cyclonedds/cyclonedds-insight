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

from PySide6.QtCore import QObject, Signal, Slot
from cyclonedds.builtin import DcpsEndpoint, DcpsParticipant
import threading
import logging

from dds_service import builtin_observer
from dds_qos import qos_match
from utils import singleton, EntityType


@singleton
class DdsData(QObject):

    # domain observer threads
    observer_threads = {}
    mutex = threading.Lock()

    # signals and slots
    new_topic_signal = Signal(int, str)
    remove_topic_signal = Signal(int, str)
    new_domain_signal = Signal(int)
    removed_domain_signal = Signal(int)
    new_endpoint_signal = Signal(int, DcpsEndpoint, EntityType)
    removed_endpoint_signal = Signal(int, str)
    new_participant_signal = Signal(int, DcpsParticipant)
    removed_participant_signal = Signal(int, str)
    new_mismatch_signal = Signal(int, str, str, list, str)
    no_more_mismatch_in_topic_signal = Signal(int, str)

    # data store
    domains = []
    endpoints = {}
    participants = {}
    mismatches = {}

    def join_observer(self):
        for obs_key in self.observer_threads.keys():
            obs, obs_running = self.observer_threads[obs_key]
            obs_running[0] = False
            obs.join()

    def add_domain(self, domain_id: int):
        with self.mutex:
            if domain_id in self.domains:
                return

            self.domains.append(domain_id)
            obs_running = [True]

            obs_thread = threading.Thread(target=builtin_observer, args=(domain_id, self, obs_running))
            obs_thread.start()
            self.observer_threads[domain_id] = (obs_thread, obs_running)
            self.new_domain_signal.emit(domain_id)

    @Slot(int)
    def remove_domain(self, domain_id: int):
        with self.mutex:
            if domain_id in self.domains:
                self.domains.remove(domain_id)

            if domain_id in self.observer_threads.keys():
                obs, obs_running = self.observer_threads[domain_id]
                obs_running[0] = False
                obs.join()
                del self.observer_threads[domain_id]

            if domain_id in self.endpoints.keys():
                del self.endpoints[domain_id]

            self.removed_domain_signal.emit(domain_id)

    @Slot(int, DcpsParticipant)
    def add_domain_participant(self, domain_id: int, participant: DcpsParticipant):
        with self.mutex:
            logging.info(f"Add domain participant {str(participant.key)}")
            if domain_id in self.participants.keys():
                self.participants[domain_id].append(participant)
            else:
                self.participants[domain_id] = [participant]

            self.new_participant_signal.emit(domain_id, participant)

    @Slot(int, DcpsParticipant)
    def remove_domain_participant(self, domain_id: int, participant: DcpsParticipant):
        with self.mutex:
            if domain_id in self.participants.keys():
                available = -1
                for idx, participant_iter in enumerate(self.participants[domain_id]):
                    if participant.key == participant_iter.key:
                        available = idx
                        break

                if available != -1:
                    logging.info(f"Remove domain participant {str(participant.key)}")
                    del self.participants[domain_id][idx]
                    self.removed_participant_signal.emit(domain_id, str(participant.key))

    def check_qos_mismatches(self, domain_id):
        """Check the given domain if there are reader and writer
        with a qos mismatch. A signal is emitted on mismatch."""

        if domain_id in self.endpoints.keys():
            if domain_id in self.mismatches:
                del self.mismatches[domain_id]
            for (entity_type, endpoint) in self.endpoints[domain_id]:
                for (entity_type_iter, endpoint_iter) in self.endpoints[domain_id]:
                    if (endpoint.topic_name == endpoint_iter.topic_name and
                            endpoint.key != endpoint_iter.key and
                            entity_type_iter != entity_type):

                        if entity_type.READER and entity_type_iter.WRITER:
                            mismatches = qos_match(endpoint, endpoint_iter)
                        else:
                            mismatches = qos_match(endpoint_iter, endpoint)

                        if len(mismatches) > 0:
                            if domain_id not in self.mismatches.keys():
                                self.mismatches[domain_id] = {}

                            if str(endpoint.key) not in self.mismatches[domain_id]:
                                self.mismatches[domain_id][str(endpoint.key)] = {}

                            self.mismatches[domain_id][str(endpoint.key)][endpoint_iter.key] = mismatches
                            self.new_mismatch_signal.emit(domain_id, endpoint.topic_name, str(endpoint.key), mismatches, str(endpoint_iter.key))

    @Slot(int, DcpsEndpoint, EntityType)
    def add_endpoint(self, domain_id: int, endpoint: DcpsEndpoint, entity_type: EntityType):
        with self.mutex:
            # add endpoint
            logging.info(f"Add endpoint domain: {domain_id}, key: {str(endpoint.key)}, entity: {entity_type}")
            if domain_id in self.endpoints.keys():
                self.endpoints[domain_id].append((entity_type, endpoint))
            else:
                self.endpoints[domain_id] = [(entity_type, endpoint)]

            # check new topic
            if domain_id in self.endpoints.keys():
                already_endpoint_on_topic = False
                for (_, endpoint_iter) in self.endpoints[domain_id]:
                    if endpoint.topic_name == endpoint_iter.topic_name and endpoint.key != endpoint_iter.key:
                        already_endpoint_on_topic = True
                        break
        
                if not already_endpoint_on_topic:
                    logging.info(f"New topic {str(endpoint.topic_name)}")
                    self.new_topic_signal.emit(domain_id, endpoint.topic_name)

                self.new_endpoint_signal.emit(domain_id, endpoint, entity_type)

            # check qos
            self.check_qos_mismatches(domain_id)

    @Slot(int, DcpsEndpoint)
    def remove_endpoint(self, domain_id: int, endpoint: DcpsEndpoint):
        with self.mutex:
            if domain_id in self.endpoints.keys():
                available = -1
                other_endpoint_on_topic = False
                topic_name = ""
                idx = -1
                for (_, endpoint_iter) in self.endpoints[domain_id]:
                    idx += 1
                    if endpoint.key == endpoint_iter.key:
                        available = idx
                        topic_name = endpoint_iter.topic_name
                        break
                if available != -1:
                    logging.info(f"Remove endpoint {str(endpoint.key)}")
                    del self.endpoints[domain_id][idx]
                    self.removed_endpoint_signal.emit(domain_id, str(endpoint.key))

                # check if it was the last endpoint on its topic
                for (_, endpoint_iter) in self.endpoints[domain_id]:
                    if topic_name == endpoint_iter.topic_name:
                        other_endpoint_on_topic = True
                        break
                if not other_endpoint_on_topic:
                    logging.info(f"Remove topic {str(topic_name)}")
                    self.remove_topic_signal.emit(domain_id, topic_name)

            # check qos
            self.no_more_mismatch_in_topic_signal.emit(domain_id, topic_name)
            self.check_qos_mismatches(domain_id)     

    @Slot(int,result=[(EntityType, DcpsEndpoint)])
    def getEndpoints(self, domain_id: int):
        with self.mutex:
            if domain_id in self.endpoints.keys():
                return self.endpoints[domain_id]

    @Slot(int, result=DcpsParticipant)
    def getParticipants(self, domain_id: int):
        with self.mutex:
            if domain_id in self.participants.keys():
                return self.participants[domain_id]

    def getQosMismatches(self, domain_id: int, topic_name: str):
        with self.mutex:
            if domain_id in self.mismatches.keys() and domain_id in self.endpoints.keys():
                topic_mismatches = {}
                for (_, endpoint_iter) in self.endpoints[domain_id]:
                    if topic_name == endpoint_iter.topic_name and str(endpoint_iter.key) in self.mismatches[domain_id].keys():
                        topic_mismatches[str(endpoint_iter.key)] = self.mismatches[domain_id][str(endpoint_iter.key)]
                return topic_mismatches
        return {}
