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
from loguru import logger as logging
import os
import sys


class LoggerConfig(QObject):

    logMessage = Signal(str)
    logLevelChanged = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.logLevel = "INFO"

    @Slot(str)
    def setGlobalLogLevel(self, level: str):
        self.setupLogger(level)

    def _qml_sink(self, message):
        self.logMessage.emit(str(message).rstrip('\n'))

    def setupLogger(self, log_level: str):

        log_levels = ["TRACE", "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if log_level not in log_levels:
            print("Unknown log level: ", log_level, "continue with INFO")
            log_level = "INFO"

        log_level = log_level.upper()

        app_data_dir = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
        if not app_data_dir:
            print("Failed to locate basic app folders")
            exit(-1)

        log_dir = os.path.join(app_data_dir, "logs")
        if not QDir(log_dir).exists():
            QDir().mkpath(log_dir)

        log_file = os.path.join(log_dir, "cyclonedds_insight.log")

        logging.remove()

        log_format = (
                "{time:YYYY-MM-DD HH:mm:ss,SSS} "
                "[<level>{level}</level>] "
                "[{file.name}:{line}] "
                "{message}"
        )

        logging.add(log_file, rotation="5 MB", retention=7, level=log_level, format=log_format)
        logging.add(sys.stderr, level=log_level, format=log_format, colorize=True)
        logging.add(self._qml_sink, level=log_level, format=log_format)

        logging.level("TRACE", color="<dim>")
        logging.level("DEBUG", color="<blue>")
        logging.level("INFO", color="<green>")
        logging.level("WARNING", color="<yellow><bold>")
        logging.level("ERROR", color="<red>")
        logging.level("CRITICAL", color="<RED><bold>")

        self.logLevel = log_level
        self.logLevelChanged.emit(log_level)

    def qt_message_handler(self, mode, context, message):
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

    @Slot()
    def requestCurrentLogLevel(self):
        self.logLevelChanged.emit(self.logLevel)
