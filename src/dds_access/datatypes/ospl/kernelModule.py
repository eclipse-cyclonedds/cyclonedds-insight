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

from dataclasses import dataclass

import cyclonedds.idl as idl
import cyclonedds.idl.annotations as annotate
import cyclonedds.idl.types as types


@dataclass
@annotate.final
@annotate.autoid("sequential")
@annotate.nested
class v_gid(idl.IdlStruct, typename="dds_access.datatypes.ospl.kernelModule.v_gid"):
    systemId: types.uint32
    annotate.key("systemId")
    localId: types.uint32
    annotate.key("localId")
    serial: types.uint32


v_builtinTopicKey = types.typedef['dds_access.datatypes.ospl.kernelModule.v_builtinTopicKey', 'dds_access.datatypes.ospl.kernelModule.v_gid']


@dataclass
@annotate.final
@annotate.autoid("sequential")
@annotate.nested
class v_productDataPolicy(idl.IdlStruct, typename="dds_access.datatypes.ospl.kernelModule.v_productDataPolicy"):
    value: str


@dataclass
@annotate.final
@annotate.autoid("sequential")
class v_participantCMInfo(idl.IdlStruct, typename="kernelModule.v_participantCMInfo"):
    key: 'dds_access.datatypes.ospl.kernelModule.v_builtinTopicKey'
    annotate.key("key")
    product: 'dds_access.datatypes.ospl.kernelModule.v_productDataPolicy'
