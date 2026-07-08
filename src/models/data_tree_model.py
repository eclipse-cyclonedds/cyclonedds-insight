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
import re
import copy
from PySide6.QtCore import Qt, QModelIndex, QAbstractItemModel, Qt
from PySide6.QtCore import Signal, Slot
import sys


class DataTreeNode:

    def __init__(self, name, typeName, role, parent=None):
        self.parentItem = parent
        self.childItems = list()
        self.itemName = name
        self.itemTypeName = typeName
        self.itemArrayTypeName = None
        self.itemArrayType = None
        self.itemValue = None
        self.role = role
        self.dataType = None
        self.enumItemNames = []
        self.maxElements = 0

    def __repr__(self):
        return f"Node(itemName={self.itemName}, itemTypeName={self.itemTypeName}, itemArrayTypeName={self.itemArrayTypeName}, itemArrayType={self.itemArrayType}, itemValue={self.itemValue}, role={self.role}, dataType={self.dataType}, enumItemNames={self.enumItemNames})"

    def appendChild(self, child):
        self.childItems.append(child)

    def child(self, row):
        return self.childItems[row]

    def arrayPosition(self, index: QModelIndex):
        if not index.isValid():
            return -1
        item = index.internalPointer()
        if item.parentItem and (item.parentItem.role == self.IsSequenceRole or item.parentItem.role == self.IsArrayRole):
            return item.parentItem.childItems.index(item)
        return -1

    def childCount(self):
        return len(self.childItems)

    def columnCount(self):
        return 1

    def data(self, column):
        return (self.itemName, self.itemValue, self.itemTypeName)

    def parent(self):
        return self.parentItem

    def row(self):
        if self.parentItem:
            if self in self.parentItem.childItems:
                return self.parentItem.childItems.index(self)
        return 0


