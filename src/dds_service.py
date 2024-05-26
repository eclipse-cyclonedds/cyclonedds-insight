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
from enum import Enum
from cyclonedds import core, domain, builtin, qos
from cyclonedds.internal import feature_typelib
from cyclonedds.util import duration
from utils import EntityType, OrderedEnum

IGNORE_TOPICS = ["DCPSParticipant", "DCPSPublication", "DCPSSubscription"]


def builtin_observer(domain_id, dds_data, running):
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

    logging.info("")

    while running[0]:

        amount_triggered = 0
        try:
            amount_triggered = waitset.wait(duration(milliseconds=100))
        except:
            pass
        if amount_triggered == 0:
            continue

        for p in rdp.take(condition=rcp):
            if p.sample_info.sample_state == core.SampleState.NotRead and p.sample_info.instance_state == core.InstanceState.Alive:
                dds_data.add_domain_participant(domain_id, p)
            elif p.sample_info.instance_state == core.InstanceState.NotAliveDisposed:
                dds_data.remove_domain_participant(domain_id, p)

        for pub in rdw.take(condition=rcw):
            if pub.sample_info.sample_state == core.SampleState.NotRead and pub.sample_info.instance_state == core.InstanceState.Alive:
                if pub.topic_name not in IGNORE_TOPICS:
                    dds_data.add_endpoint(domain_id, pub, EntityType.WRITER)
            elif pub.sample_info.instance_state == core.InstanceState.NotAliveDisposed:
                dds_data.remove_endpoint(domain_id, pub)

        for sub in rdr.take(condition=rcr):
            if sub.sample_info.sample_state == core.SampleState.NotRead and sub.sample_info.instance_state == core.InstanceState.Alive:
                if sub.topic_name not in IGNORE_TOPICS:
                    dds_data.add_endpoint(domain_id, sub, EntityType.READER)
            elif sub.sample_info.instance_state == core.InstanceState.NotAliveDisposed:
                dds_data.remove_endpoint(domain_id, sub)

    logging.info(f"builtin_observer({domain_id}) ... DONE")


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

