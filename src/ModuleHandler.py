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
from models.DataTreeModel import DataTreeModel, DataTreeNode


@dataclass
class DataModelItem:
    id: str
    parts: dict


class DataModelHandler(QObject):

    isLoadingSignal: Signal = Signal(bool)
    
    beginInsertModuleSignal: Signal = Signal(int)
    endInsertModuleSignal: Signal = Signal()

    def __init__(self, parent=typing.Optional[QObject]):
        super().__init__()

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

    def getInitializedDataObj(self, topicType):
        """Returns an default initialized object of the given type"""

        if topicType.replace(".", "::") in self.structMembers:
            topicType = topicType.replace(".", "::")

        if topicType in self.structMembers:
            initList = []
            for k in self.structMembers[topicType].keys():
                currentTypeName = self.structMembers[topicType][k]
                if self.isSequence(currentTypeName):
                    initList.append([])
                elif self.isInt(currentTypeName):
                    initList.append(0)
                elif self.isFloat(currentTypeName):
                    initList.append(0.0)
                elif self.isStr(currentTypeName):
                    initList.append("")
                elif self.isStruct(currentTypeName):
                    initList.append(self.getInitializedDataObj(currentTypeName))

            topic_type_dot: str = topicType.replace("::", ".")
            moduleNameToImport = topic_type_dot.split('.')[0]
            module = importlib.import_module(moduleNameToImport)
            for part in topic_type_dot.split('.')[1:]:
                module = getattr(module, part)
            print(module)
            initializedObj = module(*initList)
            print("thing----->>>>", initializedObj)
        else:
            if self.isInt(topicType):
                return 0
            elif self.isFloat(topicType):
                return 0.0
            elif self.isStr(topicType):
                return ""
            else:
                logging.warning(f"Unknown type: {topicType}")
                initializedObj = None

        return initializedObj

    def getRootNode(self, topic_type):
        rootNode = DataTreeNode("root", topic_type, DataTreeModel.IsStructRole)
        rootNode.dataType = self.getInitializedDataObj(topic_type)
        return self.toNode(topic_type, rootNode)

    def isInt(self, theType):
        return str(theType).startswith("typing.Annotated[int")

    def isFloat(self, theType):
        return str(theType).startswith("typing.Annotated[float")
    
    def isStr(self, theType):
        return theType == str or str(theType).startswith("typing.Annotated[str") or theType == "str"
    
    def isSequence(self, theType):
        return str(theType).startswith("typing.Annotated[typing.Sequence")
    
    def isStruct(self, theType):
        return str(theType).replace(".", "::") in self.structMembers

    def isBasic(self, theType):
        return self.isInt(theType) or self.isFloat(theType) or self.isStr(theType)
    
    def isPredefined(self, theType):
        return self.isBasic(theType) or self.isStruct(theType) or self.isSequence(theType)

    def toNode(self, theType: str, rootNode):
        print("xxx",theType, self.structMembers)

        if theType.replace(".", "::") in self.structMembers:
            theType = theType.replace(".", "::")

        if theType in self.structMembers:
            print("xxx",theType, self.structMembers[theType], str(type(self.structMembers[theType])))

            for keyStructMem in self.structMembers[theType].keys():

                tt = str(self.structMembers[theType][keyStructMem]).replace(".", "::")
    
                ano: typing.Annotated = self.structMembers[theType][keyStructMem]
                print("LOOOOKKKKK HEREEEEEE", typing.get_args(ano), typing.get_origin(ano))

                # string
                if self.isStr(self.structMembers[theType][keyStructMem]):
                    rootNode.appendChild(DataTreeNode(keyStructMem, tt, DataTreeModel.IsStrRole, parent=rootNode))

                # integer
                elif self.isInt(self.structMembers[theType][keyStructMem]):
                    rootNode.appendChild(DataTreeNode(keyStructMem, tt, DataTreeModel.IsIntRole, parent=rootNode))

                # float
                elif self.isFloat(self.structMembers[theType][keyStructMem]):
                    rootNode.appendChild(DataTreeNode(keyStructMem, tt, DataTreeModel.IsFloatRole, parent=rootNode))

                # sequence
                elif self.isSequence(self.structMembers[theType][keyStructMem]):
                    arrayRootNode = DataTreeNode(keyStructMem, tt,DataTreeModel.IsArrayRole, parent=rootNode)

                    inner = str(self.structMembers[theType][keyStructMem]).replace("typing.Annotated[typing.Sequence[",  "", 1)
                    inner = inner[:inner.rfind("], sequence[")]

                    # inner  = inner.replace(".", "::")
                    print("THE INNER:::::", inner)

                    if inner.startswith("ForwardRef('"):
                        inner = inner.replace("ForwardRef('", "")
                        inner = inner[:-2]

                    arrayRootNode.dataType = self.getInitializedDataObj(inner)
                    arrayRootNode.itemArrayTypeName = inner

                    rootNode.appendChild(arrayRootNode)

                # struct
                elif self.isStruct(self.structMembers[theType][keyStructMem]):
                    
                    subRootNode = DataTreeNode(keyStructMem, tt, DataTreeModel.IsStructRole, parent=rootNode)
                    subRootNode.dataType = self.getInitializedDataObj(str(self.structMembers[theType][keyStructMem]).replace(".", "::"))
                    self.toNode(str(self.structMembers[theType][keyStructMem]).replace(".", "::"), subRootNode)
                    rootNode.appendChild(subRootNode)

                # Unknown
                else:
                    logging.error(f"Unknown Datatype: {str(self.structMembers[theType][keyStructMem])}")

        elif self.isInt(theType):
            rootNode.appendChild(DataTreeNode("", theType, DataTreeModel.IsIntRole, parent=rootNode))
        elif self.isFloat(theType):
            rootNode.appendChild(DataTreeNode("", theType, DataTreeModel.IsFloatRole, parent=rootNode))
        elif self.isStr(theType):
            rootNode.appendChild(DataTreeNode("", theType, DataTreeModel.IsStrRole, parent=rootNode))

        return rootNode
