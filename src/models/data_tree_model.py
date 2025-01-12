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
import re
import copy
from PySide6.QtCore import Qt, QModelIndex, QAbstractItemModel, Qt
from PySide6.QtCore import Signal, Slot


class DataTreeNode:

    def __init__(self, name, typeName, role, parent=None):
        self.parentItem = parent
        self.childItems = list()
        self.itemName = name
        self.itemTypeName = typeName
        self.itemArrayTypeName = None
        self.itemValue = None
        self.role = role
        self.dataType = None
        self.enumItemNames = []
        self.maxElements = 0

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

    DisplayRole = Qt.UserRole + 1
    IsFloatRole = Qt.UserRole + 2
    IsIntRole = Qt.UserRole + 3
    IsStrRole = Qt.UserRole + 4
    IsSequenceRole = Qt.UserRole + 5
    IsStructRole = Qt.UserRole + 6
    IsEnumRole = Qt.UserRole + 7
    IsUnionRole = Qt.UserRole + 8
    IsSequenceElementRole = Qt.UserRole + 9
    TypeNameRole = Qt.UserRole + 10
    ValueRole = Qt.UserRole + 11
    DisplayHintRole = Qt.UserRole + 12
    IsBoolRole = Qt.UserRole + 13
    IsOptionalRole = Qt.UserRole + 14
    IsArrayRole = Qt.UserRole + 15
    IsArrayElementRole = Qt.UserRole + 16
    IsExpandable = Qt.UserRole + 17

    def __init__(self, rootItem: DataTreeNode, parent=None):
        super(DataTreeModel, self).__init__(parent)
        self.rootItem = rootItem

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
            elif item.role == self.IsSequenceElementRole or item.role == self.IsArrayElementRole:
                return ""
            else:
                return "value"
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
            else:
                return ""
        elif role == self.IsExpandable:
            if item.role == self.IsSequenceRole:
                return True if item.maxElements > item.childCount() else False
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
        }

    @Slot(QModelIndex, str)
    def setData(self, index, value):
        print("setData", index, value)
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

            attrs, parent = self.getDotPath(item)
            obj = parent.dataType
            for attr in attrs[:-1]:
                if attr.isdigit():
                    obj = obj[int(attr)]
                else:
                    obj = getattr(obj, attr)

            if obj is None or item.itemValue is None:
                print("WARNINGGGGGGGG !!!")
                return

            if isinstance(obj, list):
                obj[int(attrs[-1])] = item.itemValue
            else:
                setattr(obj, attrs[-1], item.itemValue)

    @Slot()
    def printTree(self):
        def printNode(node, indent=0):
            print(' ' * indent + str(node.itemName) + " " + str(node.itemValue), node.dataType, node.role)
            for child in node.childItems:
                printNode(child, indent + 2)

        printNode(self.rootItem)

    @Slot(QModelIndex, result=bool)
    def getIsEnum(self, index):
        if index.isValid():
            item: DataTreeNode= index.internalPointer()
            return item.role == self.IsEnumRole
        return False

    @Slot(QModelIndex, result=list)
    def getEnumModel(self, index):
        if index.isValid():
            item: DataTreeNode= index.internalPointer()
            return item.enumItemNames
        return []

    @Slot(QModelIndex, DataTreeNode)
    def addArrayItem(self, index: QModelIndex, node: DataTreeNode):
        logging.debug("Add array item")
        if index.isValid() and node.parentItem.maxElements > node.parentItem.childCount():
            item: DataTreeNode= index.internalPointer()
            self.beginInsertRows(index, item.childCount(), item.childCount())
            node.parentItem = item
            item.appendChild(node)

            seqenceObj = copy.deepcopy(node.parentItem.dataType)
            print("seqenceObj !!!", seqenceObj)
            print("childitems", node.childItems)
            attrs, parent = self.getDotPath(node.childItems[0])
            print("Add-array-item", attrs, parent)
            if attrs[-1].isdigit():
                attrs.append(None)
            obj = parent.dataType
            for attr in attrs[:-1]:
                if attr.isdigit():
                    if len(obj) <= int(attr):
                        obj.append(seqenceObj)
                    obj = obj[int(attr)]
                else:
                    obj = getattr(obj, attr)

            self.endInsertRows()

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

        print("attrs", attrs)

        return attrs, parent

    @Slot(QModelIndex)
    def removeArrayItem(self, index: QModelIndex):
        logging.debug("Remove array item")
        if index.isValid():
            item: DataTreeNode = index.internalPointer()
            parentX = item.parent()

            self.beginRemoveRows(self.index(parentX.row(), 0), item.row(), item.row())

            attrs, parent = self.getDotPath(item)            
            obj = parent.dataType
            for attr in attrs[:-1]:
                if attr.isdigit():
                    obj = obj[int(attr)]
                else:
                    obj = getattr(obj, attr)

            if attrs[-1].isdigit():
                del obj[int(attrs[-1])]

            parentX.childItems.remove(item)

            self.endRemoveRows()

    def getDataObj(self):
        return self.rootItem.dataType
