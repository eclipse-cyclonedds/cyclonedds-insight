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
import uuid
from cyclonedds.builtin import DcpsParticipant
from cyclonedds.core import Qos, Policy
from dds_access.datatypes.ospl.kernelModule import v_participantCMInfo
import xml.etree.ElementTree as ET
from typing import Optional


def from_ospl(participantCMInfo: v_participantCMInfo) -> Optional[DcpsParticipant]:
    logging.trace(f"extract ospl info from: {str(participantCMInfo)}")
    entity_id = "000001c1"
    try:
        key = uuid.UUID(f"{participantCMInfo.key.systemId:08x}{participantCMInfo.key.localId:08x}{participantCMInfo.key.serial:08x}{entity_id}")
        xml_root = ET.fromstring(participantCMInfo.product.value)
        pid = xml_root.find("PID").text
        process_name = xml_root.find("ExecName").text
        hostname = xml_root.find("NodeName").text
        p_update = DcpsParticipant(
            key=key,
            qos = Qos(
                Policy.Property(key="__Hostname", value=hostname),
                Policy.Property(key="__Pid", value=pid),
                Policy.Property(key="__ProcessName", value=process_name)))
        return p_update
    except Exception as e:
        logging.error(str(e))
    return None
