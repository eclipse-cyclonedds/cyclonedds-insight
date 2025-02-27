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
from PySide6.QtCore import Signal, Slot, QThread
from cyclonedds import core
from cyclonedds.util import duration
from cyclonedds.core import SampleState, ViewState, InstanceState
from cyclonedds.topic import Topic
from cyclonedds.sub import Subscriber, DataReader
from cyclonedds.pub import Publisher, DataWriter
from dds_access.dds_listener import DdsListener
from threading import Lock
from dds_access.domain_participant_factory import DomainParticipantFactory
from dds_access.datatypes.entity_type import EntityType


class DispatcherThread(QThread):

    onData = Signal(str)

    def __init__(self, id: str, domain_id: int, topic_name: str, topic_type, qos, entityType, parent=None):
        super().__init__(parent)
        self.listener = DdsListener()
        self.domain_id = domain_id
        self.domain_participant = None
        self.running = False
        self.readerData = []
        self.writerData = {}
        self.mutex = Lock()

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

    @Slot()
    def deleteAllWriters(self):
        logging.info(f"Delete all writers")  
        self.writerData.clear()

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

    @Slot()
    def addEndpoint(self, id: str, topic_name: str, topic_type, qos, entity_type: EntityType):
        logging.info(f"Add endpoint {id} ...")
        try:
            topic = Topic(self.domain_participant, topic_name, topic_type, qos=qos, listener=self.listener)

            if entity_type == EntityType.READER:
                subscriber = Subscriber(self.domain_participant, qos=qos, listener=self.listener)
                reader = DataReader(subscriber, topic, qos=qos, listener=self.listener)
                readCondition = core.ReadCondition(reader, SampleState.Any | ViewState.Any | InstanceState.Any)
                self.guardCondition.set(True)
                self.waitset.attach(readCondition)
                self.guardCondition.set(False)
                self.readerData.append((id, topic, subscriber, reader, readCondition))

            elif entity_type == EntityType.WRITER:
                publisher = Publisher(self.domain_participant, qos=qos, listener=self.listener)
                writer = DataWriter(publisher, topic, qos=qos, listener=self.listener)
                self.writerData[id] = (publisher, writer, topic_name)

            logging.info("Add endpoint ... DONE")

        except Exception as e:
            logging.error(f"Error creating endpoint {topic_name}: {e}")

    def run(self):
        with DomainParticipantFactory.get_participant(self.domain_id) as domain_participant:
            logging.info(f"Worker thread for domain({str(self.domain_id)}) ...")    
            self.running = True
            self.domain_participant = domain_participant
            self.waitset = core.WaitSet(self.domain_participant)
            self.guardCondition = core.GuardCondition(self.domain_participant)
            self.waitset.attach(self.guardCondition)
            logging.info(f"Worker thread is set up domain({str(self.domain_id)})")

            self.addEndpoint(self.id, self.topic_name, self.topic_type, self.qos, self.entityType)

            while self.running:
                amount_triggered = 0
                try:
                    amount_triggered = self.waitset.wait(duration(infinite=True))
                except:
                    pass
                if amount_triggered == 0:
                    continue

                for (_, _, _, readItem, condItem) in self.readerData:
                    for sample in readItem.take(condition=condItem):
                        logging.trace(f"Received sample: {str(sample)}")
                        self.onData.emit(f"[{str(datetime.datetime.now().isoformat())}]  -  {str(sample)}")

            logging.info(f"Worker thread for domain({str(self.domain_id)}) ... DONE")

    def stop(self):
        logging.info(f"Request to stop worker thread for domain({str(self.domain_id)})")
        self.running = False
        self.guardCondition.set(True)
