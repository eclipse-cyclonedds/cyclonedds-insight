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
from dds_access.idlc import IdlcWorkerThread
from dataclasses import dataclass
import typing
from models.data_tree_model import DataTreeModel, DataTreeNode
import cyclonedds
import re

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
        self.app_data_dir: str = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
        self.datamodel_dir: str = os.path.join(self.app_data_dir, "datamodel")
        self.destination_folder_idl: str = os.path.join(self.datamodel_dir, "idl")
        self.destination_folder_py: str = os.path.join(self.datamodel_dir, "py")

        self.allTypes = {}
        self.topLevelTypes = {}
        self.structMembers = {}
        self.loaded_structs = {}
        self.customTypes = {}

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
        self.loaded_structs.clear()
        self.allTypes.clear()
        self.customTypes.clear()

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

       # print("self.structMembers", self.structMembers)

    def addTypeFromNetwork(self, typeName, dataType):
        print()
        self.structMembers[typeName] = self.get_struct_members(dataType)
        self.allTypes[typeName] = dataType
        import json
        print("allTypes", json.dumps(self.allTypes, indent=2, default=str))
        print("customTypes", json.dumps(self.customTypes, indent=2, default=str))
        print("structMembers", json.dumps(self.structMembers, indent=2, default=str))

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

                        if not self.is_enum(cls):
                            self.structMembers[sId] = self.get_struct_members(cls)
                        self.allTypes[sId] = cls

                    elif inspect.ismodule(cls):
                        self.import_module_and_nested(cls.__name__)
                    else:
                        if hasattr(cls, "__metadata__"):
                            if len(cls.__metadata__) > 0:

                                # Check for typedefs
                                if isinstance(cls.__metadata__[0], cyclonedds.idl.types.typedef):
                                    sId: str = cls.__metadata__[0].name.replace(".", "::")
                                    self.customTypes[sId] = cls.__metadata__[0].subtype


                except Exception as e:
                    logging.error(f"Error importing {module_name} : {type_name} : {e}")
        except Exception as e:
            logging.error(f"Error importing {module_name}: {e}")

        #print("allTypes", self.allTypes)
        #print("structMembers", self.structMembers)
        #print("allTypeDefs", self.customTypes)
        #print("DONE")
        import json
        print("allTypes", json.dumps(self.allTypes, indent=2, default=str))
        print("customTypes", json.dumps(self.customTypes, indent=2, default=str))
        print("structMembers", json.dumps(self.structMembers, indent=2, default=str))

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

            if not self.is_enum(cls):
                self.structMembers[sId] = self.get_struct_members(cls)
            self.allTypes[sId] = cls

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

        print("getInitializedDataObj", type(topicType), topicType, str(topicType))

        #print(isinstance(topicType, int), isinstance(topicType, cyclonedds.idl.types.int32))

        if topicType.replace(".", "::") in self.structMembers or topicType.replace(".", "::") in self.allTypes or topicType.replace(".", "::") in self.customTypes:
            topicType = topicType.replace(".", "::")
        
        if topicType in self.customTypes:
            topicType = self.resolveCustomType(topicType)
            topicType = str(topicType).replace(".", "::")

        if topicType in self.allTypes:
            initList = []
            for k in self.structMembers[topicType].keys():
                currentTypeName = self.structMembers[topicType][k]
                print("----------->>>>>>>>>>>", currentTypeName)
                realType = self.getRealType(currentTypeName)
                print("xxxxxxxxREAL.", realType)
                if self.isArray(realType):
                    arrayDefaultValues = []
                    metaType = self.getMetaDataType(realType)
                    innerType = metaType.subtype
                    if hasattr(innerType, "__idl_typename__"):
                        inner = innerType.__idl_typename__
                    else:
                        inner = str(innerType)
                    arrayLength = metaType.length
                    for _ in range(arrayLength):
                        arrayDefaultValues.append(self.getInitializedDataObj(str(inner)))
                    initList.append(arrayDefaultValues)
                elif self.isSequence(realType):
                    initList.append([])
                elif self.isInt(realType) or self.isEnum(realType):
                    initList.append(0)
                elif self.isFloat(realType):
                    initList.append(0.0)
                elif self.isStr(realType):
                    initList.append("")
                elif self.isBool(realType):
                    initList.append(False)
                elif self.isUnion(realType):
                    initList.append(None)
                elif self.isStruct(realType):
                    initList.append(self.getInitializedDataObj(realType))
                elif self.isOptional(realType):
                    initList.append(None)                    

            #try:
            #    topic_type_dot: str = topicType.replace("::", ".")
            #    moduleNameToImport = topic_type_dot.split('.')[0]
            #    module = importlib.import_module(moduleNameToImport)
            #    for part in topic_type_dot.split('.')[1:]:
            #        module = getattr(module, part)
            #    print(module, initList)
            #    initializedObj = module(*initList)
            #    print("initializedObj----->>>>", initializedObj)

            module = self.allTypes[topicType]
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
            elif self.isUnion(topicType):
                return None
            elif self.isSequence(topicType):
                return []
            else:
                logging.warning(f"Unknown type: {topicType}")
                initializedObj = None

        return initializedObj

    def getRootNode(self, topic_type):
        rootNode = DataTreeNode("root", topic_type, DataTreeModel.IsStructRole)
        rootNode.dataType = self.getInitializedDataObj(topic_type)
        return self.toNode(topic_type, rootNode)

    def isInt(self, theType):
        args = typing.get_args(theType)
        intLikeNames = ["byte", "int8", "uint8", "int16", "uint16", "int32", "uint32", "int64", "uint64"]
        if len(args) > 1:
            if args[1] in intLikeNames:
                return True

        return str(theType).replace("::", ".").startswith("typing.Annotated[int") or str(theType) in intLikeNames

    def isFloat(self, theType):
        args = typing.get_args(theType)
        floatLikeNames = ["float32", "float64", "float128"]
        if len(args) > 1:
            if args[1] in floatLikeNames:
                return True

        return str(theType).replace("::", ".").startswith("typing.Annotated[float") or str(theType) in floatLikeNames

    def isEnum(self, theType):
        smiCol = str(theType).replace(".", "::")
        if smiCol in self.allTypes:
            ret = self.is_enum(self.allTypes[smiCol])
            rel = self.getRealType(self.allTypes[smiCol])
            return ret

        args = typing.get_args(theType)
        if len(args) > 0:
            if hasattr(args[0], "__args__"):
                if len(args[0].__args__) > 0:
                    forwRef = args[0].__args__[0]
                    if isinstance(forwRef, typing.ForwardRef):
                        realType = self.getRealType(forwRef.__forward_arg__)
                        if forwRef.__forward_arg__ == "IdlEnum":
                            return True
                        else:
                            re = self.isEnum(realType)
                            return re
        return False

    def isUnion(self, theType):
        if isinstance(theType, cyclonedds.idl.types.case):
            logging.warning("Unions are currently not supported.")
            return True
        return False

    def isOptional(self, theType):
        if hasattr(theType, "__origin__"):
            if theType.__origin__ is typing.Union:
                return True
        return False

    def getOptionalType(self, theType):
        if hasattr(theType, "__args__"):
            if len(theType.__args__) > 0:
                optType = theType.__args__[0]
                if hasattr(optType, "__forward_arg__"):
                    return self.getRealType(optType.__forward_arg__)
                else:
                    return optType
        return None

    def getEnumItemNames(self, theType):
        print("ENUM-ITEMS", theType, type(theType))
        smiCol = str(theType).replace(".", "::")
        if smiCol in self.allTypes:
            return getattr(self.allTypes[smiCol], "_member_names_")

        if hasattr(theType, "__dict__"):
            print("d", theType.__dict__)
        if hasattr(theType, "__args__"):
            print("a", theType.__args__)

        return []

    def isChar(self, theType):
        args = typing.get_args(theType)
        if len(args) > 1:
            if args[1] in ["char", "wchar"]:
                return True
        return False

    def isStr(self, theType):
        # self.isChar(theType)
        return theType == str or str(theType).replace("::", ".").startswith("typing.Annotated[str") or theType == "str" or theType == "<class 'str'>"

    def isBool(self, theType):
        return theType == bool or str(theType).startswith("typing.Annotated[bool") or theType == "bool" or theType == "<class 'bool'>"

    def isArray(self, theType):
        smiCol = str(theType).replace(".", "::")
        if smiCol in self.customTypes:
            cls = self.customTypes[smiCol]
            if hasattr(cls, "__metadata__"):
                if len(cls.__metadata__) > 0:
                    _type = cls.__metadata__[0]
                    if isinstance(_type, cyclonedds.idl.types.array):
                        return True
        elif hasattr(theType, "__metadata__"):
            if len(theType.__metadata__) > 0:
                _type = theType.__metadata__[0]
                if isinstance(_type, cyclonedds.idl.types.array):
                    return True

        elif isinstance(theType, cyclonedds.idl.types.array):
            return True

        return False

    def getMetaDataType(self, theType):
        if hasattr(theType, "__metadata__"):
            if len(theType.__metadata__) > 0:
                _type = theType.__metadata__[0]
                print("theType:", type(theType), type(_type), theType.__metadata__[0])
                return _type
        return None

    def isSequence(self, theType):
        smiCol = str(theType).replace(".", "::")
        if smiCol in self.customTypes:
            cls = self.customTypes[smiCol]
            if hasattr(cls, "__metadata__"):
                if len(cls.__metadata__) > 0:
                    _type = cls.__metadata__[0]
                    if isinstance(_type, cyclonedds.idl.types.sequence):
                        return True
        elif hasattr(theType, "__metadata__"):
            if len(theType.__metadata__) > 0:
                _type = theType.__metadata__[0]
                print("theType:", type(theType), type(_type))
                if isinstance(_type, cyclonedds.idl.types.sequence):
                    return True
                
        elif isinstance(theType, cyclonedds.idl.types.sequence):
            return True

        if isinstance(theType, str):
            if theType.replace("::", ".").startswith("typing.Annotated[typing.Sequence"):
                return True
            if theType.startswith("sequence["):
                return True

        return False

    def isStruct(self, theType):
        return str(theType).replace(".", "::") in self.structMembers

    def isBasic(self, theType):
        return self.isInt(theType) or self.isFloat(theType) or self.isStr(theType) or self.isBool(theType)

    def isPredefined(self, theType):
        return self.isBasic(theType) or self.isStruct(theType) or self.isSequence(theType) or self.isArray(theType)

    def convert_to_cpp_style(self, attr_string):
        parts = [part for part in attr_string.split('.') if not part.startswith('_')]
        return '::'.join(parts)

    def toNode(self, theType: str, rootNode):
        logging.debug("toNode " + str(theType) + " " + str(type(theType)))

        if theType.replace(".", "::") in self.structMembers:
            theType = theType.replace(".", "::")

        theType = self.convert_to_cpp_style(theType)

        if theType in self.structMembers:
            print("xxx",theType, self.structMembers[theType], str(type(self.structMembers[theType])))

            for keyStructMem in self.structMembers[theType].keys():

                tt = str(self.structMembers[theType][keyStructMem]).replace(".", "::")
                realType = self.getRealType(self.structMembers[theType][keyStructMem])

                # string
                if self.isStr(realType):
                    rootNode.appendChild(DataTreeNode(keyStructMem, tt, DataTreeModel.IsStrRole, parent=rootNode))

                # integer
                elif self.isInt(realType):
                    rootNode.appendChild(DataTreeNode(keyStructMem, tt, DataTreeModel.IsIntRole, parent=rootNode))

                # float
                elif self.isFloat(realType):
                    rootNode.appendChild(DataTreeNode(keyStructMem, tt, DataTreeModel.IsFloatRole, parent=rootNode))

                # bool
                elif self.isBool(realType):
                    rootNode.appendChild(DataTreeNode(keyStructMem, tt, DataTreeModel.IsBoolRole, parent=rootNode))

                # union
                elif self.isUnion(realType):
                    node = DataTreeNode(keyStructMem, tt, DataTreeModel.IsUnionRole, parent=rootNode)
                    rootNode.appendChild(node)

                elif self.isArray(realType):
                    arrayRootNode = DataTreeNode(keyStructMem, tt,DataTreeModel.IsArrayRole, parent=rootNode)
                    metaType = self.getMetaDataType(realType)
                    innerType = metaType.subtype
                    print("ARRAYYYYY", innerType)
                    if hasattr(innerType, "__idl_typename__"):
                        inner = innerType.__idl_typename__
                    else:
                        inner = innerType
                    arrayLength = metaType.length

                    print("ARRAYYYYY", inner)

                    arrayRootNode.dataType = self.getInitializedDataObj(str(inner))
                    arrayRootNode.itemArrayTypeName = str(inner)

                    for _ in range(arrayLength):
                        print("FILL ARRAY", arrayRootNode.itemArrayTypeName)
                        # TODO: add real datatypes to root node with the dds obj
                        arrElem = DataTreeNode("", "", DataTreeModel.IsArrayElementRole, parent=arrayRootNode)
                        itemNode = self.toNode(arrayRootNode.itemArrayTypeName, arrElem)
                        arrayRootNode.appendChild(itemNode)

                    rootNode.appendChild(arrayRootNode)

                # sequence
                elif self.isSequence(realType):
                    seqRootNode = DataTreeNode(keyStructMem, tt,DataTreeModel.IsSequenceRole, parent=rootNode)

                    metaType = self.getMetaDataType(realType)

                    innerType = metaType.subtype
                    print("seq-dict", str(innerType), innerType)
                    if hasattr(innerType, "__idl_typename__"):
                        inner = innerType.__idl_typename__
                    else:
                        inner = innerType
                    seqRootNode.maxElements = metaType.max_length

                    inner = self.getRealType(inner)

                    print("INNER:::::::", inner, seqRootNode.maxElements, self.isSequence(inner), type(inner))  

                    if hasattr(inner, "__dict__"):
                        print(inner.__dict__)

                    seqRootNode.dataType = self.getInitializedDataObj(str(inner))
                    seqRootNode.itemArrayTypeName = str(inner)
                    seqRootNode.itemArrayType = inner

                    print("INNER DATA TYPE:", seqRootNode.dataType, type(seqRootNode.dataType))

                    rootNode.appendChild(seqRootNode)

                elif self.isOptional(realType):
                    optionalNode = DataTreeNode(keyStructMem, tt, DataTreeModel.IsOptionalRole, parent=rootNode)
                    optionalNode.maxElements = 1
                    optType = self.getOptionalType(realType)
                    inner = str(optType).replace(".", "::")
                    print("INNOPTIONAL", inner)
                    optionalNode.dataType = self.getInitializedDataObj(inner)
                    print("HERE:", optionalNode.dataType)
                    optionalNode.itemArrayTypeName = inner
                    rootNode.appendChild(optionalNode)

                # enum
                elif self.isEnum(realType):
                    node = DataTreeNode(keyStructMem, tt, DataTreeModel.IsEnumRole, parent=rootNode)
                    node.enumItemNames = self.getEnumItemNames(realType)
                    print("OTHER ITEMS:", node.enumItemNames)
                    rootNode.appendChild(node)

                # struct
                elif self.isStruct(realType):
                    subRootNode = DataTreeNode(keyStructMem, tt, DataTreeModel.IsStructRole, parent=rootNode)
                    subRootNode.dataType = self.getInitializedDataObj(str(realType).replace(".", "::"))
                    self.toNode(str(realType).replace(".", "::"), subRootNode)
                    rootNode.appendChild(subRootNode)

                # Unknown
                else:
                    logging.error(f"Unknown Datatype: {theType} {keyStructMem} {str(realType)}")
        else:
            theType = self.resolveCustomType(str(theType))
            if self.isInt(theType):
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
            elif self.isUnion(theType):
                node = DataTreeNode("", theType, DataTreeModel.IsUnionRole, parent=rootNode)
                rootNode.appendChild(node)

            elif self.isSequence(theType):
                seqRootNode = DataTreeNode("", theType, DataTreeModel.IsSequenceRole, parent=rootNode)

                inner = theType.replace("::", ".")
                if inner.startswith("typing.Annotated[typing.Sequence["):
                    inner = inner.replace("typing.Annotated[typing.Sequence[", "", 1)
                else:
                    inner = inner.replace("sequence[", "", 1)

                inner = inner[:-1]

                regex = r"ForwardRef\('([^']+)'\)"
                match = re.search(regex, inner)
                if match:
                    inner = match.group(1)
                    inner = inner.replace(".", "::")
                    inner = self.resolveCustomType(inner)

                seqRootNode.dataType = self.getInitializedDataObj(str(inner))
                seqRootNode.itemArrayTypeName = str(inner)
                seqRootNode.itemArrayType = inner

                rootNode.appendChild(seqRootNode)

            # struct
            elif self.isStruct(theType):
                subRootNode = DataTreeNode("", theType, DataTreeModel.IsStructRole, parent=rootNode)
                subRootNode.dataType = self.getInitializedDataObj(str(theType).replace(".", "::"))
                self.toNode(str(theType).replace(".", "::"), subRootNode)
                rootNode.appendChild(subRootNode)

            else:
                logging.error(f"Unknown Datatype: {theType}")

        return rootNode

    def resolveCustomType(self, typeName):
        if typeName in self.customTypes:
            return self.resolveCustomType(self.getRealType(self.customTypes[typeName]))
        else:
            return typeName

    def getRealType(self, inType):
        print("GETREALTYPE:", type(inType), inType)

        outType = inType

        if isinstance(inType, str):
            print("is-str")
            inTypeSemi = inType.replace(".", "::")
            if inTypeSemi in self.customTypes:
                print("yearh its in", inTypeSemi, self.customTypes[inTypeSemi])
                outType = self.getRealType(self.customTypes[inTypeSemi])

        elif hasattr(inType, "__metadata__"):
            print("hash-metadata")
            if len(inType.__metadata__) > 0:
                metaType = inType.__metadata__[0]
                if isinstance(metaType, cyclonedds.idl.types.typedef):
                    outType = self.getRealType(metaType)

        print("OUT:", outType, type(outType))
        return outType
