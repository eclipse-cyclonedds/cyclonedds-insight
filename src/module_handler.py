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

        self.idlcWorker: typing.Optional[IdlcWorkerThread] = None
        self.allTypes = {}
        self.topLevelTypes = {}
        self.structMembers = {}
        self.loaded_structs = {}
        self.app_data_dir = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
        self.datamodel_dir = os.path.join(self.app_data_dir, "datamodel")
        self.destination_folder_idl = os.path.join(self.datamodel_dir, "idl")
        self.destination_folder_py = os.path.join(self.datamodel_dir, "py")

    def count(self) -> int:
        return len(self.topLevelTypes.keys())

    def hasType(self, topicType: str) -> bool:
        return topicType in self.topLevelTypes

    def getType(self, topicTypeStr: str):
        module_type = importlib.import_module(self.topLevelTypes[topicTypeStr].parts[0])
        class_type = getattr(module_type, self.topLevelTypes[topicTypeStr].parts[1])
        return module_type, class_type

    def getName(self, index: int):
        if index < len(list(self.topLevelTypes.keys())):
            return str(list(self.topLevelTypes.keys())[index])
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
        self.topLevelTypes.clear()
        self.structMembers.clear()
        self.allTypes.clear()

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
                        sId: str = f"{module_name}::{cls.__name__}".replace(".", "::")
                        if sId not in self.topLevelTypes:
                            if not self.has_nested_annotation(cls) and not self.is_enum(cls):
                                    self.beginInsertModuleSignal.emit(self.count())
                                    self.topLevelTypes[sId] = DataModelItem(sId, [module_name, cls.__name__])
                                    
                                    self.endInsertModuleSignal.emit()
                            else:
                                pass

                        self.structMembers[sId] = self.get_struct_members(cls)
                        self.allTypes[sId] = cls

                    elif inspect.ismodule(cls):
                        self.import_module_and_nested(cls.__name__)
                except Exception as e:
                    logging.error(f"Error importing {module_name} : {type_name} : {e}")
        except Exception as e:
            logging.error(f"Error importing {module_name}: {e}")

        print("allTypes", self.allTypes)
        print("structMembers", self.structMembers)

    def has_nested_annotation(self, cls):
        return 'nested' in getattr(cls, '__idl_annotations__', {})

    def is_enum(self, cls):
        return hasattr(cls, "__idl_enum_default_value__")

    def print_class_attributes(self, cls):
        logging.debug(f"Attributes of class {cls.__name__}:")
        for attr_name in dir(cls):
            logging.debug(f"  {attr_name}: {getattr(cls, attr_name)}")

    def add_idl_without_module(self, module):
        classes = [getattr(module, name) for name in dir(module) if isinstance(getattr(module, name), type)]
        for cls in classes:
            sId: str = f"{module.__name__}::{cls.__name__}"
            if not self.has_nested_annotation(cls) and "(IdlStruct" in str(cls):
                
                if sId not in self.topLevelTypes:
                    self.beginInsertModuleSignal.emit(self.count())
                    self.topLevelTypes[sId] = DataModelItem(sId, [module.__name__, cls.__name__])
                    self.endInsertModuleSignal.emit()

            self.structMembers[sId] = self.get_struct_members(cls)
            self.allTypes[sId] = cls

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

    def getInitializedDataObj(self, topicType):
        """Returns an default initialized object of the given type"""

        if topicType.replace(".", "::") in self.structMembers:
            topicType = topicType.replace(".", "::")

        if topicType in self.allTypes:
            initList = []
            for k in self.structMembers[topicType].keys():
                currentTypeName = self.structMembers[topicType][k]
                print("----------->>>>>>>>>>>", currentTypeName)
                if self.isSequence(currentTypeName):
                    initList.append([])
                elif self.isInt(currentTypeName) or self.isEnum(currentTypeName):
                    initList.append(0)
                elif self.isFloat(currentTypeName):
                    initList.append(0.0)
                elif self.isStr(currentTypeName):
                    initList.append("")
                elif self.isBool(currentTypeName):
                    initList.append(False)
                elif self.isStruct(currentTypeName):
                    initList.append(self.getInitializedDataObj(currentTypeName))

            topic_type_dot: str = topicType.replace("::", ".")
            moduleNameToImport = topic_type_dot.split('.')[0]
            module = importlib.import_module(moduleNameToImport)
            for part in topic_type_dot.split('.')[1:]:
                module = getattr(module, part)
            print(module, initList)
            initializedObj = module(*initList)
            print("initializedObj----->>>>", initializedObj)
        else:
            if self.isInt(topicType) or self.isEnum(topicType):
                return 0
            elif self.isFloat(topicType):
                return 0.0
            elif self.isBool(topicType):
                return False
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
    
    def isEnum(self, theType):
        smiCol = str(theType).replace(".", "::")
        if smiCol in self.allTypes:
            return self.is_enum(self.allTypes[smiCol])
        return False

    def getEnumItemNames(self, theType):
        smiCol = str(theType).replace(".", "::")
        if smiCol in self.allTypes:
            return getattr(self.allTypes[smiCol], "_member_names_")
        return []

    def isStr(self, theType):
        return theType == str or str(theType).startswith("typing.Annotated[str") or theType == "str"
    
    def isBool(self, theType):
        print("isBool", theType)
        return theType == bool or str(theType).startswith("typing.Annotated[bool") or theType == "bool"

    def isSequence(self, theType):
        return str(theType).startswith("typing.Annotated[typing.Sequence")
    
    def isStruct(self, theType):
        return str(theType).replace(".", "::") in self.structMembers

    def isBasic(self, theType):
        return self.isInt(theType) or self.isFloat(theType) or self.isStr(theType) or self.isBool(theType)
    
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

                # bool
                elif self.isBool(self.structMembers[theType][keyStructMem]):
                    rootNode.appendChild(DataTreeNode(keyStructMem, tt, DataTreeModel.IsBoolRole, parent=rootNode))

                # enum
                elif self.isEnum(self.structMembers[theType][keyStructMem]):
                    node = DataTreeNode(keyStructMem, tt, DataTreeModel.IsEnumRole, parent=rootNode)
                    node.enumItemNames = self.getEnumItemNames(self.structMembers[theType][keyStructMem])
                    rootNode.appendChild(node)

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
                    logging.error(f"Unknown Datatype: {theType} {keyStructMem} {str(self.structMembers[theType][keyStructMem])}")

        elif self.isInt(theType):
            rootNode.appendChild(DataTreeNode("", theType, DataTreeModel.IsIntRole, parent=rootNode))
        elif self.isFloat(theType):
            rootNode.appendChild(DataTreeNode("", theType, DataTreeModel.IsFloatRole, parent=rootNode))
        elif self.isStr(theType):
            rootNode.appendChild(DataTreeNode("", theType, DataTreeModel.IsStrRole, parent=rootNode))
        elif self.isBool(theType):
            rootNode.appendChild(DataTreeNode("", theType, DataTreeModel.IsBoolRole, parent=rootNode))
        elif self.isEnum(theType):
            node = DataTreeNode("", theType, DataTreeModel.IsEnumRole, parent=rootNode)
            node.enumItemNames = self.getEnumItemNames(theType)
            rootNode.appendChild(node)

        return rootNode
