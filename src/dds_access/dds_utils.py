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
from cyclonedds.util import duration
from dds_access.DomainParticipantFactory import DomainParticipantFactory
import logging
import xml.etree.ElementTree as ET
import os
import re


HOSTNAMES     = ["__Hostname",    "dds.sys_info.hostname", "fastdds.physical_data.host"]
PROCESS_NAMES = ["__ProcessName", "dds.sys_info.executable_filepath"]
PIDS          = ["__Pid",         "dds.sys_info.process_id", "fastdds.physical_data.process"]
ADDRESSES     = ["__NetworkAddresses"]

CYCLONEDDS_URI_NAME = "CYCLONEDDS_URI"


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
