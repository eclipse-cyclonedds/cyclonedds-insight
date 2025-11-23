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

from typing import Optional, List
from cyclonedds.builtin import DcpsParticipant
from cyclonedds import core, dynamic
from cyclonedds import core
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration
from dds_access.domain_participant_factory import DomainParticipantFactory
from loguru import logger as logging
import xml.etree.ElementTree as ET
import os
import re
from pathlib import Path


HOSTNAMES     = ["__Hostname",    "dds.sys_info.hostname", "fastdds.physical_data.host"]
PROCESS_NAMES = ["__ProcessName", "dds.sys_info.executable_filepath", "fastdds.application.id"]
PIDS          = ["__Pid",         "dds.sys_info.process_id", "fastdds.physical_data.process"]
ADDRESSES     = ["__NetworkAddresses"]
DEBUG_MONITORS = ["__DebugMonitor"]

CYCLONEDDS_URI_NAME = "CYCLONEDDS_URI"

MAX_SAMPLE_SIZE = 67108863


def getProperty(p: Optional[DcpsParticipant], names: List[str]):
    propName: str = "Unknown"
    if p is None:
        return propName
    for item in names:
        if p.qos[core.Policy.Property(item, "Unknown")] is not None:
            propName = str(p.qos[core.Policy.Property(item, "Unknown")].value)
            if propName != "Unknown":
                break
    return propName

def getAppName(p: Optional[DcpsParticipant]):
    appNameWithPath = getProperty(p, PROCESS_NAMES)
    pid = getProperty(p, PIDS)
    appNameStem = Path(appNameWithPath.replace("\\", f"{os.path.sep}")).stem
    return  appNameStem + ":" + pid

def getHostname(p: Optional[DcpsParticipant]):
    hostnameRaw = getProperty(p, HOSTNAMES)
    if ":" in hostnameRaw:
        hostnameSplit = hostnameRaw.split(":")
        if len(hostnameSplit) > 0:
            return hostnameSplit[0]
    return hostnameRaw


def isVendorCycloneDDS(p: Optional[DcpsParticipant]) -> bool:

    if p is not None:
        try:
            cyc_prop_host = p.qos[core.Policy.Property(HOSTNAMES[0], "Unknown")]
            cyc_prop_proc = p.qos[core.Policy.Property(PROCESS_NAMES[0], "Unknown")]
            cyc_prop_pid = p.qos[core.Policy.Property(PIDS[0], "Unknown")]
            if None in [cyc_prop_host, cyc_prop_proc, cyc_prop_pid]:
                return False
            else:
                return True
        except Exception:
            pass

    return False

def getConfiguredDomainIds():

    def expandEnvVariable(value):
        pattern = re.compile(r'\${(\w+)}|\$(\w+)')
        def replacer(match):
            var_name = match.group(1) or match.group(2)
            return os.getenv(var_name, "0")
        return pattern.sub(replacer, value)

    cycloneUriContent = os.getenv(CYCLONEDDS_URI_NAME)
    if not cycloneUriContent:
        # variable not set (None or empty str)
        return []

    if cycloneUriContent.startswith("file://"):
        cycloneUriContent = cycloneUriContent.replace("file://", "")

    try:
        if os.path.isabs(cycloneUriContent) or os.path.exists(cycloneUriContent):
            with open(cycloneUriContent, 'r') as file:
                content = file.read()
            root = ET.fromstring(content)
        else:
            root = ET.fromstring(cycloneUriContent)
    except Exception as e:
        logging.error(f"Failed to parse {CYCLONEDDS_URI_NAME} xml: {str(e)}")
        return []

    domain_ids = set()
    for domain in root.findall("./{*}Domain"):
        domain_id_str = domain.get("Id", "any")
        if domain_id_str.lower() == "any":
            continue
        else:
            try:
                domain_id_str = expandEnvVariable(domain_id_str)
                domain_id = int(domain_id_str)
                domain_ids.add(domain_id)
            except Exception as e:
                logging.error(f"Failed to get domain id: {str(e)} from {domain_id_str}")

    return sorted(domain_ids)


def getDataType(domainId, endp):
    with DomainParticipantFactory.get_participant(domainId) as participant:
        try:
            requestedDataType, _ = dynamic.get_types_for_typeid(participant, endp.type_id, duration(seconds=3))
            return requestedDataType
        except Exception as e:
            logging.error(str(e))

    return None

