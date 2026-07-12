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

from PySide6.QtCore import Qt, QModelIndex, QAbstractItemModel, QByteArray, Slot

from models.config_editor_model.xsd_schema import Node, parse_xsd_schema


def parse_xsd(path):
    return parse_xsd_schema(path).root


class XsdTreeModel(QAbstractItemModel):
    DisplayRole = Qt.DisplayRole
    DetailsRole = Qt.UserRole + 1
    KindRole = Qt.UserRole + 2
    PathRole = Qt.UserRole + 3

    def __init__(self, schema):
        super().__init__()
        self.schema = schema if hasattr(schema, "root") else None
        self.root = schema.root if self.schema is not None else schema

    def roleNames(self):
        return {
            self.DisplayRole: QByteArray(b"display"),
            self.DetailsRole: QByteArray(b"details"),
            self.KindRole: QByteArray(b"kind"),
        self.PathRole: QByteArray(b"path"),
        }

    def index(self, row, column, parent=QModelIndex()):
        parent_node = parent.internalPointer() if parent.isValid() else self.root
        if 0 <= row < len(parent_node.children):
            return self.createIndex(row, column, parent_node.children[row])
        return QModelIndex()

    def parent(self, index):
        if not index.isValid():
            return QModelIndex()

        node = index.internalPointer()
        parent = node.parent

        if parent is None or parent == self.root:
            return QModelIndex()

        grand = parent.parent or self.root
        row = grand.children.index(parent)
        return self.createIndex(row, 0, parent)

    def rowCount(self, parent=QModelIndex()):
        node = parent.internalPointer() if parent.isValid() else self.root
        return len(node.children)

    def columnCount(self, parent=QModelIndex()):
        return 1

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None

        node = index.internalPointer()

        if role == self.DisplayRole:
            return node.name
        if role == self.DetailsRole:
            return node.details
        if role == self.KindRole:
            return node.kind
        if role == self.PathRole:
            return node.path
        return None

    @Slot(QModelIndex, result=str)
    def detailsAt(self, index):
        if not index.isValid():
            return ""
        return index.internalPointer().details

    @Slot(QModelIndex, result=str)
    def pathAt(self, index):
        if not index.isValid():
            return ""
        return index.internalPointer().path

    @Slot(str, result=QModelIndex)
    def indexForPath(self, path):
        def find(parent_index, parent_node):
            for row, child in enumerate(parent_node.children):
                child_index = self.index(row, 0, parent_index)
                if child.path == path:
                    return child_index
                result = find(child_index, child)
                if result.isValid():
                    return result
            return QModelIndex()

        return find(QModelIndex(), self.root)
