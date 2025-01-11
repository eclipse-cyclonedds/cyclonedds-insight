
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
from queue import Queue
from cyclonedds import core, builtin
from cyclonedds.util import duration
from dds_access.domain_participant_factory import DomainParticipantFactory
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

    with DomainParticipantFactory.get_participant(domain_id) as domain_participant:

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