def normalizeGuid(guid: str) -> str:

    parts = guid.split(':')
    if len(parts) != 4:
        return guid

    part0 = parts[0].rjust(8, '0')
    part1 = parts[1].rjust(8, '0')
    part2 = parts[2].rjust(8, '0')
    part3 = parts[3].zfill(8)

    return f"{part0}-{part1[:4]}-{part1[4:8]}-{part2[:4]}-{part2[4:8]}{part3}"

def toQos(
        # Reader/Writer
        q_own, q_dur, q_rel, q_rel_max_block_msec, q_xcdr1, q_xcdr2,
        type_consis, ig_seq_bnds, ig_str_bnds, ign_mem_nam, prev_ty_wide, fore_type_vali, fore_type_vali_allow,
        history, history_keep_last_nr,
        destination_order,
        liveliness, liveliness_seconds,
        lifespan_seconds, deadline_seconds, latencybudget_seconds, owner_strength,
        writer_life_autodispose,
        reader_life_nowriter_delay, reader_life_disposed, transport_prio,
        limit_max_samples, limit_max_instances, limit_max_samples_per_instance,
        timebased_filter_time_sec, ignore_local,
        user_data, entity_name, prop_name, prop_value, prop_propagate, bin_prop_name, bin_prop_value, bin_prop_propagate,
        durserv_cleanup_delay_minutes, durserv_history, durserv_history_keep_last_nr,
        durserv_max_samples, durserv_max_instances, durserv_max_samples_per_instance,
        # Pub/Sub
        partitions,
        presentation_access_scope, pres_acc_scope_coherent, pres_acc_scope_ordered,
        pubSubGroupData,
        # Topic
        topicQosOwn, topicQosDur, topicQosRel, topicQosRelMaxBlockMsec, topicQosXcdr1, topicQosXcdr2,
        topicQosHistory, topicQosHistoryKeepLastNr, topicQosDestinationOrder,
        topicQosLiveliness, topicQosLivelinessSeconds,
        topicQosLifespanSeconds, topicQosDeadlineSeconds, topicQosLatencybudgetSeconds, topicQosTransportPrio,
        topicQosLimitMaxSamples, topicQosLimitMaxInstances, topicQosLimitMaxSamplesPerInstance,
        topicQosTopicData, topicQosDurservCleanupDelayMinutes, topicQosDurservHistory, topicQosDurservHistoryKeepLastNr,
        topicQosDurservMaxSamples, topicQosDurservMaxInstances, topicQosDurservMaxSamplesPerInstance,
        # Participant
        dpUserdataField, dpAutoEnable):

        # Reader/Writer
        qos = Qos()
        if q_own == "DDS_OWNERSHIP_SHARED":
            qos += Qos(Policy.Ownership.Shared)
        elif q_own == "DDS_OWNERSHIP_EXCLUSIVE":
            qos += Qos(Policy.Ownership.Exclusive)

        if q_dur == "DDS_DURABILITY_VOLATILE":
            qos += Qos(Policy.Durability.Volatile)
        elif q_dur == "DDS_DURABILITY_TRANSIENT_LOCAL":
            qos += Qos(Policy.Durability.TransientLocal)
        elif q_dur == "DDS_DURABILITY_TRANSIENT":
            qos += Qos(Policy.Durability.Transient)
        elif q_dur == "DDS_DURABILITY_PERSISTENT":
            qos += Qos(Policy.Durability.Persistent)

        if q_rel == "DDS_RELIABILITY_BEST_EFFORT":
            qos += Qos(Policy.Reliability.BestEffort)
        elif q_rel == "DDS_RELIABILITY_RELIABLE":
            qos += Qos(Policy.Reliability.Reliable(
                max_blocking_time=duration(milliseconds=q_rel_max_block_msec) if q_rel_max_block_msec >= 0 else duration(infinite=True)))

        if q_xcdr1 or q_xcdr2:
            qos += Qos(Policy.DataRepresentation(use_cdrv0_representation=q_xcdr1, use_xcdrv2_representation=q_xcdr2))

        if type_consis == "AllowTypeCoercion":
            qos += Qos(Policy.TypeConsistency.AllowTypeCoercion(
                ignore_sequence_bounds=ig_seq_bnds,
                ignore_string_bounds=ig_str_bnds,
                ignore_member_names=ign_mem_nam,
                prevent_type_widening=prev_ty_wide,
                force_type_validation=fore_type_vali))
        elif type_consis == "DisallowTypeCoercion":
            qos += Qos(Policy.TypeConsistency.DisallowTypeCoercion(force_type_validation=fore_type_vali_allow))

        if history == "KeepAll":
            qos += Qos(Policy.History.KeepAll)
        elif history == "KeepLast":
            qos += Qos(Policy.History.KeepLast(history_keep_last_nr))

        if destination_order == "ByReceptionTimestamp":
            qos += Qos(Policy.DestinationOrder.ByReceptionTimestamp)
        elif destination_order == "BySourceTimestamp":
            qos += Qos(Policy.DestinationOrder.BySourceTimestamp)

        liveliness_duration = duration(seconds=liveliness_seconds) if liveliness_seconds >= 0 else duration(infinite=True)
        if liveliness == "Automatic":
            qos += Qos(Policy.Liveliness.Automatic(liveliness_duration))
        elif liveliness == "ManualByParticipant":
            qos += Qos(Policy.Liveliness.ManualByParticipant(liveliness_duration))
        elif liveliness == "ManualByTopic":
            qos += Qos(Policy.Liveliness.ManualByTopic(liveliness_duration))

        qos += Qos(Policy.Lifespan(duration(seconds=lifespan_seconds) if lifespan_seconds >= 0 else duration(infinite=True)))
        qos += Qos(Policy.Deadline(duration(seconds=deadline_seconds) if deadline_seconds >= 0 else duration(infinite=True)))
        qos += Qos(Policy.LatencyBudget(duration(seconds=latencybudget_seconds) if latencybudget_seconds >= 0 else duration(infinite=True)))
        qos += Qos(Policy.OwnershipStrength(owner_strength))

        qos += Qos(Policy.WriterDataLifecycle(autodispose=writer_life_autodispose))

        qos += Qos(Policy.ReaderDataLifecycle(
            autopurge_nowriter_samples_delay=duration(seconds=reader_life_nowriter_delay) if reader_life_nowriter_delay >= 0 else duration(infinite=True),
            autopurge_disposed_samples_delay=duration(seconds=reader_life_disposed) if reader_life_disposed >= 0 else duration(infinite=True)
        ))

        qos += Qos(Policy.TransportPriority(transport_prio))
        qos += Qos(Policy.ResourceLimits(
            max_samples=limit_max_samples, max_instances=limit_max_instances, max_samples_per_instance=limit_max_samples_per_instance))
        qos += Qos(Policy.TimeBasedFilter(filter_time=duration(seconds=timebased_filter_time_sec)))

        if ignore_local == "Nothing":
            qos += Qos(Policy.IgnoreLocal.Nothing)
        elif ignore_local == "Participant":
            qos += Qos(Policy.IgnoreLocal.Participant)
        elif ignore_local == "Process":
            qos += Qos(Policy.IgnoreLocal.Process)

        if user_data:
            qos += Qos(Policy.Userdata(data=user_data.encode('utf-8')))

        if entity_name:
            qos += Qos(Policy.EntityName(name=entity_name))

        if prop_name and prop_value:
            qos += Qos(Policy.Property(key=prop_name, value=prop_value, propagate=prop_propagate))

        if bin_prop_name and bin_prop_value:
            qos += Qos(Policy.BinaryProperty(key=bin_prop_name, value=bin_prop_value.encode('utf-8'), propagate=bin_prop_propagate))

        qos += Qos(Policy.DurabilityService(
            cleanup_delay=duration(minutes=durserv_cleanup_delay_minutes) if durserv_cleanup_delay_minutes >= 0 else duration(infinite=True),
            history=Policy.History.KeepLast(durserv_history_keep_last_nr) if durserv_history == "KeepLast" else Policy.History.KeepAll,
            max_samples=durserv_max_samples,
            max_instances=durserv_max_instances,
            max_samples_per_instance=durserv_max_samples_per_instance))

        # Pub/Sub
        pubSubQos = Qos()
        if len(partitions) > 0:
            pubSubQos += Qos(Policy.Partition(partitions=partitions))

        if presentation_access_scope == "Instance":
            pubSubQos += Qos(Policy.PresentationAccessScope.Instance(coherent_access=pres_acc_scope_coherent, ordered_access=pres_acc_scope_ordered))
        elif presentation_access_scope == "Topic":
            pubSubQos += Qos(Policy.PresentationAccessScope.Topic(coherent_access=pres_acc_scope_coherent, ordered_access=pres_acc_scope_ordered))
        elif presentation_access_scope == "Group":
            pubSubQos += Qos(Policy.PresentationAccessScope.Group(coherent_access=pres_acc_scope_coherent, ordered_access=pres_acc_scope_ordered))

        if pubSubGroupData:
            pubSubQos += Qos(Policy.Groupdata(data=pubSubGroupData.encode('utf-8')))

        # Topic
        topicQos = Qos()
        if topicQosOwn == "DDS_OWNERSHIP_SHARED":
            topicQos += Qos(Policy.Ownership.Shared)
        elif topicQosOwn == "DDS_OWNERSHIP_EXCLUSIVE":
            topicQos += Qos(Policy.Ownership.Exclusive)

        if topicQosDur == "DDS_DURABILITY_VOLATILE":
            topicQos += Qos(Policy.Durability.Volatile)
        elif topicQosDur == "DDS_DURABILITY_TRANSIENT_LOCAL":
            topicQos += Qos(Policy.Durability.TransientLocal)
        elif topicQosDur == "DDS_DURABILITY_TRANSIENT":
            topicQos += Qos(Policy.Durability.Transient)
        elif topicQosDur == "DDS_DURABILITY_PERSISTENT":
            topicQos += Qos(Policy.Durability.Persistent)

        if topicQosRel == "DDS_RELIABILITY_BEST_EFFORT":
            topicQos += Qos(Policy.Reliability.BestEffort)
        elif topicQosRel == "DDS_RELIABILITY_RELIABLE":
            topicQos += Qos(Policy.Reliability.Reliable(
                max_blocking_time=duration(milliseconds=topicQosRelMaxBlockMsec) if topicQosRelMaxBlockMsec >= 0 else duration(infinite=True)))

        if topicQosXcdr1 or topicQosXcdr2:
            topicQos += Qos(Policy.DataRepresentation(use_cdrv0_representation=topicQosXcdr1, use_xcdrv2_representation=topicQosXcdr2))

        if topicQosHistory == "KeepAll":
            topicQos += Qos(Policy.History.KeepAll)
        elif topicQosHistory == "KeepLast":
            topicQos += Qos(Policy.History.KeepLast(topicQosHistoryKeepLastNr))

        if topicQosDestinationOrder == "ByReceptionTimestamp":
            topicQos += Qos(Policy.DestinationOrder.ByReceptionTimestamp)
        elif topicQosDestinationOrder == "BySourceTimestamp":
            topicQos += Qos(Policy.DestinationOrder.BySourceTimestamp)

        topicQosLivelinessDuration = duration(seconds=topicQosLivelinessSeconds) if topicQosLivelinessSeconds >= 0 else duration(infinite=True)
        if topicQosLiveliness == "Automatic":
            topicQos += Qos(Policy.Liveliness.Automatic(topicQosLivelinessDuration))
        elif topicQosLiveliness == "ManualByParticipant":
            topicQos += Qos(Policy.Liveliness.ManualByParticipant(topicQosLivelinessDuration))
        elif topicQosLiveliness == "ManualByTopic":
            topicQos += Qos(Policy.Liveliness.ManualByTopic(topicQosLivelinessDuration))

        topicQos += Qos(Policy.Lifespan(duration(seconds=topicQosLifespanSeconds) if topicQosLifespanSeconds >= 0 else duration(infinite=True)))
        topicQos += Qos(Policy.Deadline(duration(seconds=topicQosDeadlineSeconds) if topicQosDeadlineSeconds >= 0 else duration(infinite=True)))
        topicQos += Qos(Policy.LatencyBudget(duration(seconds=topicQosLatencybudgetSeconds) if topicQosLatencybudgetSeconds >= 0 else duration(infinite=True)))
        topicQos += Qos(Policy.TransportPriority(topicQosTransportPrio))
        topicQos += Qos(Policy.ResourceLimits(
            max_samples=topicQosLimitMaxSamples, max_instances=topicQosLimitMaxInstances, max_samples_per_instance=topicQosLimitMaxSamplesPerInstance))
        topicQos += Qos(Policy.DurabilityService(
            cleanup_delay=duration(minutes=topicQosDurservCleanupDelayMinutes) if topicQosDurservCleanupDelayMinutes >= 0 else duration(infinite=True),
            history=Policy.History.KeepLast(topicQosDurservHistoryKeepLastNr) if topicQosDurservHistory == "KeepLast" else Policy.History.KeepAll,
            max_samples=topicQosDurservMaxSamples,
            max_instances=topicQosDurservMaxInstances,
            max_samples_per_instance=topicQosDurservMaxSamplesPerInstance))

        if topicQosTopicData:
            topicQos += Qos(Policy.Topicdata(data=topicQosTopicData.encode('utf-8')))

        # Participant
        dpQps = Qos()
        if dpUserdataField:
            dpQps += Qos(Policy.Userdata(data=dpUserdataField.encode('utf-8')))

        if dpAutoEnable:
            # dpQps += Qos(Policy.AutoEnable()) # CycloneDDS does not support this policy
            pass

        return dpQps, topicQos, pubSubQos, qos
