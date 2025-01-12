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
from cyclonedds import core
from dds_access.dds_qos import dds_qos_policy_id


class DdsListener(core.Listener):

    def on_inconsistent_topic(self, reader, status):
        logging.warning("on_inconsistent_topic")
        
    def on_liveliness_lost(self, writer, status):
        logging.debug("on_liveliness_lost")

    def on_liveliness_changed(self, reader, status):
        logging.debug("on_liveliness_changed")

    def on_offered_deadline_missed(self, writer, status):
        logging.warning("on_offered_deadline_missed")

    def on_offered_incompatible_qos(self, writer, status):
        # QoS mismatches are not worthy of a warning (they should not have been a QoS in DDS in the first place)
        # Most likely a mismatch is intended, otherwise there is no reason to use partitions.
        # We show matching partitions inside the gui to be able to verify them.
        if dds_qos_policy_id(status.last_policy_id) != dds_qos_policy_id.DDS_PARTITION_QOS_POLICY_ID:
            logging.warning(f"on_offered_incompatible_qos: {dds_qos_policy_id(status.last_policy_id).name}")

    def on_data_on_readers(self, subscriber):
        logging.debug("on_data_on_readers")

    def on_sample_lost(self, writer, status):
        logging.warning("on_sample_lost")

    def on_sample_rejected(self, reader, status):
        logging.warning("on_sample_rejected")

    def on_requested_deadline_missed(self, reader,status):
        logging.warning("on_sample_rejected")

    def on_requested_incompatible_qos(self, reader, status):
        # QoS mismatches are not worthy of a warning (they should not have been a QoS in DDS in the first place)
        # Most likely a mismatch is intended, otherwise there is no reason to use partitions.
        # We show matching partitions inside the gui to be able to verify them.
        if dds_qos_policy_id(status.last_policy_id) != dds_qos_policy_id.DDS_PARTITION_QOS_POLICY_ID:
            logging.warning(f"on_requested_incompatible_qos: {dds_qos_policy_id(status.last_policy_id).name}")

    def on_publication_matched(self, writer, status):
        logging.debug("on_publication_matched")

    def on_subscription_matched(self, reader, status):
        logging.debug("on_subscription_matched")
