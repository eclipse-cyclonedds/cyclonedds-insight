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

from PySide6.QtCore import Qt, QModelIndex, QAbstractListModel, Qt, QByteArray, QStandardPaths, QFile, QDir, QProcess, QThread
from PySide6.QtCore import QObject, Signal, Slot
import logging
import os
import sys
import typing
import importlib
import types
import inspect
from pathlib import Path
import subprocess
import uuid
import glob
from dataclasses import dataclass
import typing
from dds_service import WorkerThread
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration


@dataclass
class DataModelItem:
    id: str
    parts: dict


class DatamodelModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    newDataArrived = Signal(str)
    isLoadingSignal = Signal(bool)

    newWriterSignal = Signal(str, int, str, str, str, str)

    def __init__(self, threads, parent=typing.Optional[QObject]) -> None:
        super().__init__()
        self.idlcWorker = None
        self.dataModelItems = {}
        self.structMembers = {}
        self.loaded_structs = {}
        self.threads = threads
        self.app_data_dir = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
        self.datamodel_dir = os.path.join(self.app_data_dir, "datamodel")
        self.destination_folder_idl = os.path.join(self.datamodel_dir, "idl")
        self.destination_folder_py = os.path.join(self.datamodel_dir, "py")

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> typing.Any:
        if not index.isValid():
            return None
        row = index.row()
        if role == self.NameRole:
            return str(list(self.dataModelItems.keys())[row])
        elif False:
            pass

        return None

    def roleNames(self) -> typing.Dict[int, QByteArray]:
        return {
            self.NameRole: b'name'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return len(self.dataModelItems.keys())

    @Slot(list)
    def addUrls(self, urls):
        if self.idlcWorker:
            return

        logging.info("add urls:" + str(urls))

        self.isLoadingSignal.emit(True)

        self.idlcWorker = IdlcWorkerThread(urls, self.destination_folder_py, self.destination_folder_idl)
        self.idlcWorker.doneSignale.connect(self.idlcWorkerDone)
        self.idlcWorker.start()

    @Slot()
    def idlcWorkerDone(self):
        self.loadModules()
        self.idlcWorker = None
        self.isLoadingSignal.emit(False)

    @Slot()
    def clear(self):
        self.beginResetModel()
        self.delete_folder(self.datamodel_dir)
        self.dataModelItems.clear()
        self.endResetModel()

    def delete_folder(self, folder_path):
        dir = QDir(folder_path)
        if dir.exists():
            success = dir.removeRecursively()
            if success:
                logging.info(f"Successfully deleted folder: {folder_path}")
            else:
                logging.error(f"Failed to delete folder: {folder_path}")
        else:
            logging.error(f"Folder does not exist: {folder_path}")

    @Slot()
    def loadModules(self):
        logging.debug("")

        dir = QDir(self.destination_folder_py)
        if not dir.exists():
            return

        parent_dir = self.destination_folder_py
        sys.path.insert(0, parent_dir)

        # Structs without any module, can only appear on root level
        py_files = [f for f in os.listdir(parent_dir) if f.endswith('.py')]
        for py_file in py_files:            
            module_name = Path(py_file).stem
            try:
                module = importlib.import_module(module_name)
                self.add_idl_without_module(module)
            except Exception as e:
                logging.error(f"Error importing {module_name}")

        submodules = [name for name in os.listdir(parent_dir) if os.path.isdir(os.path.join(parent_dir, name))]
        for submodule in submodules:
            self.import_module_and_nested(submodule)

        print("self.structMembers", self.structMembers)

    def import_module_and_nested(self, module_name):
        try:
            module = importlib.import_module(module_name)
            all_types = getattr(module, '__all__', [])
            for type_name in all_types:
                try:
                    cls = getattr(module, type_name)
                    if inspect.isclass(cls):
                        if not self.has_nested_annotation(cls) and not self.is_enum(cls):
                            sId: str = f"{module_name}::{cls.__name__}".replace(".", "::")
                            if sId not in self.dataModelItems:
                                self.beginInsertRows(QModelIndex(), self.rowCount(), self.rowCount())
                                self.dataModelItems[sId] = DataModelItem(sId, [module_name, cls.__name__])
                                self.structMembers[sId] = self.get_struct_members(cls)
                                self.endInsertRows()
                    elif inspect.ismodule(cls):
                        self.import_module_and_nested(cls.__name__)
                except Exception as e:
                    logging.error(f"Error importing {module_name} : {type_name} : {e}")
        except Exception as e:
            logging.error(f"Error importing {module_name}: {e}")

    def get_struct_membersX(self, cls):
        return {name: type_ for name, type_ in cls.__annotations__.items()}

    def get_struct_members(self, cls):
        members = {}
        for name, type_ in cls.__annotations__.items():
            if inspect.isclass(type_) and type_ in self.loaded_structs:
                members[name] = type_
                self.structMembers[f"{type_.__module__}::{type_.__name__}".replace(".", "::")] = self.get_struct_members(type_)
            else:
                members[name] = type_
        return members

    def has_nested_annotation(self, cls):
        return 'nested' in getattr(cls, '__idl_annotations__', {})

    def is_enum(self, cls):
        return getattr(cls, '__doc__', None) == "An enumeration."

    def print_class_attributes(self, cls):
        logging.debug(f"Attributes of class {cls.__name__}:")
        for attr_name in dir(cls):
            logging.debug(f"  {attr_name}: {getattr(cls, attr_name)}")

    def add_idl_without_module(self, module):
        classes = [getattr(module, name) for name in dir(module) if isinstance(getattr(module, name), type)]
        for cls in classes:
            if not self.has_nested_annotation(cls) and "(IdlStruct" in str(cls):
                sId: str = f"{module.__name__}::{cls.__name__}"
                if sId not in self.dataModelItems:
                    self.beginInsertRows(QModelIndex(), self.rowCount(), self.rowCount())
                    self.dataModelItems[sId] = DataModelItem(sId, [module.__name__, cls.__name__])
                    self.structMembers[sId] = self.get_struct_members(cls)
                    self.endInsertRows()

    @Slot(int, str, str, str, str, str, int)
    def addEndpoint(self, domain_id, topic_name, topic_type, q_own, q_dur, q_rel, entityType):
        logging.debug(f"try add endpoint {str(domain_id)} {str(topic_name)} {str(topic_type)} {str(q_own)} {str(q_dur)} {str(q_rel)} {str(entityType)}")

        id = "m" + str(uuid.uuid4()).replace("-", "_")

        if topic_type in self.dataModelItems:
            module_type = importlib.import_module(self.dataModelItems[topic_type].parts[0])
            class_type = getattr(module_type, self.dataModelItems[topic_type].parts[1])

            logging.debug(str(module_type))
            logging.debug(str(class_type))

            qos = Qos()

            if q_own == "DDS_OWNERSHIP_SHARED":
                qos += Qos(Policy.Ownership.Shared)
            elif q_own == "DDS_OWNERSHIP_EXCLUSIVE":
                qos += Qos(Policy.Ownership.Exclusive)

            if q_dur == "DDS_DURABILITY_VOLATILE":
                qos += Qos(Policy.Durability.Volatile)
            elif q_dur == "DDS_DURABILITY_TRANSIENT_LOCAL":
                qos += Qos(Policy.Durability.TransientLocal)
            elif q_dur == "DDS_DURABILITY_TRANSIENT":
                qos += Qos(Policy.Durability.Transient)
            elif q_dur == "DDS_DURABILITY_PERSISTENT":
                qos += Qos(Policy.Durability.Persistent)

            if q_rel == "DDS_RELIABILITY_BEST_EFFORT":
                qos += Qos(Policy.Reliability.BestEffort)
            elif q_rel == "DDS_RELIABILITY_RELIABLE":
                qos += Qos(Policy.Reliability.Reliable(max_blocking_time=duration(seconds=1)))

            if domain_id not in self.threads:
                self.threads[domain_id] = WorkerThread(domain_id)
                self.threads[domain_id].onData.connect(self.onData, Qt.ConnectionType.QueuedConnection)
                self.threads[domain_id].start()


            if not self.threads[domain_id].addEndpoint(id, topic_name, class_type, qos, entityType):
                return

        if entityType == 4:
            qmlCode = """
import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import org.eclipse.cyclonedds.insight

Rectangle {
    id: settingsViewId
    anchors.fill: parent
    color: rootWindow.isDarkMode ? "black" : "white"
"""
            qmlCode += f"    property string mId: \"{id}\"\n"
            qmlCode += """
    ScrollView {
        anchors.fill: parent

        GridLayout {
            columns: 2
            anchors.fill: parent
            anchors.margins: 10
            rowSpacing: 10
            columnSpacing: 10

"""
            qmlCode += "            Label {\n"
            qmlCode += "                text: " + "\"" + topic_type + "\"\n"
            qmlCode += "                font.bold: true\n"
            qmlCode += "            }\n"
            qmlCode += "            Item {}\n"

            pyCode: str = """
import logging
from PySide6.QtCore import QObject, Signal, Slot

class DataWriterModel(QObject):

    writeDataSignal = Signal(object, object)

    def __init__(self, id):
        super().__init__()
        logging.debug(f"Construct DataWriterModel {id}")
        self.id = id
"""
            pyCode += f"    @Slot(object, object, object, object, object)\n"
            topic_type_underscore = topic_type.replace("::", "_")
            pyCode += f"    def write(self\n"

            pyCodeInner = f"        logging.debug(\"Write {topic_type_underscore} ...\")\n"
            topic_type_dot: str = topic_type.replace("::", ".")
            pyCodeInner += f"        data = {topic_type_dot}(\n"

            pyCodeImport = set()
            pyCodeImport.add(topic_type_dot.split('.')[0])

            qmlCodeWrite = ""

            (qmlCode, qmlCodeWrite, pyCode, pyCodeInner) = self.toQml(topic_type, qmlCode, qmlCodeWrite, pyCode, pyCodeInner, pyCodeImport, "")

            # Qml-Code
            qmlCode += "            Button {\n"
            qmlCode += "                text: qsTr(\"Write\")\n"
            qmlCode += "                onClicked: {\n"
            qmlCode += "                    console.log(\"write button pressed\")\n"
            qmlCode += f"                    var params = [{qmlCodeWrite}]\n"
            qmlCode += "                    testerModel.write(mId, params)\n"
            qmlCode += "                }\n"
            qmlCode += "            }\n"
            qmlCode += "        }\n    }\n}"

            imp_str = ""
            for imp in pyCodeImport:
                imp_str += f"import {imp}\n"
            pyCode = imp_str + pyCode
            pyCode += "            ):\n"

            pyCodeInner += "        )\n"
            pyCodeInner += "        print(data)\n"
            pyCodeInner += "        self.writeDataSignal.emit(self.id, data)\n"
            pyCodeInner += f"        logging.debug(\"Write {topic_type_underscore} ... DONE\")\n"
            pyCode += pyCodeInner

            logging.debug("Qml:")
            logging.debug(qmlCode)
            logging.debug("Py:")
            logging.debug(pyCode)

            self.newWriterSignal.emit(id, domain_id, topic_name, topic_type, qmlCode, pyCode)

            # Example usage
            # module_name = 'mymodule'
            # new_module = types.ModuleType(module_name)
            # exec(pyCode, new_module.__dict__)
            # mt = new_module.DataWriterModel(topic_name)
            # mt.writeDataSignal.connect(self.threads[domain_id].write, Qt.ConnectionType.QueuedConnection)
            # mt.write_vehicles_Vehicle("A cool string", 42, 43, "franz1", 1, 0.123456789, 0.2, 'x')

        logging.debug("try add endpoint ... DONE")

    def toQml(self, theType, qmlCode, qmlCodeWrite, pyCode, pyCodeInner, pyCodeImport, prefix):
        print("xxx",theType, self.structMembers)
        if theType in self.structMembers:
            print("xxx",theType, self.structMembers[theType])
            isFirst = True
            for keyStructMem in self.structMembers[theType].keys():
                qmlCode += "            Label {\n"
                qmlCode += "                text: " + "\"" + keyStructMem + "\"\n"
                qmlCode += "            }\n"
                print(str(self.structMembers[theType][keyStructMem]))

                keyWithPrefix: str = prefix + keyStructMem
    
                # string
                if self.structMembers[theType][keyStructMem] == str or str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[str"):
                    qmlCode += "            TextField {\n"
                    qmlCode += f"                id: id{keyWithPrefix}\n"
                    qmlCode += "            }\n"

                    pyCode += f"            , {keyWithPrefix}: str\n"

                    pyCodeInner += f"            "
                    if not isFirst:
                        pyCodeInner += ", "
                        qmlCodeWrite += ", "
                    pyCodeInner += f"{keyStructMem} = {keyWithPrefix}\n"
                    isFirst = False

                    qmlCodeWrite += f"id{keyWithPrefix}.text"

                # integer
                elif str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[int"):
                    qmlCode += "            TextField {\n"
                    qmlCode += f"                id: id{keyWithPrefix}\n"
                    qmlCode += f"                text: \"0\"\n"
                    qmlCode += "            }\n"

                    pyCode += f"            , {keyWithPrefix}: int\n"

                    pyCodeInner += f"            "
                    if not isFirst:
                        pyCodeInner += ", "
                        qmlCodeWrite += ", "
                    pyCodeInner += f"{keyStructMem} = {keyWithPrefix}\n"
                    isFirst = False

                    qmlCodeWrite += f"Math.floor(parseInt(id{keyWithPrefix}.text))"

                elif str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[float"):
                    qmlCode += "            TextField {\n"
                    qmlCode += f"                id: id{keyWithPrefix}\n"
                    qmlCode += f"                text: \"0.0\"\n"
                    qmlCode += "            }\n"

                    pyCode += f"            , {keyWithPrefix}: float\n"

                    pyCodeInner += f"            "
                    if not isFirst:
                        pyCodeInner += ", "
                        qmlCodeWrite += ", "
                    pyCodeInner += f"{keyStructMem} = {keyWithPrefix}\n"
                    isFirst = False

                    qmlCodeWrite += f"parseFloat(id{keyWithPrefix}.text)"

                elif str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[typing.Sequence"):
                    qmlCode += "            Label {\n"
                    qmlCode += "                text: " + "\"Listtype TBD\"\n"
                    qmlCode += "            }\n"

                    pyCode += f"            , {keyWithPrefix}: []\n"# TODO: for array probally a model is needed, or only qml model!

                    pyCodeInner += f"            "
                    if not isFirst:
                        pyCodeInner += ", "
                        qmlCodeWrite += ", "
                    pyCodeInner += f"{keyStructMem} = {keyWithPrefix}\n"
                    isFirst = False

                    qmlCodeWrite += f"id{keyWithPrefix}.text"

                # struct
                elif str(self.structMembers[theType][keyStructMem]).replace(".", "::") in self.structMembers:

                    if not isFirst:
                        qmlCodeWrite += ", "
                    isFirst = False

                    qmlCode += "            Item {}\n"
                    theType_strcut = str(self.structMembers[theType][keyStructMem])
                    pyCodeInner += f"                , {keyStructMem} = {theType_strcut}(\n"
                    pyCodeImport.add(theType_strcut.split('.')[0])
                    (qmlCode, qmlCodeWrite, pyCode, pyCodeInner) = self.toQml(str(self.structMembers[theType][keyStructMem]).replace(".", "::"), qmlCode, qmlCodeWrite, pyCode, pyCodeInner, pyCodeImport, keyWithPrefix)
                    pyCodeInner += f"            )\n"



                # Unknown
                else:
                    qmlCode += "            Label {\n"
                    qmlCode += "                text: " + "\"Unknown Datatype\"\n"
                    qmlCode += "            }\n"

                    pyCode += f"            , {keyWithPrefix}\n"

                    pyCodeInner += f"            "
                    if not isFirst:
                        pyCodeInner += ", "
                        qmlCodeWrite += ", "
                    pyCodeInner += f"{keyStructMem} = {keyWithPrefix}\n"
                    isFirst = False

                    qmlCodeWrite += "0"

            return (qmlCode, qmlCodeWrite, pyCode, pyCodeInner)

    @Slot(str)
    def onData(self, data: str):
        self.newDataArrived.emit(data)

    @Slot()
    def deleteAllReaders(self):
        for key in list(self.threads.keys()):
            self.threads[key].deleteAllReaders()

    @Slot()
    def shutdownEndpoints(self):
        for key in list(self.threads.keys()):
            self.threads[key].stop()
            self.threads[key].wait()
        self.threads.clear()

class IdlcWorkerThread(QThread):

    doneSignale = Signal()
    
    def __init__(self, urls, destination_folder_py, destination_folder_idl, parent=None):
        super().__init__(parent)
        self.urls = urls
        self.destination_folder_idl = destination_folder_idl
        self.destination_folder_py = destination_folder_py

    def run(self):
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
                    logging.error("Failed to copy file.")
                    break

        parent_dir = self.destination_folder_idl
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
                    logging.critical("No _idlpy lib found")
            else:
                arguments.append("py")
                # Started as python program
                #   - use idlc from cyclonedds_home
                #   - use _idlpy from pip package
                if "CYCLONEDDS_HOME" in os.environ:
                    application_path = os.environ["CYCLONEDDS_HOME"] + "/bin"

            arguments.append("-o")
            arguments.append(os.path.normpath(self.destination_folder_py))
            arguments.append(os.path.normpath(destination_file))

            command = os.path.normpath(f"{application_path}/idlc")

            logging.info("Execute: " + command + " " + " ".join(arguments))

            process = QProcess()
            process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
            process.setWorkingDirectory(self.destination_folder_py)
            process.start(command, arguments)

            if process.waitForFinished():
                if process.exitStatus() == QProcess.NormalExit:
                    logging.debug(str(process.readAll()))
                    logging.debug("Process finished successfully.") 
                else:
                    logging.debug("Process failed with error code: " + str(process.exitCode()))
            else:
                logging.debug("Failed to start process:" + str(process.errorString()))

        self.doneSignale.emit()
