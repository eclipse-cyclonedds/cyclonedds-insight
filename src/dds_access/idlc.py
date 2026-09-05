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
import os
import sys
from PySide6.QtCore import QDir
from PySide6.QtCore import QThread, Signal, QFile, QProcess
import glob


class IdlcWorkerThread(QThread):

    doneSignale = Signal(bool, str)
    
    def __init__(self, urls, destination_folder_py, destination_folder_idl, parent=None):
        super().__init__(parent)
        self.urls = urls
        self.destination_folder_idl = destination_folder_idl
        self.destination_folder_py = destination_folder_py

    def run(self):
        logging.info("Start idlc ...")
        errors = []
        for url in self.urls:
            logging.debug("Copy " + str(url) + " ...")
            if url.isLocalFile():
                # Copy idl source file
                source_file = url.toLocalFile()
                logging.debug("IDL-Folder: " + self.destination_folder_idl)
                if not QDir(self.destination_folder_idl).exists():
                    QDir().mkpath(self.destination_folder_idl)

                destination_file = os.path.join(self.destination_folder_idl, os.path.basename(source_file))

                if (QFile.exists(destination_file)):
                    QFile.remove(destination_file)

                if QFile.copy(source_file, destination_file):
                    logging.debug("File copied successfully. " + os.path.basename(source_file))
                else:
                    errors.append(f"Could not copy '{os.path.basename(source_file)}' into the application data folder.")
            else:
                errors.append(f"Only local IDL files can be imported: {url.toString()}")

        parent_dir = self.destination_folder_idl
        if not os.path.isdir(parent_dir):
            message = "No IDL files could be prepared for import."
            logging.error(message)
            self.doneSignale.emit(False, message)
            return
        idls = [name for name in os.listdir(parent_dir) if os.path.isfile(os.path.join(parent_dir, name))]

        for idl in idls:
            logging.debug("Process " + idl + " ...")

            destination_file = os.path.join(self.destination_folder_idl, idl)

            # Compile idl to py file
            if not QDir(self.destination_folder_py).exists():
                QDir().mkpath(self.destination_folder_py)

            arguments = ["-l"]
            application_path = "./"

            if getattr(sys, 'frozen', False):
                # Bundled as App - use idlc and _idlpy from app binaries
                application_path = sys._MEIPASS
                search_pattern = os.path.join(application_path, "_idlpy.*")
                matching_files = glob.glob(search_pattern)
                matching_files.sort()
                if matching_files:
                    arguments.append(os.path.normpath(matching_files[0]))
                    logging.debug("Found _idlpy: " + matching_files[0])
                else:
                    errors.append("The IDL Python generator library (_idlpy) was not found.")
                    continue
            else:
                arguments.append("py")
                # Started as python program
                #   - use idlc from cyclonedds_home
                #   - use _idlpy from pip package
                if "CYCLONEDDS_HOME" in os.environ:
                    application_path = os.environ["CYCLONEDDS_HOME"] + "/bin"

            arguments.append("-o")
            arguments.append(os.path.normpath(self.destination_folder_py))
            arguments.append("-I")
            arguments.append(os.path.normpath(self.destination_folder_idl))
            arguments.append("-f")
            arguments.append("case-sensitive")
            arguments.append(os.path.normpath(destination_file))

            command = os.path.normpath(f"{application_path}/idlc")

            logging.debug("Execute: " + command + " " + " ".join(arguments))

            process = QProcess()
            process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
            process.setWorkingDirectory(self.destination_folder_py)
            process.start(command, arguments)

            if process.waitForFinished():
                output = bytes(process.readAll()).decode(errors="replace").strip()
                if process.exitStatus() == QProcess.NormalExit and process.exitCode() == 0:
                    logging.debug(output)
                    logging.debug("Process finished successfully.") 
                else:
                    detail = output or f"idlc exited with code {process.exitCode()}"
                    errors.append(f"Failed to compile '{idl}': {detail}")
            else:
                errors.append(f"Failed to run idlc for '{idl}': {process.errorString()}")

        logging.info("idlc done.")
        if errors:
            message = "\n\n".join(errors)
            logging.error(message)
            self.doneSignale.emit(False, message)
        else:
            self.doneSignale.emit(True, "")
