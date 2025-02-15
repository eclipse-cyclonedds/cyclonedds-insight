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

import sys
import logging
from queue import Queue
from cyclonedds import core, builtin
from cyclonedds.util import duration
from cyclonedds.builtin import DcpsEndpoint, DcpsParticipant
from cyclonedds.core import Qos, Policy
from cyclonedds.topic import Topic
from cyclonedds.sub import Subscriber, DataReader
from dds_access.datatypes.ospl import kernelModule
from dds_access.datatypes.ospl.utils import from_ospl
from typing import Optional, List, Tuple
from dds_access.domain_participant_factory import DomainParticipantFactory
from utils import EntityType


IGNORE_TOPICS = [
                # DDS-Spec
                "DCPSParticipant", "DCPSPublication", "DCPSSubscription",
                # OSPL-BuiltIn-Topics
                "CMParticipant", "CMDataReader", "CMDataWriter", "CMSubscriber", "CMPublisher",
                "DCPSTopic", "DCPSType", "DCPSHeartbeat", "DCPSCandMCommand", "DCPSDelivery"]


class BuiltInDataItem():

    def __init__(self):
        # Participants
        self.new_participants: Tuple[int, DcpsParticipant] = []
        self.remove_participants: Tuple[int, DcpsParticipant] = []
        self.update_participants: Tuple[int, DcpsParticipant] = []

        # Endpoints
        self.new_endpoints: Tuple[int, DcpsEndpoint, EntityType] = []
        self.remove_endpoints: Tuple[int, DcpsEndpoint] = []


def builtin_observer(domain_id: int, queue: Queue, running):
    logging.info(f"builtin_observer({domain_id}) ...")

    domain_participant = DomainParticipantFactory.get_participant(domain_id)
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

    # OpenSplice-BuiltIn
    sys.modules["kernelModule"] = kernelModule
    ospl_qos = Qos(
        Policy.Ownership.Shared,
        Policy.Durability.TransientLocal,
        Policy.Reliability.Reliable(max_blocking_time=duration(milliseconds=0)),
        Policy.History.KeepAll,
        Policy.Partition(partitions=["__BUILT-IN PARTITION__"]),
        Policy.EntityName(name="CMParticipantReader"),
        Policy.DataRepresentation(use_cdrv0_representation=True, use_xcdrv2_representation=False))
    ospl_topic = Topic(domain_participant, "CMParticipant", kernelModule.v_participantCMInfo, qos=ospl_qos)
    ospl_subscriber = Subscriber(domain_participant, qos=ospl_qos)
    ospl_reader = DataReader(ospl_subscriber, ospl_topic, qos=ospl_qos)
    ospl_read_condition = core.ReadCondition(ospl_reader, core.SampleState.NotRead | core.ViewState.Any | core.InstanceState.Alive)
    waitset.attach(ospl_read_condition)

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
                print(p)
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

        for ospl_participant in ospl_reader.take(condition=ospl_read_condition):
            p_update = from_ospl(ospl_participant)
            print("ospl: ", p_update)
            if p_update:
                dataItem.update_participants.append((domain_id, p_update))

        queue.put(dataItem)

    logging.info(f"builtin_observer({domain_id}) ... DONE")
