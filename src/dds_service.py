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
from enum import Enum
from queue import Queue
from PySide6.QtCore import QObject, Signal, Slot, QThread
from dataclasses import dataclass
from cyclonedds import core, domain, builtin
from cyclonedds.util import duration
from cyclonedds.builtin import DcpsEndpoint, DcpsParticipant
from cyclonedds.core import SampleState, ViewState, InstanceState
from cyclonedds.topic import Topic
from cyclonedds.sub import Subscriber, DataReader

from utils import EntityType

IGNORE_TOPICS = ["DCPSParticipant", "DCPSPublication", "DCPSSubscription"]


class BuiltInDataItem():

    def __init__(self):
        self.new_participants = []
        self.new_endpoints = []
        self.remove_participants = []
        self.remove_endpoints = []


def builtin_observer(domain_id: int, queue: Queue, running):
    logging.info(f"builtin_observer({domain_id}) ...")

    domain_participant = domain.DomainParticipant(domain_id)
    waitset = core.WaitSet(domain_participant)

    rdp = builtin.BuiltinDataReader(domain_participant, builtin.BuiltinTopicDcpsParticipant)
    rcp = core.ReadCondition(
        rdp, core.SampleState.Any | core.ViewState.Any | core.InstanceState.Any)
    waitset.attach(rcp)

    rdw = builtin.BuiltinDataReader(domain_participant, builtin.BuiltinTopicDcpsPublication)
    rcw = core.ReadCondition(
        rdw, core.SampleState.Any | core.ViewState.Any | core.InstanceState.Any)
    waitset.attach(rcw)

    rdr = builtin.BuiltinDataReader(domain_participant, builtin.BuiltinTopicDcpsSubscription)
    rcr = core.ReadCondition(
        rdr, core.SampleState.Any | core.ViewState.Any | core.InstanceState.Any)
    waitset.attach(rcr)

    while running[0]:

        amount_triggered = 0
        try:
            amount_triggered = waitset.wait(duration(milliseconds=100))
        except Exception as e:
            logging.error(str(e))
        if amount_triggered == 0:
            continue

        dataItem = BuiltInDataItem()

        for p in rdp.take(condition=rcp):
            if p.sample_info.sample_state == core.SampleState.NotRead and p.sample_info.instance_state == core.InstanceState.Alive:
                dataItem.new_participants.append((domain_id, p))
            elif p.sample_info.instance_state == core.InstanceState.NotAliveDisposed:
                dataItem.remove_participants.append((domain_id, p))

        for pub in rdw.take(condition=rcw):
            if pub.sample_info.sample_state == core.SampleState.NotRead and pub.sample_info.instance_state == core.InstanceState.Alive:
                if pub.topic_name not in IGNORE_TOPICS:
                    dataItem.new_endpoints.append((domain_id, pub, EntityType.WRITER))
            elif pub.sample_info.instance_state == core.InstanceState.NotAliveDisposed:
                dataItem.remove_endpoints.append((domain_id, pub))

        for sub in rdr.take(condition=rcr):
            if sub.sample_info.sample_state == core.SampleState.NotRead and sub.sample_info.instance_state == core.InstanceState.Alive:
                if sub.topic_name not in IGNORE_TOPICS:
                    dataItem.new_endpoints.append((domain_id, sub, EntityType.READER))
            elif sub.sample_info.instance_state == core.InstanceState.NotAliveDisposed:
                dataItem.remove_endpoints.append((domain_id, sub))

        queue.put(dataItem)

    logging.info(f"builtin_observer({domain_id}) ... DONE")


class WorkerThread(QThread):

    data_emitted = Signal(str)
    
    def __init__(self, domain_id, topic_name, topic_type, qos, parent=None):
        super().__init__(parent)
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
            subscriber = Subscriber(self.domain_participant)
            reader = DataReader(subscriber, topic)
            readCondition = core.ReadCondition(reader, SampleState.Any | ViewState.Any | InstanceState.Any)
            self.waitset.attach(readCondition)

            self.readerData.append((topic,subscriber, reader, readCondition))
        except Exception as e:
            logging.error(f"Error creating reader {topic_name}: {e}")

    def run(self):
        logging.info(f"Worker thread for domain({str(self.domain_id)}) ...")    

        self.domain_participant = domain.DomainParticipant(self.domain_id)
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
