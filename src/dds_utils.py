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
from cyclonedds import core


HOSTNAMES     = ["__Hostname",    "dds.sys_info.hostname", "fastdds.physical_data.host"]
PROCESS_NAMES = ["__ProcessName", "dds.sys_info.executable_filepath"]
PIDS          = ["__Pid",         "dds.sys_info.process_id", "fastdds.physical_data.process"]
ADDRESSES     = ["__NetworkAddresses"]


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