def qos_match(endpoint_reader, endpoint_writer):

    if endpoint_reader.topic_name != endpoint_writer.topic_name:
        return False, dds_qos_policy_id.DDS_INVALID_QOS_POLICY_ID

    reliability_rd = to_kind_reliability(endpoint_reader.qos)
    reliability_wr = to_kind_reliability(endpoint_writer.qos)
    if reliability_rd and reliability_wr and reliability_rd > reliability_wr:
        return False, dds_qos_policy_id.DDS_RELIABILITY_QOS_POLICY_ID

    durability_rd = to_kind_durability(endpoint_reader.qos)
    durability_wr = to_kind_durability(endpoint_writer.qos)
    if durability_rd and durability_wr and durability_rd > durability_wr:
        return False, dds_qos_policy_id.DDS_DURABILITY_QOS_POLICY_ID

    access_scope_rd = to_kind_access_scope(endpoint_reader.qos)
    access_scope_wr = to_kind_access_scope(endpoint_writer.qos)
    if access_scope_rd and access_scope_wr and access_scope_rd > access_scope_wr:
        return False, dds_qos_policy_id.DDS_PRESENTATION_QOS_POLICY_ID

    coherent_access_rd = to_kind_coherent_access(endpoint_reader.qos)
    coherent_access_wr = to_kind_coherent_access(endpoint_writer.qos)
    if coherent_access_rd and coherent_access_wr and coherent_access_rd > coherent_access_wr:
        return False, dds_qos_policy_id.DDS_PRESENTATION_QOS_POLICY_ID
    
    ordered_access_rd = to_kind_ordered_access(endpoint_reader.qos)
    ordered_access_wr = to_kind_ordered_access(endpoint_writer.qos)
    if ordered_access_rd and ordered_access_wr and ordered_access_rd > ordered_access_wr:
        return False, dds_qos_policy_id.DDS_PRESENTATION_QOS_POLICY_ID

    deadline_rd = to_kind_deadline(endpoint_reader.qos)
    deadline_wr = to_kind_deadline(endpoint_writer.qos)
    if deadline_rd and deadline_wr and deadline_rd < deadline_wr:
        return False, dds_qos_policy_id.DDS_DEADLINE_QOS_POLICY_ID

    lat_duration_rd = to_kind_lat_duration(endpoint_reader.qos)
    lat_duration_wr = to_kind_lat_duration(endpoint_writer.qos)
    if lat_duration_rd and lat_duration_wr and lat_duration_rd < lat_duration_wr:
        return False, dds_qos_policy_id.DDS_LATENCYBUDGET_QOS_POLICY_ID

    ownership_rd = to_kind_ownership(endpoint_reader.qos)
    ownership_wr = to_kind_ownership(endpoint_writer.qos)
    if ownership_rd and ownership_wr and ownership_rd != ownership_wr:
        return False, dds_qos_policy_id.DDS_OWNERSHIP_QOS_POLICY_ID

    liveliness_rd = to_kind_liveliness(endpoint_reader.qos)
    liveliness_wr = to_kind_liveliness(endpoint_writer.qos)
    if liveliness_rd and liveliness_wr and liveliness_rd > liveliness_wr:
        return False, dds_qos_policy_id.DDS_LIVELINESS_QOS_POLICY_ID

    live_duration_rd = to_kind_live_duration(endpoint_reader.qos)
    live_duration_wr = to_kind_live_duration(endpoint_writer.qos)
    if live_duration_rd and live_duration_wr and live_duration_rd < live_duration_wr:
        return False, dds_qos_policy_id.DDS_LIVELINESS_QOS_POLICY_ID

    destination_order_rd = to_kind_destination_order(endpoint_reader.qos)
    destination_order_wr = to_kind_destination_order(endpoint_writer.qos)
    if destination_order_rd and destination_order_wr and destination_order_rd > destination_order_wr:
        return False, dds_qos_policy_id.DDS_DESTINATIONORDER_QOS_POLICY_ID


    """        
    if ((mask & DDSI_QP_PARTITION) && !partitions_match_p (rd_qos, wr_qos)) 
        *reason = DDS_PARTITION_QOS_POLICY_ID;
        return false;
    """

    if qos.Policy.DataRepresentation in endpoint_reader.qos and qos.Policy.DataRepresentation in endpoint_writer.qos:
        if endpoint_writer.qos[qos.Policy.DataRepresentation].use_cdrv0_representation and endpoint_reader.qos[qos.Policy.DataRepresentation].use_cdrv0_representation:
            pass # ok - both using cdrv0
        elif endpoint_writer.qos[qos.Policy.DataRepresentation].use_xcdrv2_representation and endpoint_reader.qos[qos.Policy.DataRepresentation].use_xcdrv2_representation:
            pass # ok - both using xcdrv2
        else:
            return False, dds_qos_policy_id.DDS_DATA_REPRESENTATION_QOS_POLICY_ID

    if feature_typelib:
        type_pair_has_id = False # TODO
        # if (!type_pair_has_id (rd_type_pair) || !type_pair_has_id (wr_type_pair))
        if not type_pair_has_id or not type_pair_has_id:
            
            if qos.Policy.TypeConsistency.AllowTypeCoercion in endpoint_reader.qos and endpoint_reader.qos[qos.Policy.TypeConsistency.AllowTypeCoercion].force_type_validation:
                return False, dds_qos_policy_id.DDS_TYPE_CONSISTENCY_ENFORCEMENT_QOS_POLICY_ID
            if qos.Policy.TypeConsistency.DisallowTypeCoercion in endpoint_reader.qos and endpoint_reader.qos[qos.Policy.TypeConsistency.DisallowTypeCoercion].force_type_validation:
                return False, dds_qos_policy_id.DDS_TYPE_CONSISTENCY_ENFORCEMENT_QOS_POLICY_ID
            
            if endpoint_reader.type_name != endpoint_writer.type_name:
                return False, dds_qos_policy_id.DDS_INVALID_QOS_POLICY_ID

        else:

            if qos.Policy.TypeConsistency.DisallowTypeCoercion in endpoint_reader.qos and endpoint_reader.qos[qos.Policy.TypeConsistency.DisallowTypeCoercion].force_type_validation:
                # if ddsi_typeid_compare (ddsi_type_pair_minimal_id (rd_type_pair), ddsi_type_pair_minimal_id (wr_type_pair)))
                #     return False, dds_qos_policy_id.DDS_TYPE_CONSISTENCY_ENFORCEMENT_QOS_POLICY_ID
                pass
            else:
                pass
            """
            else
            {
                dds_type_consistency_enforcement_qospolicy_t tce = {
                .kind = DDS_TYPE_CONSISTENCY_ALLOW_TYPE_COERCION,
                .ignore_sequence_bounds = true,
                .ignore_string_bounds = true,
                .ignore_member_names = false,
                .prevent_type_widening = false,
                .force_type_validation = false
                };
                (void) dds_qget_type_consistency (rd_qos, &tce.kind, &tce.ignore_sequence_bounds, &tce.ignore_string_bounds, &tce.ignore_member_names, &tce.prevent_type_widening, &tce.force_type_validation);

                if (tce.kind == DDS_TYPE_CONSISTENCY_DISALLOW_TYPE_COERCION)
                {
                    if (ddsi_typeid_compare (ddsi_type_pair_minimal_id (rd_type_pair), ddsi_type_pair_minimal_id (wr_type_pair)))
                    {
                        *reason = DDS_TYPE_CONSISTENCY_ENFORCEMENT_QOS_POLICY_ID;
                        return false;
                    }
                }
                else
                {
                    uint32_t rd_resolved, wr_resolved;
                    if (!(rd_resolved = is_endpoint_type_resolved (gv, rd_qos->type_name, rd_type_pair, rd_typeid_req_lookup, "rd"))
                        || !(wr_resolved = is_endpoint_type_resolved (gv, wr_qos->type_name, wr_type_pair, wr_typeid_req_lookup, "wr")))
                        return false;

                    if (!ddsi_is_assignable_from (gv, rd_type_pair, rd_resolved, wr_type_pair, wr_resolved, &tce))
                    {
                        *reason = DDS_TYPE_CONSISTENCY_ENFORCEMENT_QOS_POLICY_ID;
                        return false;
                    }
                }
            }
            #else
            """
    else:
        if endpoint_reader.type_name != endpoint_writer.type_name:
            return False, dds_qos_policy_id.DDS_INVALID_QOS_POLICY_ID


    return True, None
