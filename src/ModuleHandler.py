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

import logging
import os
import sys
import importlib
from pathlib import Path
from PySide6.QtCore import Slot, QDir
from PySide6.QtCore import QThread, Signal, QStandardPaths
from PySide6.QtCore import QObject
import inspect
from utils import delete_folder
from dds_access.Idlc import IdlcWorkerThread
from dataclasses import dataclass
import typing


@dataclass
class DataModelItem:
    id: str
    parts: dict


class DataModelHandler(QObject):

    isLoadingSignal: Signal = Signal(bool)
    
    beginInsertModuleSignal: Signal = Signal(int)
    endInsertModuleSignal: Signal = Signal()

    def __init__(self, parent=typing.Optional[QObject]):
        super().__init__(parent)

        self.idlcWorker = None
        self.idlcWorker = None
        self.dataModelItems = {}
        self.structMembers = {}
        self.loaded_structs = {}
        self.app_data_dir = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
        self.datamodel_dir = os.path.join(self.app_data_dir, "datamodel")
        self.destination_folder_idl = os.path.join(self.datamodel_dir, "idl")
        self.destination_folder_py = os.path.join(self.datamodel_dir, "py")
        self.destination_folder_qtmodels = os.path.join(self.datamodel_dir, "qtmodels")

    def count(self) -> int:
        return len(self.dataModelItems.keys())

    def hasType(self, topicType: str) -> bool:
        return topicType in self.dataModelItems

    def getType(self, topicTypeStr: str):
        module_type = importlib.import_module(self.dataModelItems[topicTypeStr].parts[0])
        class_type = getattr(module_type, self.dataModelItems[topicTypeStr].parts[1])
        return module_type, class_type

    def getName(self, index: int):
        if index < len(list(self.dataModelItems.keys())):
            return str(list(self.dataModelItems.keys())[index])

        return None

    def addUrls(self, urls):
        if self.idlcWorker:
            return
        
        self.isLoadingSignal.emit(True)

        logging.info("add urls:" + str(urls))

        self.idlcWorker = IdlcWorkerThread(urls, self.destination_folder_py, self.destination_folder_idl)
        self.idlcWorker.doneSignale.connect(self.idlcWorkerDone)
        self.idlcWorker.start()

    @Slot()
    def idlcWorkerDone(self):
        self.loadModules()
        self.idlcWorker = None
        self.isLoadingSignal.emit(False)

    def clear(self):
        delete_folder(self.datamodel_dir)
        self.dataModelItems.clear()

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

        model_dir = QDir(self.destination_folder_qtmodels)
        if not model_dir.exists():
            QDir().mkdir(self.destination_folder_qtmodels)
        sys.path.insert(0, self.destination_folder_qtmodels)

        for struct in self.structMembers:
            undscore = struct.replace("::", "_")
            topic_type_dot: str = struct.replace("::", ".")

            pyStrucCode = "import " + topic_type_dot.split('.')[0] + "\n"
            pyStrucCode += "from PySide6.QtCore import QObject, Property, Slot, Signal\n"
            pyStrucCode += "from PySide6.QtQml import qmlRegisterType\n"
            pyStrucCode += "\n"
            pyStrucCode = self.toPyStructs(struct, pyStrucCode)
            with open(f"{self.destination_folder_qtmodels}/M{undscore}.py", "w") as structFile:
                structFile.write(pyStrucCode)

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
                                self.beginInsertModuleSignal.emit(self.count())
                                self.dataModelItems[sId] = DataModelItem(sId, [module_name, cls.__name__])
                                self.structMembers[sId] = self.get_struct_members(cls)
                                self.endInsertModuleSignal.emit()
                    elif inspect.ismodule(cls):
                        self.import_module_and_nested(cls.__name__)
                except Exception as e:
                    logging.error(f"Error importing {module_name} : {type_name} : {e}")
        except Exception as e:
            logging.error(f"Error importing {module_name}: {e}")


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
                    self.beginInsertModuleSignal.emit(self.count())
                    self.dataModelItems[sId] = DataModelItem(sId, [module.__name__, cls.__name__])
                    self.structMembers[sId] = self.get_struct_members(cls)
                    self.endInsertModuleSignal.emit()

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

    def toPyStructs(self, theType, code):
        print("CODE xxx",theType, self.structMembers)

        if theType in self.structMembers:
            print("xxx",theType, self.structMembers[theType])
            typeUnderscore = theType.replace("::", "_")
            typeDot = theType.replace("::", ".")
            code += f"class M{typeUnderscore}(QObject):\n"
            code += "    def __init__(self"
            for keyStructMem in self.structMembers[theType].keys():
                code += f", {keyStructMem} = None"
            code += "):\n"

            code += "        super().__init__()\n"
            for keyStructMem in self.structMembers[theType].keys():
                code += f"        self._{keyStructMem} = {keyStructMem}\n"

            for keyStructMem in self.structMembers[theType].keys():
                code += "\n"
                if self.structMembers[theType][keyStructMem] == str or str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[str"):
                    code += "    @Property(str)\n"
                elif str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[int"):
                    code += "    @Property(int)\n"
                elif str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[float"):
                    code += "    @Property(float)\n"
                elif str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[typing.Sequence"):
                    code += f"    @Property('QVariantList', notify={keyStructMem}Changed)\n"
                elif str(self.structMembers[theType][keyStructMem]).replace(".", "::") in self.structMembers:
                    code += f"    @Property(QObject, constant=False)\n"
                    pass
                else:
                    logging.warn("unkown type")

                code += f"    def {keyStructMem}(self):\n"
                code += f"        print(\"Getter called {keyStructMem}\")\n"
                code += f"        return self._{keyStructMem}\n\n"

                code += f"    @{keyStructMem}.setter\n"
                code += f"    def {keyStructMem}(self, value):\n"
                code += f"        print(\"SETTER CALLED {keyStructMem}\", value)\n"
                code += f"        self._{keyStructMem} = value\n\n"

            # Convert to DDS-Type
            code += f"    def toDdsObj(self):\n"
            code += f"        return {typeDot}("
            theFir = True
            for keyStructMem in self.structMembers[theType].keys():
                if theFir:
                    theFir = False
                else:
                    code += ", "

                if str(self.structMembers[theType][keyStructMem]).replace(".", "::") in self.structMembers:
                    code += f"{keyStructMem} = self._{keyStructMem}.toDdsObj()"
                    pass
                else:
                    code += f"{keyStructMem} = self._{keyStructMem}"

                #code += "\n"

            code += ")\n"

            code += f"\nqmlRegisterType(M{typeUnderscore}, \"org.eclipse.cyclonedds.insight\", 1, 0, \"M{typeUnderscore}\")"
            for keyStructMem in self.structMembers[theType].keys():
                if str(self.structMembers[theType][keyStructMem]).replace(".", "::") in self.structMembers:
                    theType_strcut = str(self.structMembers[theType][keyStructMem])
                    usc = theType_strcut.replace("::", "_").replace(".", "_")                    
                    #code += f"\nqmlRegisterType(M{usc}, \"org.eclipse.cyclonedds.insight\", 1, 0, \"M{usc}\")"
                    code = f"import M{usc}\n" + code

        return code

    def getCode(self, id, topic_type):
            

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

            usc = topic_type.replace("::", "_")
            qmlCode += "\n"
            qmlCode += "    M" + usc
            qmlCode += " {\n"
            qmlCode += f"        id: {usc}\n"
            qmlCode += "    }\n"

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
            pyCode += f"    @Slot(QObject)\n"
            pyCode += f"    def writeObj(self, value):\n"
            pyCode += f"        logging.debug(\"Write value: \" + str(type(value)))\n"
            pyCode += f"        self.writeDataSignal.emit(self.id, value.toDdsObj())\n\n"

            topic_type_underscore = topic_type.replace("::", "_")

            topic_type_dot: str = topic_type.replace("::", ".")

            pyCodeImport = set()
            pyCodeImport.add(topic_type_dot.split('.')[0])

            qmlCodeWrite = ""
            pyCodeInner = ""
            (qmlCode, qmlCodeWrite, pyCode, pyCodeInner) = self.toQml(topic_type, qmlCode, qmlCodeWrite, pyCode, pyCodeInner, pyCodeImport, "", 0)

            # Qml-Code
            qmlCode += "            Button {\n"
            qmlCode += "                text: qsTr(\"Write\")\n"
            qmlCode += "                onClicked: {\n"
            qmlCode += "                    console.log(\"write button pressed\")\n"

            assignments = ""
            assignments = self.getQmlAssignments(topic_type, assignments)
            qmlCode += assignments


            qmlCode += f"                    testerModel.writeObj(mId, {usc})\n"
            qmlCode += "                }\n"
            qmlCode += "            }\n"
            qmlCode += "        }\n"
            qmlCode += "    }\n"
            qmlCode += "}\n"

            imp_str = ""
            for imp in pyCodeImport:
                imp_str += f"import {imp}\n"
            pyCode = imp_str + pyCode


            logging.debug("Qml:")
            logging.debug(qmlCode)
            logging.debug("Py:")
            logging.debug(pyCode)

            return pyCode, qmlCode


    def getQmlAssignments(self, theType, code):
        print("ASSIGN xxx",theType, self.structMembers)

        if theType in self.structMembers:

            realType_underscore = theType.replace("::", "_")

            for keyStructMem in self.structMembers[theType].keys():
                code += "\n"
                if str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[typing.Sequence"):
                    pass
                elif str(self.structMembers[theType][keyStructMem]).replace(".", "::") in self.structMembers:
                    theType_strcut = str(self.structMembers[theType][keyStructMem])
                    usc = theType_strcut.replace("::", "_").replace(".", "_")

                    code = f"{realType_underscore}.{keyStructMem} = {usc}\n" + code
                    code = self.getQmlAssignments(str(self.structMembers[theType][keyStructMem]).replace(".", "::"), code)
                else:
                    logging.warning(f"unkown type keyStructMem: {str(keyStructMem)}")

        return code

    def toQml(self, theType: str, qmlCode, qmlCodeWrite, pyCode, pyCodeInner, pyCodeImport, prefix, padding):
        print("xxx",theType, self.structMembers)
        theTypeUnderSc = theType.replace("::", "_")
        if theType in self.structMembers:
            print("xxx",theType, self.structMembers[theType], str(type(self.structMembers[theType])))

            for keyStructMem in self.structMembers[theType].keys():
                qmlCode += "            Label {\n"
                qmlCode += "                text: " + "\"" + keyStructMem + "\"\n"
                qmlCode += f"                leftPadding: {str(padding)}\n"
                qmlCode += "            }\n"
                print(str(self.structMembers[theType][keyStructMem]))

                keyWithPrefix: str = prefix + keyStructMem
    
                ano: typing.Annotated = self.structMembers[theType][keyStructMem]
                print("LOOOOKKKKK HEREEEEEE", typing.get_args(ano), typing.get_origin(ano))

                # string
                if self.structMembers[theType][keyStructMem] == str or str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[str"):
                    qmlCode += "            TextField {\n"
                    qmlCode += f"                id: id{keyWithPrefix}\n"
                    qmlCode += f"                onTextChanged: {theTypeUnderSc}.{keyStructMem} = text\n"
                    qmlCode += "            }\n"

                # integer
                elif str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[int"):
                    qmlCode += "            TextField {\n"
                    qmlCode += f"                id: id{keyWithPrefix}\n"
                    qmlCode += f"                text: \"0\"\n"
                    qmlCode += f"                onTextChanged: {theTypeUnderSc}.{keyStructMem} = Math.floor(parseInt(text))\n"
                    qmlCode += "            }\n"

                elif str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[float"):
                    qmlCode += "            TextField {\n"
                    qmlCode += f"                id: id{keyWithPrefix}\n"
                    qmlCode += f"                text: \"0.0\"\n"
                    qmlCode += f"                onTextChanged: {theTypeUnderSc}.{keyStructMem} = parseFloat(text)\n"
                    qmlCode += "            }\n"

                elif str(self.structMembers[theType][keyStructMem]).startswith("typing.Annotated[typing.Sequence"):

                    print("YYYYYYYYYYY", keyStructMem, self.structMembers[theType][keyStructMem], str(type(self.structMembers[theType][keyStructMem])))

                    theType_strcut = str(self.structMembers[theType][keyStructMem])
                    usc = theType_strcut.replace("::", "_").replace(".", "_")

                    qmlCode += "ListModel {\n"
                    qmlCode += f"    id: {usc}\n"
                    qmlCode += "}\n"
                    qmlCode += "Row {\n"

                    qmlCode += "ListView {\n"
                    #qmlCode += "anchors.fill: parent\n"
                    qmlCode += "    width: 100\n"
                    qmlCode += "    height: 100\n"
                    qmlCode += f"    model: {usc}\n"
                    qmlCode += "    delegate: Item {\n"

                    inner = str(self.structMembers[theType][keyStructMem]).replace("typing.Annotated[typing.Sequence",  "", 1)



                    
                    # inner  = inner.replace(".", "::")
                    print("THE INNER:::::", inner)

                    (qmlCode, qmlCodeWrite, pyCode, pyCodeInner) = self.toQml(inner, qmlCode, qmlCodeWrite, pyCode, pyCodeInner, pyCodeImport, keyWithPrefix, padding + 10)

                    qmlCode += "    }\n"
                    qmlCode += "}\n"
                    qmlCode += "Button {\n"
                    qmlCode += "    text: \"+\"\n"
                    qmlCode += "}\n"
                    qmlCode += "Button {\n"
                    qmlCode += "    text: \"-\"\n"
                    qmlCode += "}\n"
                    qmlCode += "}\n"

                # struct
                elif str(self.structMembers[theType][keyStructMem]).replace(".", "::") in self.structMembers:

                    qmlCode += "            Item {}\n"
                    theType_strcut = str(self.structMembers[theType][keyStructMem])

                    usc = theType_strcut.replace("::", "_").replace(".", "_")
                    qmlCode += "\n            M" + usc
                    qmlCode += " {\n"
                    qmlCode += f"                id: {usc}\n"
                    qmlCode += "            }\n\n"

                    pyCodeImport.add(theType_strcut.split('.')[0])
                    (qmlCode, qmlCodeWrite, pyCode, pyCodeInner) = self.toQml(str(self.structMembers[theType][keyStructMem]).replace(".", "::"), qmlCode, qmlCodeWrite, pyCode, pyCodeInner, pyCodeImport, keyWithPrefix, padding + 10)

                # Unknown
                else:
                    qmlCode += "            Label {\n"
                    qmlCode += "                text: " + "\"Unknown Datatype\"\n"
                    qmlCode += "            }\n"

            return (qmlCode, qmlCodeWrite, pyCode, pyCodeInner)