class DataTreeModel(QAbstractItemModel):

    DisplayRole = Qt.UserRole + 1     # 257
    IsFloatRole = Qt.UserRole + 2     # 258
    IsIntRole = Qt.UserRole + 3       # 259
    IsStrRole = Qt.UserRole + 4       # 260
    IsSequenceRole = Qt.UserRole + 5  # 261
    IsStructRole = Qt.UserRole + 6    # 262
    IsEnumRole = Qt.UserRole + 7      # 263
    IsUnionRole = Qt.UserRole + 8     # 264
    IsSequenceElementRole = Qt.UserRole + 9 # 265
    TypeNameRole = Qt.UserRole + 10       # 266
    ValueRole = Qt.UserRole + 11          # 267
    DisplayHintRole = Qt.UserRole + 12    # 268
    IsBoolRole = Qt.UserRole + 13         # 269
    IsOptionalRole = Qt.UserRole + 14     # 270
    IsArrayRole = Qt.UserRole + 15        # 271
    IsArrayElementRole = Qt.UserRole + 16 # 272
    IsExpandable = Qt.UserRole + 17       # 273
    IsOptionalElementRole = Qt.UserRole + 18 # 274

    def __init__(self, rootItem: DataTreeNode, parent=None):
        super(DataTreeModel, self).__init__(parent)
        self.rootItem = rootItem

    def get_role_name_by_number(self, role_number):
        # Manuelle Zuordnung der Rollen
        if role_number == self.DisplayRole:
            return "DisplayRole"
        elif role_number == self.IsFloatRole:
            return "IsFloatRole"
        elif role_number == self.IsIntRole:
            return "IsIntRole"
        elif role_number == self.IsStrRole:
            return "IsStrRole"
        elif role_number == self.IsSequenceRole:
            return "IsSequenceRole"
        elif role_number == self.IsStructRole:
            return "IsStructRole"
        elif role_number == self.IsEnumRole:
            return "IsEnumRole"
        elif role_number == self.IsUnionRole:
            return "IsUnionRole"
        elif role_number == self.IsSequenceElementRole:
            return "IsSequenceElementRole"
        elif role_number == self.TypeNameRole:
            return "TypeNameRole"
        elif role_number == self.ValueRole:
            return "ValueRole"
        elif role_number == self.DisplayHintRole:
            return "DisplayHintRole"
        elif role_number == self.IsBoolRole:
            return "IsBoolRole"
        elif role_number == self.IsOptionalRole:
            return "IsOptionalRole"
        elif role_number == self.IsArrayRole:
            return "IsArrayRole"
        elif role_number == self.IsArrayElementRole:
            return "IsArrayElementRole"
        elif role_number == self.IsExpandable:
            return "IsExpandable"
        elif role_number == self.IsOptionalElementRole:
            return "IsOptionalElementRole"
        else:
            return "Unknown Role"

    def index(self, row, column, parent=QModelIndex()):
        if not self.hasIndex(row, column, parent):
            return QModelIndex()
        parentItem = parent.internalPointer() if parent.isValid() else self.rootItem
        childItem = parentItem.child(row)
        if childItem:
            return self.createIndex(row, column, childItem)
        else:
            return QModelIndex()

    def parent(self, index):
        if not index.isValid():
            return QModelIndex()
        childItem = index.internalPointer()
        parentItem = childItem.parent()
        if parentItem == self.rootItem:
            return QModelIndex()
        return self.createIndex(parentItem.row(), 0, parentItem)

    def rowCount(self, parent=QModelIndex()):
        if parent.column() > 0:
            return 0
        if not parent.isValid():
            parentItem = self.rootItem
        else:
            parentItem = parent.internalPointer()
        return parentItem.childCount()

    def columnCount(self, parent=QModelIndex()):
        return 1  # Only one column for a simple tree

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None

        item = index.internalPointer()

        if role == self.DisplayRole:
            if item.itemName:
                return item.itemName
            elif item.role == self.IsSequenceElementRole or item.role == self.IsArrayElementRole or item.role == self.IsOptionalElementRole:
                return ""
            else:
                return "__value__"
        elif role == self.TypeNameRole:
            return item.itemTypeName
        elif role == self.IsFloatRole:
            return item.role == self.IsFloatRole
        elif role == self.IsIntRole:
            return item.role == self.IsIntRole
        elif role == self.IsStrRole:
            return item.role == self.IsStrRole
        elif role == self.IsBoolRole:
            return item.role == self.IsBoolRole
        elif role == self.IsSequenceRole:
            return item.role == self.IsSequenceRole
        elif role == self.IsArrayRole:
            return item.role == self.IsArrayRole
        elif role == self.IsStructRole:
            return item.role == self.IsStructRole
        elif role == self.IsOptionalRole:
            return item.role == self.IsOptionalRole
        elif role == self.IsEnumRole:
            return item.role == self.IsEnumRole
        elif role == self.IsUnionRole:
            return item.role == self.IsUnionRole
        elif role == self.IsSequenceElementRole:
            return item.role == self.IsSequenceElementRole
        elif role == self.IsArrayElementRole:
            return item.role == self.IsArrayElementRole
        elif role == self.IsOptionalElementRole:
            return item.role == self.IsOptionalElementRole
        elif role == self.ValueRole:
            if item.itemValue is not None:
                return str(item.itemValue)
            elif item.role == self.IsIntRole:
                return "0"
            elif item.role == self.IsFloatRole:
                return "0.0"
            elif item.role == self.IsStrRole:
                return ""
            elif item.role == self.IsEnumRole:
                return 0
        elif role == self.DisplayHintRole:
            if item.role == self.IsSequenceElementRole or item.role == self.IsArrayElementRole:
                return f"[{item.parentItem.childItems.index(item)}]"
            elif item.role == self.IsOptionalElementRole:
                return "[optional]"
            else:
                return ""
        elif role == self.IsExpandable:

            if item.role == self.IsSequenceElementRole:
                if item.childCount() == 0:
                    return True

            if item.maxElements:
                if item.role == self.IsSequenceRole or item.role == self.IsOptionalRole:
                    return True if item.maxElements > item.childCount() else False
            elif item.role == self.IsSequenceRole:
                return True

            return False
        return None

    def roleNames(self):
        return {
            self.DisplayRole: b'display',
            self.IsFloatRole: b'is_float',
            self.IsIntRole: b'is_int',
            self.IsStrRole: b'is_str',
            self.IsSequenceRole: b'is_sequence',
            self.IsStructRole: b'is_struct',
            self.IsEnumRole: b'is_enum',
            self.IsUnionRole: b'is_union',
            self.IsSequenceElementRole: b'is_sequence_element',
            self.TypeNameRole: b'type_name',
            self.ValueRole: b'value',
            self.DisplayHintRole: b'display_hint',
            self.IsBoolRole: b'is_bool',
            self.IsArrayRole: b'is_array',
            self.IsOptionalRole: b'is_optional',
            self.IsArrayElementRole: b'is_array_element',
            self.IsExpandable: b'is_expandable',
            self.IsOptionalElementRole: b'is_optional_element',
        }

    @Slot(QModelIndex, str)
    def setData(self, index, value):
        # print("setData", index, value)
        if index.isValid():
            item = index.internalPointer()
            if item.role == self.IsFloatRole:
                try:
                    item.itemValue = float(value)
                except:
                    item.itemValue = 0.0
            elif item.role == self.IsIntRole or item.role == self.IsEnumRole:
                try:
                    item.itemValue = int(value)
                except:
                    item.itemValue = 0
            elif item.role == self.IsBoolRole:
                item.itemValue = True if value == "true" else False
            elif item.role == self.IsStrRole:
                item.itemValue = str(value)
            elif item.role == self.IsSequenceRole:
                return
            elif item.role == self.IsArrayRole:
                return
            elif item.role == self.IsStructRole:
                return
            
        self.syncDataType(item)

    def syncDataType(self, item):

            attrs, parent = self.getDotPath(item)
            obj = parent.dataType
            for attr in attrs[:-1]:
                if attr.isdigit():
                    obj = obj[int(attr)]
                else:
                    obj = getattr(obj, attr)

            if obj is None or item.itemValue is None:
                logging.warning("Warning cannot set value")
                return

            if isinstance(obj, list):
                obj[int(attrs[-1])] = item.itemValue
            else:
                setattr(obj, attrs[-1], item.itemValue)

    @Slot()
    def printTree(self):
        def printNode(node, indent=0):
            print(' ' * indent + str(node) + " " + self.get_role_name_by_number(node.role))
            for child in node.childItems:
                printNode(child, indent + 2)

        printNode(self.rootItem)

    def toJson(self):
        def default_value_for_node(node):
            if node.itemValue is not None:
                return node.itemValue
            if node.role == self.IsIntRole or node.role == self.IsEnumRole:
                return 0
            elif node.role == self.IsFloatRole:
                return 0.0
            elif node.role == self.IsStrRole:
                return ""
            elif node.role == self.IsBoolRole:
                return False
            elif node.role in [self.IsSequenceRole, self.IsArrayRole, self.IsOptionalRole]:
                return []
            elif node.role == self.IsStructRole or node.childCount() > 0:
                return {}
            else:
                logging.error(f"Unknown role in default_value_for_node: {node.role}")
                return "__default__"

        def nodeToDict(node):
            name = node.itemName if node.itemName else "__value__"

            # Sequence / array
            if node.role in [self.IsSequenceRole, self.IsArrayRole, self.IsOptionalRole]:
                result = []
                for child in node.childItems:
                    child_dict = nodeToDict(child)
                    key = child.itemName if child.itemName else "__value__"
                    value = child_dict[key]
                    result.append({key: value})
                return {name: result if result else []}

            # Leaf node
            elif node.childCount() == 0:
                return {name: default_value_for_node(node)}

            # Struct / object node
            else:
                child_dict = {}
                for child in node.childItems:
                    child_dict.update(nodeToDict(child))
                return {name: child_dict if child_dict else default_value_for_node(node)}

        return nodeToDict(self.rootItem)

    def fromJson(self, jsonDict, dataModelHandler):

        def updateNode(node: DataTreeNode, value, dataModelHandler):
            if isinstance(value, dict):
                if "__value__" in value:
                    value = value["__value__"]

                for child in node.childItems:
                    key = child.itemName
                    if not key:
                        key = "__value__"
                    if key in value:
                        updateNode(child, value[key], dataModelHandler)

            elif isinstance(value, list):
                for idx, item_val in enumerate(value):
                    if node.itemArrayTypeName:
                        targetRole = DataTreeModel.IsSequenceElementRole
                        if node.role == DataTreeModel.IsOptionalRole:
                            targetRole = DataTreeModel.IsOptionalElementRole
                        itemNode = dataModelHandler.toNode(node.itemArrayTypeName, DataTreeNode("", "", targetRole, parent=node))

                        currentTreeIndex = self.createIndex(node.row(), 0, node)
                        self.addArrayItem(currentTreeIndex, itemNode)
                    elif node.parentItem.itemArrayTypeName:
                        itemNode = dataModelHandler.toNode(node.parentItem.itemArrayTypeName, DataTreeNode("", "", DataTreeModel.IsSequenceElementRole, parent=node))
                        itemNode.itemArrayTypeName = node.parentItem.itemArrayTypeName
                        currentTreeIndex = self.createIndex(node.row(), 0, node)
                        self.addArrayItem(currentTreeIndex, itemNode)
                    
                    if idx < node.childCount():
                        updateNode(node.childItems[idx], item_val, dataModelHandler)
            else:
                node.itemValue = value
                self.syncDataType(node)

        self.beginResetModel()
        updateNode(self.rootItem, jsonDict, dataModelHandler)
        self.endResetModel()

    @Slot(QModelIndex, result=bool)
    def getIsEnum(self, index):
        if index.isValid():
            item: DataTreeNode= index.internalPointer()
            return item.role == self.IsEnumRole
        return False

    @Slot(QModelIndex, result=int)
    def getEnumValue(self, index):
        if index.isValid():
            item: DataTreeNode= index.internalPointer()
            if item.itemValue:
                return item.itemValue
        return 0

    @Slot(QModelIndex, result=str)
    def getStrValue(self, index):
        if index.isValid():
            item: DataTreeNode= index.internalPointer()
            if item.itemValue:
                return item.itemValue
        return ""

    @Slot(QModelIndex, result=list)
    def getEnumModel(self, index):
        if index.isValid():
            item: DataTreeNode= index.internalPointer()
            return item.enumItemNames
        return []

    @Slot(QModelIndex, DataTreeNode)
    def addArrayItem(self, index: QModelIndex, node: DataTreeNode):
        logging.debug("Add array item " + str(node.parentItem.maxElements) + " " + str(node.parentItem.childCount()) + " "+  str(node.parentItem.role) + " " + str(DataTreeModel.DisplayRole))
        
        insertAllowed = True
        if node.parentItem.maxElements:
            insertAllowed = node.parentItem.maxElements > node.parentItem.childCount()

        if index.isValid() and insertAllowed:
            item: DataTreeNode= index.internalPointer()
            self.beginInsertRows(index, item.childCount(), item.childCount())
            node.parentItem = item
            item.appendChild(node)
            seqenceObj = copy.deepcopy(node.parentItem.dataType)
            if node.parentItem.role == DataTreeModel.IsOptionalRole:
                attrs, parent = self.getDotPath(node)
            else:
                if len(node.childItems) > 0:
                    attrs, parent = self.getDotPath(node.childItems[0])
                else:
                    attrs, parent = self.getDotPath(node)

            if attrs[-1].isdigit():
                attrs.append(None)

            obj = parent.dataType

            for attr in attrs[:-1]:
                if attr.isdigit():
                    if len(obj) <= int(attr):
                        obj.append(seqenceObj)
                    obj = obj[int(attr)]
                else:
                    objT = getattr(obj, attr)
                    if objT is not None:
                        obj = objT

            if node.parentItem.role == DataTreeModel.IsOptionalRole:
                setattr(obj, attrs[-1], seqenceObj)

            self.endInsertRows()

            self.dataChanged.emit(index, index, [DataTreeModel.IsExpandable])
        else:
            logging.warning("Failed to insert array item")

    def getDotPath(self, item):
        dotName = item.itemName
        parent = item.parentItem
        count = 0

        def findArrayPosition(itemX, count):
            path = ""
            countScope = 0
            while itemX is not None and itemX.parentItem is not None:
                if itemX.parentItem.role == self.IsSequenceRole or itemX.parentItem.role == self.IsArrayRole:
                    countScope += 1
                    if count == countScope:
                        pos = itemX.parentItem.childItems.index(itemX)
                        path = f"[{pos}]" + path
                itemX = itemX.parentItem
            return path

        while parent is not None:
            if parent.parentItem is not None:
                if parent.role == self.IsSequenceRole or parent.role == self.IsArrayRole:
                    count += 1
                    array_position = findArrayPosition(item, count)
                    dotName = parent.itemName + array_position + "." + dotName
                elif parent.role == self.IsSequenceElementRole or parent.role == self.IsArrayElementRole:
                    pass
                else:
                    dotName = parent.itemName + "." + dotName
            else:
                break

            parent = parent.parentItem

        attrs = re.split(r'\.|\[|\]', dotName)
        attrs = [attr for attr in attrs if attr]

        return attrs, parent

    @Slot(QModelIndex)
    def removeArrayItem(self, index: QModelIndex):
        logging.debug("Remove array item")
        if index.isValid():
            item: DataTreeNode = index.internalPointer()
            parentX = item.parent()
            row = item.row()
            parentIndex = self.parent(index)

            attrs, parent = self.getDotPath(item)
            obj = parent.dataType
            for attr in attrs[:-1]:
                if attr.isdigit():
                    obj = obj[int(attr)]
                else:
                    obj = getattr(obj, attr)

            self.beginRemoveRows(parentIndex, row, row)

            if attrs[-1].isdigit():
                del obj[int(attrs[-1])]

            if item.parentItem.role == DataTreeModel.IsOptionalRole:
                setattr(obj, attrs[-1], None)

            del parentX.childItems[row]

            self.endRemoveRows()

            if parentX.childCount() > row:
                firstChanged = self.index(row, 0, parentIndex)
                lastChanged = self.index(parentX.childCount() - 1, 0, parentIndex)
                self.dataChanged.emit(firstChanged, lastChanged, [
                    DataTreeModel.DisplayHintRole,
                    DataTreeModel.IsExpandable
                ])

            if parentIndex.isValid():
                self.dataChanged.emit(parentIndex, parentIndex, [DataTreeModel.IsExpandable])

    def getDataObj(self):
        return self.rootItem.dataType
