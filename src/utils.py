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
from PySide6.QtCore import QStandardPaths, QDir, QObject, Slot
from PySide6.QtWidgets import QApplication
from PySide6.QtGui import Qt
import logging
from logging.handlers import RotatingFileHandler
import os
from enum import Enum


@QtCore.QEnum
class EntityType(Enum):
    UNDEFINED = 1
    TOPIC = 2
    READER = 3
    WRITER = 4

def qt_message_handler(mode, context, message):
    file = context.file
    if file:
        file = os.path.basename(file)
    else:
        file = "<unknown>"
    if message.startswith("qrc:/"):
        message = message[len("qrc:/"):] 
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

def setupLogger(log_level = logging.DEBUG):
    
    logger = logging.getLogger()
    logger.handlers.clear()
    logger.setLevel(log_level)

    app_data_dir = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
    if len(app_data_dir) == 0:
        print("Failed to locate basic app folders")
        exit(-1)

    log_dir = os.path.join(app_data_dir, "logs")
    if not QDir(log_dir).exists():
        QDir().mkpath(log_dir)

    log_file = os.path.join(log_dir, "cyclonedds_insight.log")
    file_handler = RotatingFileHandler(log_file, maxBytes=1024*1024, backupCount=5) # Rotates after 1MB, keeps 5 backups
    file_handler.setLevel(log_level)

    stream_handler = logging.StreamHandler()
    stream_handler.setLevel(log_level)

    formatter = logging.Formatter('%(asctime)s [%(levelname)s] [%(filename)s:%(lineno)s] %(message)s')
    file_handler.setFormatter(formatter)
    stream_handler.setFormatter(formatter)

    logger.addHandler(file_handler)
    logger.addHandler(stream_handler)

def getBuildInfoGitHashShort() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_GIT_HASH_SHORT
        return CYCLONEDDS_INSIGHT_GIT_HASH_SHORT
    except Exception:
        return "n/a"

def getBuildInfoGitHash() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_GIT_HASH
        return CYCLONEDDS_INSIGHT_GIT_HASH
    except Exception:
        return "n/a"

def getBuildInfoGitBranch() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_GIT_BRANCH
        return CYCLONEDDS_INSIGHT_GIT_BRANCH
    except Exception:
        return "n/a"

def getBuildPipelineId() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_BUILD_PIPELINE_ID
        return CYCLONEDDS_INSIGHT_BUILD_PIPELINE_ID
    except Exception:
        return "19"

def getBuildId() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_BUILD_ID
        return CYCLONEDDS_INSIGHT_BUILD_ID
    except Exception:
        return "0"

def getBuildInfoCycloneGitHash() -> str:
    try:
        from build_info import CYCLONEDDS_GIT_HASH
        return CYCLONEDDS_GIT_HASH
    except Exception:
        return "n/a"

def getBuildInfoCycloneGitHashShort() -> str:
    try:
        from build_info import CYCLONEDDS_GIT_HASH_SHORT
        return CYCLONEDDS_GIT_HASH_SHORT
    except Exception:
        return "n/a"

def getBuildInfoCyclonePythonGitHash() -> str:
    try:
        from build_info import CYCLONEDDS_PYTHON_GIT_HASH
        return CYCLONEDDS_PYTHON_GIT_HASH
    except Exception:
        return "n/a"

def getBuildInfoCyclonePythonGitHashShort() -> str:
    try:
        from build_info import CYCLONEDDS_PYTHON_GIT_HASH_SHORT
        return CYCLONEDDS_PYTHON_GIT_HASH_SHORT
    except Exception:
        return "n/a"


class QmlUtils(QObject):

    def __init__(self, parent=None):
        super().__init__(parent)

    @Slot(int)
    def setColorScheme(self, scheme):
        QApplication.styleHints().setColorScheme(Qt.ColorScheme(scheme))

def delete_folder(folder_path):
    dir = QDir(folder_path)
    if dir.exists():
        success = dir.removeRecursively()
        if success:
            logging.info(f"Successfully deleted folder: {folder_path}")
        else:
            logging.error(f"Failed to delete folder: {folder_path}")
    else:
        logging.error(f"Folder does not exist: {folder_path}")
