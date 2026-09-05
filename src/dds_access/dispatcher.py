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

from loguru import logger as logging
import datetime
import time
from PySide6.QtCore import Signal, Slot, QThread
from cyclonedds import core
from cyclonedds.util import duration
from cyclonedds.core import SampleState, ViewState, InstanceState
from cyclonedds.topic import Topic
from cyclonedds.sub import Subscriber, DataReader
from cyclonedds.pub import Publisher, DataWriter
from cyclonedds.internal import InvalidSample
from dds_access.dds_listener import DdsListener
from threading import Lock, Event
from dds_access.domain_participant_factory import DomainParticipantFactory
from dds_access.datatypes.entity_type import EntityType


class DispatcherThread(QThread):

    onData = Signal(
        str, str, str, bool, str, str, str, str, str, int, str, str, str
    )
    endpointCreated = Signal(str)
    endpointCreationFailed = Signal(str, str)

    @staticmethod
    def _format_sample_timing(sample_info, received_timestamp_ns):
        source_timestamp_ns = sample_info.source_timestamp

        if source_timestamp_ns <= 0:
            return "-", "-"

        source_time = datetime.datetime.fromtimestamp(
            source_timestamp_ns / 1_000_000_000,
            tz=datetime.timezone.utc
        ).astimezone()
        readable_timestamp = source_time.isoformat(timespec="milliseconds")

        elapsed_ns = received_timestamp_ns - source_timestamp_ns
        if elapsed_ns >= 1_000_000_000:
            elapsed = f"{elapsed_ns / 1_000_000_000:.3f} s"
        elif elapsed_ns >= 1_000_000:
            elapsed = f"{elapsed_ns / 1_000_000:.3f} ms"
        elif elapsed_ns >= 1_000:
            elapsed = f"{elapsed_ns / 1_000:.3f} us"
        elif elapsed_ns >= 0:
            elapsed = f"{elapsed_ns} ns"
        else:
            elapsed = "unavailable (source clock is ahead)"

        return readable_timestamp, elapsed

    def __init__(self, id: str, domain_id: int, topic_name: str, topic_type, qos, entityType, parent=None):
        super().__init__(parent)
        self.listener = DdsListener()
        self.domain_id = domain_id
        self.domain_participant = None
        self.running = False
        self.readerData = []
        self.writerIdsByHandle = {}
        self.writerParticipantIdsByHandle = {}
        self.writerData = {}
        self.mutex = Lock()
        self.dpSetUpDone = Event()

        # initial endpoint
        self.entityType = entityType
        self.topic_name = topic_name
        self.topic_type = topic_type
        self.qos = qos
        self.id = id

    @Slot(str, object)
    def write(self, id, data):
        if id in self.writerData:
            logging.debug(f"Write {id} {data}")
            (_, writer, _) = self.writerData[id]
            writer.write(data)
            logging.debug("Write ... DONE")

    @Slot(str, object)
    def dispose(self, id, data):
        if id in self.writerData:
            logging.debug(f"Dispose {id} {data}")
            (_, writer, _) = self.writerData[id]
            writer.dispose(data)
            logging.debug("Dispose ... DONE")

    @Slot(str, object)
    def unregisterInstance(self, id, data):
        if id in self.writerData:
            logging.debug(f"Unregister {id} {data}")
            (_, writer, _) = self.writerData[id]
            writer.unregister_instance(data)
            logging.debug("Unregister ... DONE")

    @Slot()
    def deleteAllWriters(self):
        logging.info(f"Delete all writers")  
        self.writerData.clear()

    def deleteWriter(self, id: str):
        if id in self.writerData:
            logging.info(f"Delete writer {id}")
            del self.writerData[id]

    @Slot()
    def deleteAllReaders(self):
        logging.info(f"Delete all readers")
        self.guardCondition.set(True)
        for id, tp, sub, rd, readCondition in self.readerData:
            logging.info(f"Delete reader {id} ({tp.name})")
            self.waitset.detach(readCondition)
            del rd
            del sub
            del tp
        self.readerData.clear()
        self.guardCondition.set(False)

    @Slot(str)
    def deleteReader(self, _id: str):
        for i, (readerId, tp, sub, rd, readCondition) in enumerate(self.readerData):
            if readerId == _id:
                logging.info(f"Delete reader {_id} ({tp.name})")
                self.guardCondition.set(True)
                self.waitset.detach(readCondition)
                del rd
                del sub
                del tp
                del self.readerData[i]
                self.guardCondition.set(False)
                break

    @Slot()
    def addEndpoint(self, id: str, topic_name: str, topic_type, qos, entity_type: EntityType):
        logging.info(f"Add endpoint {id} {topic_name} ...")
        _, topicQos, pubSubQos, endpQos = qos
        try:
            topic = Topic(self.domain_participant, topic_name, topic_type, listener=self.listener, qos=topicQos)

            if entity_type == EntityType.READER:
                subscriber = Subscriber(self.domain_participant, qos=pubSubQos, listener=self.listener)
                reader = DataReader(subscriber, topic, qos=endpQos, listener=self.listener)
                readCondition = core.ReadCondition(reader, SampleState.Any | ViewState.Any | InstanceState.Any)
                self.guardCondition.set(True)
                self.waitset.attach(readCondition)
                self.guardCondition.set(False)
                self.readerData.append((id, topic, subscriber, reader, readCondition))

            elif entity_type == EntityType.WRITER:
                publisher = Publisher(self.domain_participant, qos=pubSubQos, listener=self.listener)
                writer = DataWriter(publisher, topic, qos=endpQos, listener=self.listener)
                self.writerData[id] = (publisher, writer, topic_name)

            logging.info(f"Add endpoint {topic_name} ... Success")
            self.endpointCreated.emit(id)

        except Exception as e:
            message = f"Failed to create endpoint '{topic_name}': {e}"
            logging.error(message)
            self.endpointCreationFailed.emit(id, message)

    def run(self):
        self.dpSetUpDone.clear()
        try:
            with DomainParticipantFactory.get_participant(self.domain_id) as domain_participant:
                logging.info(f"Worker thread for domain({str(self.domain_id)}) ...")
                self.running = True
                self.domain_participant = domain_participant
                self.waitset = core.WaitSet(self.domain_participant)
                self.guardCondition = core.GuardCondition(self.domain_participant)
                self.waitset.attach(self.guardCondition)
                logging.info(f"Worker thread is set up domain({str(self.domain_id)})")

                self.addEndpoint(self.id, self.topic_name, self.topic_type, self.qos, self.entityType)

                self.dpSetUpDone.set()

                while self.running:
                    amount_triggered = 0
                    try:
                        amount_triggered = self.waitset.wait(duration(infinite=True))
                    except Exception as error:
                        logging.error(f"DDS wait failed in domain {self.domain_id}: {error}")
                    if amount_triggered == 0:
                        continue

                    for (_id, topic, _, readItem, condItem) in self.readerData:
                        samples = readItem.take(condition=condItem)
                        if not samples:
                            continue

                        received_timestamp_ns = time.time_ns()
                        received_time = datetime.datetime.fromtimestamp(
                            received_timestamp_ns / 1_000_000_000,
                            tz=datetime.timezone.utc
                        ).astimezone()

                        for sample in samples:
                            logging.trace(f"Received sample: {str(sample)}")
                            sample_data = (
                                f"{str(sample.key_sample)}"
                                if isinstance(sample, InvalidSample)
                                else str(sample)
                            )
                            source_timestamp, transmission_time = self._format_sample_timing(
                                sample.sample_info,
                                received_timestamp_ns
                            )
                            publication_handle = sample.sample_info.publication_handle
                            writer_id = self.writerIdsByHandle.get(publication_handle, "-")
                            writer_participant_id = self.writerParticipantIdsByHandle.get(
                                publication_handle, ""
                            )
                            try:
                                publication = readItem.get_matched_publication_data(publication_handle)
                                if publication is not None:
                                    writer_id = str(publication.key)
                                    writer_participant_id = str(publication.participant_key)
                                    self.writerIdsByHandle[publication_handle] = writer_id
                                    self.writerParticipantIdsByHandle[publication_handle] = \
                                        writer_participant_id
                            except Exception:
                                pass
                            received_timestamp = received_time.isoformat(timespec="milliseconds")
                            self.onData.emit(
                                _id,
                                sample_data,
                                str(sample.sample_info),
                                sample.sample_info.valid_data,
                                source_timestamp,
                                transmission_time,
                                received_timestamp,
                                writer_id,
                                str(readItem.guid),
                                self.domain_id,
                                writer_participant_id,
                                str(topic.typename),
                                str(topic.name)
                            )

                    _id = None
                    readItem = None
                    condItem = None

                logging.info(f"Worker thread for domain({str(self.domain_id)}) ... DONE")
        except Exception as error:
            message = f"Failed to initialize DDS domain {self.domain_id}: {error}"
            logging.error(message)
            self.endpointCreationFailed.emit(self.id, message)
        finally:
            self.dpSetUpDone.set()
    def stop(self):
        logging.info(f"Request to stop worker thread for domain({str(self.domain_id)})")
        self.running = False
        self.guardCondition.set(True)

    def isSetUpDone(self) -> bool:
        return self.dpSetUpDone.is_set()
