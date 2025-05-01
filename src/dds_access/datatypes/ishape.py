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
from enum import auto


@dataclass
@annotate.appendable
@annotate.autoid("sequential")
class ShapeType(idl.IdlStruct, typename="ShapeTypeBase"):
    color: str
    annotate.key("color")
    x: types.int32
    y: types.int32
    shapesize: types.int32


@annotate.appendable
class ShapeFillKind(idl.IdlEnum, typename="ShapeFillKind", default="SOLID_FILL"):
    SOLID_FILL = auto()
    TRANSPARENT_FILL = auto()
    HORIZONTAL_HATCH_FILL = auto()
    VERTICAL_HATCH_FILL = auto()


@dataclass
@annotate.appendable
@annotate.autoid("sequential")
class ShapeTypeExtended(ShapeType, typename="ShapeType"):
    fillKind: 'ShapeFillKind'
    angle: types.float32

