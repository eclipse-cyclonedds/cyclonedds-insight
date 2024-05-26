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

from PySide6 import QtCore
import logging
import os
from enum import Enum

@QtCore.QEnum
class EntityType(Enum):
    UNDEFINED = 1
    TOPIC = 2
    READER = 3
    WRITER = 4

def qt_message_handler(mode, context, message):
    file = os.path.basename(context.file)
    log_msg = f"[{file}:{context.line}] {message}"
    if mode == QtCore.QtMsgType.QtInfoMsg:
        logging.info(log_msg)
    elif mode == QtCore.QtMsgType.QtWarningMsg:
        logging.warning(log_msg)
    elif mode == QtCore.QtMsgType.QtCriticalMsg:
        logging.critical(log_msg)
    elif mode == QtCore.QtMsgType.QtFatalMsg:
        logging.fatal(log_msg)
    else:
        logging.debug(log_msg)

def singleton(cls):
    instances = {}
    def getinstance():
        if cls not in instances:
            instances[cls] = cls()
        return instances[cls]
    return getinstance

class OrderedEnum(Enum):

    def __ge__(self, other):

        if self.__class__ is other.__class__:

            return self.value >= other.value

        return NotImplemented

    def __gt__(self, other):

        if self.__class__ is other.__class__:

            return self.value > other.value

        return NotImplemented

    def __le__(self, other):

        if self.__class__ is other.__class__:

            return self.value <= other.value

        return NotImplemented

    def __lt__(self, other):

        if self.__class__ is other.__class__:

            return self.value < other.value

        return NotImplemented


