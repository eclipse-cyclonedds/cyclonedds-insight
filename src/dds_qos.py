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

from enum import Enum
from cyclonedds import qos
# from cyclonedds.internal import feature_typelib # not available in v0.10.5
from utils import OrderedEnum


def qos_match(endpoint_reader, endpoint_writer) -> list:

    mismatches = []

    if endpoint_reader.topic_name != endpoint_writer.topic_name:
        mismatches.append(dds_qos_policy_id.DDS_INVALID_QOS_POLICY_ID)

    reliability_rd = to_kind_reliability(endpoint_reader.qos)
    reliability_wr = to_kind_reliability(endpoint_writer.qos)
    if reliability_rd and reliability_wr and reliability_rd > reliability_wr:
        mismatches.append(dds_qos_policy_id.DDS_RELIABILITY_QOS_POLICY_ID)

    durability_rd = to_kind_durability(endpoint_reader.qos)
    durability_wr = to_kind_durability(endpoint_writer.qos)
    if durability_rd and durability_wr and durability_rd > durability_wr:
        mismatches.append(dds_qos_policy_id.DDS_DURABILITY_QOS_POLICY_ID)

    access_scope_rd = to_kind_access_scope(endpoint_reader.qos)
    access_scope_wr = to_kind_access_scope(endpoint_writer.qos)
    if access_scope_rd and access_scope_wr and access_scope_rd > access_scope_wr:
        mismatches.append(dds_qos_policy_id.DDS_PRESENTATION_QOS_POLICY_ID)

    coherent_access_rd = to_kind_coherent_access(endpoint_reader.qos)
    coherent_access_wr = to_kind_coherent_access(endpoint_writer.qos)
    if coherent_access_rd and coherent_access_wr and coherent_access_rd > coherent_access_wr:
        mismatches.append(dds_qos_policy_id.DDS_PRESENTATION_QOS_POLICY_ID)
    
    ordered_access_rd = to_kind_ordered_access(endpoint_reader.qos)
    ordered_access_wr = to_kind_ordered_access(endpoint_writer.qos)
    if ordered_access_rd and ordered_access_wr and ordered_access_rd > ordered_access_wr:
        mismatches.append(dds_qos_policy_id.DDS_PRESENTATION_QOS_POLICY_ID)

    deadline_rd = to_kind_deadline(endpoint_reader.qos)
    deadline_wr = to_kind_deadline(endpoint_writer.qos)
    if deadline_rd and deadline_wr and deadline_rd < deadline_wr:
        mismatches.append(dds_qos_policy_id.DDS_DEADLINE_QOS_POLICY_ID)

    lat_duration_rd = to_kind_lat_duration(endpoint_reader.qos)
    lat_duration_wr = to_kind_lat_duration(endpoint_writer.qos)
    if lat_duration_rd and lat_duration_wr and lat_duration_rd < lat_duration_wr:
        mismatches.append(dds_qos_policy_id.DDS_LATENCYBUDGET_QOS_POLICY_ID)

    ownership_rd = to_kind_ownership(endpoint_reader.qos)
    ownership_wr = to_kind_ownership(endpoint_writer.qos)
    if ownership_rd and ownership_wr and ownership_rd != ownership_wr:
        mismatches.append(dds_qos_policy_id.DDS_OWNERSHIP_QOS_POLICY_ID)

    liveliness_rd = to_kind_liveliness(endpoint_reader.qos)
    liveliness_wr = to_kind_liveliness(endpoint_writer.qos)
    if liveliness_rd and liveliness_wr and liveliness_rd > liveliness_wr:
        mismatches.append(dds_qos_policy_id.DDS_LIVELINESS_QOS_POLICY_ID)

    live_duration_rd = to_kind_live_duration(endpoint_reader.qos)
    live_duration_wr = to_kind_live_duration(endpoint_writer.qos)
    if live_duration_rd and live_duration_wr and live_duration_rd < live_duration_wr:
        mismatches.append(dds_qos_policy_id.DDS_LIVELINESS_QOS_POLICY_ID)

    destination_order_rd = to_kind_destination_order(endpoint_reader.qos)
    destination_order_wr = to_kind_destination_order(endpoint_writer.qos)
    if destination_order_rd and destination_order_wr and destination_order_rd > destination_order_wr:
        mismatches.append(dds_qos_policy_id.DDS_DESTINATIONORDER_QOS_POLICY_ID)

    if not partitions_match_p(endpoint_reader.qos, endpoint_writer.qos):
        mismatches.append(dds_qos_policy_id.DDS_PARTITION_QOS_POLICY_ID)

    if qos.Policy.DataRepresentation in endpoint_reader.qos and qos.Policy.DataRepresentation in endpoint_writer.qos:
        if endpoint_writer.qos[qos.Policy.DataRepresentation].use_cdrv0_representation and endpoint_reader.qos[qos.Policy.DataRepresentation].use_cdrv0_representation:
            pass # ok - both using cdrv0
        elif endpoint_writer.qos[qos.Policy.DataRepresentation].use_xcdrv2_representation and endpoint_reader.qos[qos.Policy.DataRepresentation].use_xcdrv2_representation:
            pass # ok - both using xcdrv2
        else:
            mismatches.append(dds_qos_policy_id.DDS_DATA_REPRESENTATION_QOS_POLICY_ID)

    if False: # feature_typelib:
        pass # TODO: finish implementation of xtypes qos check
    else:
        if endpoint_reader.type_name != endpoint_writer.type_name:
            mismatches.append(dds_qos_policy_id.DDS_INVALID_QOS_POLICY_ID)

    return mismatches

