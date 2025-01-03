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

    def appendChild(self, child):
        self.childItems.append(child)

    def child(self, row):
        return self.childItems[row]

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
            return self.parentItem.childItems.index(self)
        return 0


class DataTreeModel(QAbstractItemModel):

    DisplayRole = Qt.UserRole + 1
    IsFloatRole = Qt.UserRole + 2
    IsIntRole = Qt.UserRole + 3
    IsStrRole = Qt.UserRole + 4
    IsArrayRole = Qt.UserRole + 5
    IsStructRole = Qt.UserRole + 6
    IsEnumRole = Qt.UserRole + 7
    IsUnionRole = Qt.UserRole + 8
    IsArrayElementRole = Qt.UserRole + 9
    TypeNameRole = Qt.UserRole + 10

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
            return item.itemName
        elif role == self.TypeNameRole:
            return item.itemTypeName
        elif role == self.IsFloatRole:
            return item.role == self.IsFloatRole
        elif role == self.IsIntRole:
            return item.role == self.IsIntRole
        elif role == self.IsStrRole:
            return item.role == self.IsStrRole
        elif role == self.IsArrayRole:
            return item.role == self.IsArrayRole
        elif role == self.IsStructRole:
            return item.role == self.IsStructRole
        elif role == self.IsEnumRole:
            return item.role == self.IsEnumRole
        elif role == self.IsUnionRole:
            return item.role == self.IsUnionRole
        elif role == self.IsArrayElementRole:
            return item.role == self.IsArrayElementRole

        return None

    def roleNames(self):
        return {
            self.DisplayRole: b'display',
            self.IsFloatRole: b'is_float',
            self.IsIntRole: b'is_int',
            self.IsStrRole: b'is_str',
            self.IsArrayRole: b'is_array',
            self.IsStructRole: b'is_struct',
            self.IsEnumRole: b'is_enum',
            self.IsUnionRole: b'is_union',
            self.IsArrayElementRole: b'is_array_element',
            self.TypeNameRole: b'type_name'
        }

    @Slot(QModelIndex, str)
    def setData(self, index, value):
        if index.isValid():
            item = index.internalPointer()
            if item.role == self.IsFloatRole:
                try:
                    item.itemValue = float(value)
                except:
                    item.itemValue = 0.0
            elif item.role == self.IsIntRole:
                try:
                    item.itemValue = int(value)
                except:
                    item.itemValue = 0
            elif item.role == self.IsStrRole:
                item.itemValue = value

            dotName = item.itemName
            parent = item.parentItem
            while parent is not None:
                if parent.parentItem is not None:
                    #if parent.role != self.IsArrayElementRole:
                    dotName = parent.itemName + "." + dotName
                    parent = parent.parentItem
                else:
                    break

            print("dotName", dotName)
            attrs = dotName.split('.')
            obj = parent.dataType
            for attr in attrs[:-1]:
                obj = getattr(obj, attr)

            print("set data", obj, attrs[-1], item.itemValue,attrs)
            setattr(obj, attrs[-1], item.itemValue)

    @Slot()
    def printTree(self):
        def printNode(node, indent=0):
            print(' ' * indent + str(node.itemName) + " " + str(node.itemValue), node.dataType)
            for child in node.childItems:
                printNode(child, indent + 2)

        printNode(self.rootItem)

    @Slot(QModelIndex, DataTreeNode)
    def addArrayItem(self, index: QModelIndex, node: DataTreeNode):
        logging.debug("Add array item")
        if index.isValid():
            item: DataTreeNode= index.internalPointer()
            self.beginInsertRows(index, item.childCount(), item.childCount())
            node.parentItem = item
            # node.itemName = str(item.childCount()) # TODO: Find solution to show array index



            item.appendChild(node)
            self.endInsertRows()

    @Slot(QModelIndex)
    def removeArrayItem(self, index: QModelIndex):
        logging.debug("Remove array item")
        if index.isValid():
            item: DataTreeNode = index.internalPointer()
            parent = item.parent()
            self.beginRemoveRows(self.index(parent.row(), 0), item.row(), item.row())
            parent.childItems.remove(item)
            self.endRemoveRows()

    def getDataObj(self):
        return self.rootItem.dataType
