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
from PySide6.QtCore import QStandardPaths, QDir, QObject, Slot, Signal, QFile, QFileInfo, QUrl
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

    @Slot(str, result=str)
    def loadFileContent(self, file_path: str) -> str:
        file_path = self.removeFilePrefix(file_path)

        if not os.path.isfile(file_path):
            logging.error(f"File does not exist: {file_path}")
            return ""

        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                content = file.read()
                return content
        except Exception as e:
            logging.error(f"Error reading file {file_path}: {e}")
            return ""

    @Slot(str, str)
    def saveFileContent(self, file_path, content):
        file_path = self.removeFilePrefix(file_path)
        if not os.path.isfile(file_path):
            logging.error(f"File does not exist: {file_path}")
            return ""
        try:
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(content)
        except Exception as e:
            logging.error(f"Error writing file: {e}")

    @Slot(result=str)
    def getUserHome(self):
        return os.path.expanduser("~")

    @Slot(str, result=bool)
    def isValidFile(self, path):
        file_info = QFileInfo(self.removeFilePrefix(path))
        return file_info.exists() and file_info.isFile()

    @Slot(QUrl, result=str)
    def toLocalFile(self, uri):
        return uri.toLocalFile()

    @Slot(QUrl)
    def createFileFromQUrl(self, url):
        path = url.toLocalFile()
        file = QFile(path)
        info = QFileInfo(file)
        if not info.exists():
            dir_path = info.absolutePath()
            if not QDir().mkpath(dir_path):
                logging.error(f"Failed to create directories: {dir_path}")
                return

            if file.open(QFile.WriteOnly):
                logging.debug(f"Created new file: {path}")
                file.close()
            else:
                logging.error(f"Failed to create file: {path}")
        else:
            logging.info(f"File already exists: {path}")

    def removeFilePrefix(self, file_path: str) -> str:
        if file_path.startswith("file://"):
            return file_path[7:]
        return file_path