class dds_durability_kind(OrderedEnum):
    DDS_DURABILITY_VOLATILE = 0
    DDS_DURABILITY_TRANSIENT_LOCAL = 1
    DDS_DURABILITY_TRANSIENT = 2
    DDS_DURABILITY_PERSISTENT = 3

class dds_history(OrderedEnum):
    DDS_HISTORY_KEEP_LAST = 0
    DDS_HISTORY_KEEP_ALL = 1

class dds_ownership(OrderedEnum):
    DDS_OWNERSHIP_SHARED = 0
    DDS_OWNERSHIP_EXCLUSIVE = 1

class dds_liveliness(OrderedEnum):
    DDS_LIVELINESS_AUTOMATIC = 0
    DDS_LIVELINESS_MANUAL_BY_PARTICIPANT = 1
    DDS_LIVELINESS_MANUAL_BY_TOPIC = 2

class dds_reliability(OrderedEnum):
    DDS_RELIABILITY_BEST_EFFORT = 0
    DDS_RELIABILITY_RELIABLE = 1

class dds_destination_order(OrderedEnum):
    DDS_DESTINATIONORDER_BY_RECEPTION_TIMESTAMP = 0
    DDS_DESTINATIONORDER_BY_SOURCE_TIMESTAMP = 1

class dds_presentation_access_scope(OrderedEnum):
    DDS_PRESENTATION_INSTANCE = 0
    DDS_PRESENTATION_TOPIC = 1
    DDS_PRESENTATION_GROUP = 2

class dds_ignorelocal(OrderedEnum):
    DDS_IGNORELOCAL_NONE = 0
    DDS_IGNORELOCAL_PARTICIPANT = 1
    DDS_IGNORELOCAL_PROCESS = 2

class dds_type_consistency(OrderedEnum):
    DDS_TYPE_CONSISTENCY_DISALLOW_TYPE_COERCION = 0
    DDS_TYPE_CONSISTENCY_ALLOW_TYPE_COERCION = 1

