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
from cyclonedds import core
from cyclonedds.sub import DataReader, Subscriber
from cyclonedds.pub import DataWriter
from cyclonedds.internal import dds_c_t
from dds_access.dds_qos import dds_qos_policy_id


def status_to_string(status) -> str:
    status_text = ""
    for i, (name, _) in enumerate(status._fields_):
        status_text += f"{name}={getattr(status, name)}"
        if i < len(status._fields_) - 1:
            status_text += ", "
    return status_text


class DdsListener(core.Listener):

    def on_inconsistent_topic(self, reader: DataReader, status: dds_c_t.inconsistent_topic_status):
        if reader and status:
            logging.warning(f"on_inconsistent_topic: {reader.topic.name}, type: {reader.topic.typename}, {status_to_string(status)}")
        else:
            logging.warning("on_inconsistent_topic")

    def on_liveliness_lost(self, writer: DataWriter, status: dds_c_t.liveliness_lost_status):
        if writer and status:
            logging.debug(f"on_liveliness_lost: {writer.topic.name}, type: {writer.topic.typename}, {status_to_string(status)}")
        else:
            logging.debug("on_liveliness_lost")

    def on_liveliness_changed(self, reader: DataReader, status: dds_c_t.liveliness_changed_status):
        if reader and status:
            logging.debug(f"on_liveliness_changed: {reader.topic.name}, type: {reader.topic.typename}, {status_to_string(status)}")
        else:
            logging.debug("on_liveliness_changed")

    def on_offered_deadline_missed(self, writer: DataWriter, status: dds_c_t.offered_deadline_missed_status):
        if writer and status:
            logging.warning(f"on_offered_deadline_missed: topic: {writer.topic.name}, type: {writer.topic.typename}, {status_to_string(status)}")
        else:
            logging.warning("on_offered_deadline_missed")

    def on_offered_incompatible_qos(self, writer: DataWriter, status: dds_c_t.offered_incompatible_qos_status):
        if writer and status:
            # The check is only here because currently there is a bug in cyclonedds
            # that causes the partition to be shown as incompatible.
            if dds_qos_policy_id(status.last_policy_id) != dds_qos_policy_id.DDS_PARTITION_QOS_POLICY_ID:
                logging.warning(f"on_offered_incompatible_qos: {writer.topic.name}, type: {writer.topic.typename}, {status_to_string(status)}, "
                                f"last_policy_name: {dds_qos_policy_id(status.last_policy_id).name}")
        else:
            logging.warning("on_offered_incompatible_qos")

    def on_data_on_readers(self, subscriber: Subscriber):
        pass

    def on_sample_lost(self, writer: DataWriter, status: dds_c_t.sample_lost_status):
        if writer and status:
            logging.warning(f"on_sample_lost: {writer.topic.name}, type: {writer.topic.typename}, {status_to_string(status)}")
        else:
            logging.warning("on_sample_lost")

    def on_sample_rejected(self, reader: DataReader, status: dds_c_t.sample_rejected_status):
        if reader and status:
            logging.warning(f"on_sample_rejected: {reader.instance_handle}, topic: {reader.topic.name}, {status_to_string(status)}")
        else:
            logging.warning("on_sample_rejected")

    def on_requested_deadline_missed(self, reader: DataReader, status: dds_c_t.requested_deadline_missed_status):
        if reader and status:
            logging.warning(f"on_requested_deadline_missed: {reader.instance_handle}, topic: {reader.topic.name}, {status_to_string(status)}")
        else:
            logging.warning("on_requested_deadline_missed")

    def on_requested_incompatible_qos(self, reader: DataReader, status: dds_c_t.requested_incompatible_qos_status):
        if reader and status:
            # The check is only here because currently there is a bug in cyclonedds
            # that causes the partition to be shown as incompatible.
            if dds_qos_policy_id(status.last_policy_id) != dds_qos_policy_id.DDS_PARTITION_QOS_POLICY_ID:
                logging.warning(f"on_requested_incompatible_qos: {reader.topic.name}, "
                                f"type: {reader.topic.typename}, {status_to_string(status)}, "
                                f"last_policy_name: {dds_qos_policy_id(status.last_policy_id).name}")
        else:
            logging.warning("on_requested_incompatible_qos")

    def on_publication_matched(self, writer: DataWriter, status: dds_c_t.publication_matched_status):
        if writer and status:
            logging.debug(f"on_publication_matched: {writer.instance_handle}, topic: {writer.topic.name}, {status_to_string(status)}")
        else:
            logging.debug("on_publication_matched")

    def on_subscription_matched(self, reader: DataReader, status: dds_c_t.subscription_matched_status):
        if reader and status:
            logging.debug(f"on_subscription_matched: {reader.topic.name}, type: {reader.topic.typename}, {status_to_string(status)}")
        else:
            logging.debug("on_subscription_matched")
