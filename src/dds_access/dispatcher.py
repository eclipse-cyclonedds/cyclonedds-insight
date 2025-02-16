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

import logging
import datetime
from PySide6.QtCore import Signal, Slot, QThread
from cyclonedds import core, dynamic
from cyclonedds.util import duration
from cyclonedds.core import SampleState, ViewState, InstanceState
from cyclonedds.topic import Topic
from cyclonedds.sub import Subscriber, DataReader
from dds_access.domain_participant_factory import DomainParticipantFactory
from dds_access.dds_listener import DdsListener


def getDataType(domainId, endp):
    try:
        requestedDataType, _ = dynamic.get_types_for_typeid(
            DomainParticipantFactory.get_participant(domainId), endp.type_id, duration(seconds=3))
        return requestedDataType
    except Exception as e:
        logging.error(str(e))

    return None


class WorkerThread(QThread):

    data_emitted = Signal(str)
    
    def __init__(self, domain_id, topic_name, topic_type, qos, parent=None):
        super().__init__(parent)
        self.listener = DdsListener()
        self.domain_id = domain_id
        self.topic_name = topic_name
        self.topic_type = topic_type
        self.qos = qos
        self.running = True
        self.readerData = []

    @Slot()
    def receive_data(self, topic_name, topic_type, qos):
        logging.info("Add reader")
        try:
            topic = Topic(self.domain_participant, topic_name, topic_type, qos=qos)
            subscriber = Subscriber(self.domain_participant, qos=qos)
            reader = DataReader(subscriber, topic, qos=qos, listener=self.listener)
            readCondition = core.ReadCondition(reader, SampleState.Any | ViewState.Any | InstanceState.Any)
            self.waitset.attach(readCondition)

            self.readerData.append((topic,subscriber, reader, readCondition))
        except Exception as e:
            logging.error(f"Error creating reader {topic_name}: {e}")

    def run(self):
        logging.info(f"Worker thread for domain({str(self.domain_id)}) ...")    

        self.domain_participant = DomainParticipantFactory.get_participant(self.domain_id)
        self.waitset = core.WaitSet(self.domain_participant)
        self.receive_data(self.topic_name, self.topic_type, self.qos)

        while self.running:
            amount_triggered = 0
            try:
                amount_triggered = self.waitset.wait(duration(milliseconds=100))
            except:
                pass
            if amount_triggered == 0:
                continue

            for (_, _, readItem, condItem) in self.readerData:
                for sample in readItem.take(condition=condItem):
                    self.data_emitted.emit(f"[{str(datetime.datetime.now().isoformat())}]  -  {str(sample)}")

        logging.info(f"Worker thread for domain({str(self.domain_id)}) ... DONE")

    def stop(self):
        logging.info(f"Request to stop worker thread for domain({str(self.domain_id)})")
        self.running = False