class dds_qos_policy_id(Enum):
    DDS_INVALID_QOS_POLICY_ID = 0
    DDS_USERDATA_QOS_POLICY_ID = 1
    DDS_DURABILITY_QOS_POLICY_ID = 2
    DDS_PRESENTATION_QOS_POLICY_ID = 3
    DDS_DEADLINE_QOS_POLICY_ID = 4
    DDS_LATENCYBUDGET_QOS_POLICY_ID = 5
    DDS_OWNERSHIP_QOS_POLICY_ID = 6
    DDS_OWNERSHIPSTRENGTH_QOS_POLICY_ID = 7
    DDS_LIVELINESS_QOS_POLICY_ID = 8
    DDS_TIMEBASEDFILTER_QOS_POLICY_ID = 9
    DDS_PARTITION_QOS_POLICY_ID = 10
    DDS_RELIABILITY_QOS_POLICY_ID = 11
    DDS_DESTINATIONORDER_QOS_POLICY_ID = 12
    DDS_HISTORY_QOS_POLICY_ID = 13
    DDS_RESOURCELIMITS_QOS_POLICY_ID = 14
    DDS_ENTITYFACTORY_QOS_POLICY_ID = 15
    DDS_WRITERDATALIFECYCLE_QOS_POLICY_ID = 16
    DDS_READERDATALIFECYCLE_QOS_POLICY_ID = 17
    DDS_TOPICDATA_QOS_POLICY_ID = 18
    DDS_GROUPDATA_QOS_POLICY_ID = 19
    DDS_TRANSPORTPRIORITY_QOS_POLICY_ID = 20
    DDS_LIFESPAN_QOS_POLICY_ID = 21
    DDS_DURABILITYSERVICE_QOS_POLICY_ID = 22
    DDS_PROPERTY_QOS_POLICY_ID = 23
    DDS_TYPE_CONSISTENCY_ENFORCEMENT_QOS_POLICY_ID = 24
    DDS_DATA_REPRESENTATION_QOS_POLICY_ID = 25


def to_kind_reliability(q: qos.Qos):
    if qos.Policy.Reliability in q:
        if qos.Policy.Reliability.Reliable in q:
            return dds_reliability.DDS_RELIABILITY_RELIABLE
        elif qos.Policy.Reliability.BestEffort in q:
            return dds_reliability.DDS_RELIABILITY_BEST_EFFORT
    return None

def to_kind_durability(q: qos.Qos):
    if qos.Policy.Durability in q:
        if qos.Policy.Durability.Volatile in q:
            return dds_durability_kind.DDS_DURABILITY_VOLATILE
        if qos.Policy.Durability.TransientLocal in q:
            return dds_durability_kind.DDS_DURABILITY_TRANSIENT_LOCAL
        if qos.Policy.Durability.Transient in q:
            return dds_durability_kind.DDS_DURABILITY_TRANSIENT
        if qos.Policy.Durability.Persistent in q:
            return dds_durability_kind.DDS_DURABILITY_PERSISTENT
    return None

def to_kind_access_scope(q: qos.Qos):
    if qos.Policy.PresentationAccessScope in q:
        if qos.Policy.PresentationAccessScope.Instance in q:
            return dds_presentation_access_scope.DDS_PRESENTATION_INSTANCE
        if qos.Policy.PresentationAccessScope.Topic in q:
            return dds_presentation_access_scope.DDS_PRESENTATION_GROUP
        if qos.Policy.PresentationAccessScope.Group in q:
            return dds_presentation_access_scope.DDS_PRESENTATION_TOPIC
    return None

def to_kind_coherent_access(q: qos.Qos):
    if qos.Policy.PresentationAccessScope in q:
        if qos.Policy.PresentationAccessScope.Instance in q:
            return 1 if q[qos.Policy.PresentationAccessScope.Instance].coherent_access else 0
        if qos.Policy.PresentationAccessScope.Topic in q:
            return 1 if q[qos.Policy.PresentationAccessScope.Topic].coherent_access else 0
        if qos.Policy.PresentationAccessScope.Group in q:
            return 1 if q[qos.Policy.PresentationAccessScope.Group].coherent_access else 0
    return None

def to_kind_ordered_access(q: qos.Qos):
    if qos.Policy.PresentationAccessScope in q:
        if qos.Policy.PresentationAccessScope.Instance in q:
            return 1 if q[qos.Policy.PresentationAccessScope.Instance].ordered_access else 0
        if qos.Policy.PresentationAccessScope.Topic in q:
            return 1 if q[qos.Policy.PresentationAccessScope.Topic].ordered_access else 0
        if qos.Policy.PresentationAccessScope.Group in q:
            return 1 if q[qos.Policy.PresentationAccessScope.Group].ordered_access else 0
    return None

def to_kind_deadline(q: qos.Qos):
    if qos.Policy.Deadline in q:
       return q[qos.Policy.Deadline].deadline
    return None

def to_kind_lat_duration(q: qos.Qos):
    if qos.Policy.LatencyBudget in q:
       return q[qos.Policy.LatencyBudget].budget
    return None

