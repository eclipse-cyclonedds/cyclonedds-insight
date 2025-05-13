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
from PySide6.QtCore import QStandardPaths, QDir, QObject, Slot, Signal
from PySide6.QtWidgets import QApplication
from PySide6.QtGui import Qt
from loguru import logger as logging
import os
import sys
from enum import Enum


class QmlUtils(QObject):

    aboutToQuit = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)

    @Slot(int)
    def setColorScheme(self, scheme):
        QApplication.styleHints().setColorScheme(Qt.ColorScheme(scheme))