def to_kind_ownership(q: qos.Qos):
    if qos.Policy.Ownership in q:
        if qos.Policy.Ownership.Shared in q:
            return dds_ownership.DDS_OWNERSHIP_SHARED
        if qos.Policy.Ownership.Exclusive in q:
            return dds_ownership.DDS_OWNERSHIP_EXCLUSIVE
    return None

def to_kind_liveliness(q: qos.Qos):
    if qos.Policy.Liveliness in q:
        if qos.Policy.Liveliness.Automatic in q:
            return dds_liveliness.DDS_LIVELINESS_AUTOMATIC
        if qos.Policy.Liveliness.ManualByParticipant in q:
            return dds_liveliness.DDS_LIVELINESS_MANUAL_BY_PARTICIPANT
        if qos.Policy.Liveliness.ManualByTopic in q:
            return dds_liveliness.DDS_LIVELINESS_MANUAL_BY_TOPIC
    return None

def to_kind_live_duration(q: qos.Qos):
    if qos.Policy.Liveliness in q:
        if qos.Policy.Liveliness.Automatic in q:
            return q[qos.Policy.Liveliness.Automatic].lease_duration
        if qos.Policy.Liveliness.ManualByParticipant in q:
            return q[qos.Policy.Liveliness.ManualByParticipant].lease_duration
        if qos.Policy.Liveliness.ManualByTopic in q:
            return q[qos.Policy.Liveliness.ManualByTopic].lease_duration
    return None

def to_kind_destination_order(q: qos.Qos):
    if qos.Policy.DestinationOrder in q:
        if qos.Policy.DestinationOrder.ByReceptionTimestamp in q:
            return dds_destination_order.DDS_DESTINATIONORDER_BY_RECEPTION_TIMESTAMP
        if qos.Policy.DestinationOrder.BySourceTimestamp in q:
            return dds_destination_order.DDS_DESTINATIONORDER_BY_SOURCE_TIMESTAMP
    return None

def ddsi_patmatch(pat, s):
    pat_idx = 0
    s_idx = 0

    while pat_idx < len(pat):
        if pat[pat_idx] == '?':
            # any character will do
            if s_idx >= len(s):
                return False
            pat_idx += 1
            s_idx += 1
        elif pat[pat_idx] == '*':
            # collapse a sequence of wildcards
            while pat_idx < len(pat) and (pat[pat_idx] == '*' or pat[pat_idx] == '?'):
                if pat[pat_idx] == '?' and s_idx >= len(s):
                    return False
                pat_idx += 1
                s_idx += 1
            # try matching on all positions where s matches pat
            while s_idx < len(s):
                if (pat_idx < len(pat) and s[s_idx] == pat[pat_idx] and
                        ddsi_patmatch(pat[pat_idx + 1:], s[s_idx + 1:])):
                    return True
                s_idx += 1
            return pat_idx == len(pat)
        else:
            # only an exact match
            if s_idx >= len(s) or s[s_idx] != pat[pat_idx]:
                return False
            pat_idx += 1
            s_idx += 1

    return s_idx == len(s)

def is_wildcard_partition(s):
    return '*' in s or '?' in s

def partition_patmatch_p(pat, name):
    if not is_wildcard_partition(pat):
        return pat == name
    elif is_wildcard_partition(name):
        return False
    else:
        return ddsi_patmatch(pat, name)

def partitions_match_default(x):
    if qos.Policy.Partition not in x or len(x[qos.Policy.Partition].partitions) == 0:
        return True
    for i in range(len(x.partition)):
        if partition_patmatch_p(x[qos.Policy.Partition].partitions[i], ""):
            return True
    return False

def partitions_match_p(a, b):
    if (qos.Policy.Partition not in a) or len(a[qos.Policy.Partition].partitions) == 0:
        return partitions_match_default(b)
    elif (qos.Policy.Partition not in b) or len(b[qos.Policy.Partition].partitions) == 0:
        return partitions_match_default(a)
    else:
        for i in range(len(a[qos.Policy.Partition].partitions)):
            for j in range(len(b[qos.Policy.Partition].partitions)):
                if (partition_patmatch_p(a[qos.Policy.Partition].partitions[i], b[qos.Policy.Partition].partitions[j]) or 
                        partition_patmatch_p(b[qos.Policy.Partition].partitions[j], a[qos.Policy.Partition].partitions[i])):
                    return True
        return False

