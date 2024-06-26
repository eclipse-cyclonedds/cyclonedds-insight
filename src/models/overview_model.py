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

from PySide6.QtCore import Qt, QModelIndex, QAbstractItemModel, Qt
from PySide6.QtCore import Signal, Slot
import logging
import dds_data


class TreeNode:
    def __init__(self, data: str, is_domain=False, has_qos_mismatch=False, parent=None):
        self.parentItem = parent
        self.itemData = data
        self.childItems = []
        self.is_domain = is_domain
        self.has_qos_mismatch = has_qos_mismatch

    def appendChild(self, item):
        self.childItems.append(item)

    def child(self, row):
        return self.childItems[row]

    def childCount(self):
        return len(self.childItems)

    def columnCount(self):
        return 1

    def data(self, column):
        return self.itemData

    def parent(self):
        return self.parentItem
    def row(self):
        if self.parentItem:
            return self.parentItem.childItems.index(self)
        return 0

    def removeChild(self, row):
        del self.childItems[row]

    def isDomain(self):
        return self.is_domain

    def hasQosMismatch(self):
        return self.has_qos_mismatch

class TreeModel(QAbstractItemModel):

    IsDomainRole = Qt.UserRole + 1
    DisplayRole = Qt.UserRole + 2
    HasQosMismatch = Qt.UserRole + 3

    remove_domain_request_signal = Signal(int)

    def __init__(self, rootItem: TreeNode, parent=None):
        super(TreeModel, self).__init__(parent)
        self.rootItem = rootItem

        self.dds_data = dds_data.DdsData()

        # Connect to from dds_data to self
        self.dds_data.new_topic_signal.connect(self.new_topic_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.remove_topic_signal.connect(self.remove_topic_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_domain_signal.connect(self.addDomain, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_domain_signal.connect(self.removeDomain, Qt.ConnectionType.QueuedConnection)
        self.dds_data.no_more_mismatch_in_topic_signal.connect(self.no_more_mismatch_in_topic_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.publish_mismatch_signal.connect(self.publish_mismatch_slot, Qt.ConnectionType.QueuedConnection)

        # Connect from self to dds_data
        self.remove_domain_request_signal.connect(self.dds_data.remove_domain, Qt.ConnectionType.QueuedConnection)

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
        if role == Qt.DisplayRole:
            return item.data()
        if role == self.DisplayRole:
            return item.data(index)
        if role == self.IsDomainRole:
            return item.isDomain()
        if role == self.HasQosMismatch:
            return item.hasQosMismatch()
        return None

    def roleNames(self):
        return {
            self.DisplayRole: b'display',
            self.IsDomainRole: b'is_domain',
            self.HasQosMismatch: b'has_qos_mismatch'
        }

    def flags(self, index):
        if not index.isValid():
            return Qt.NoItemFlags
        return super(TreeModel, self).flags(index)

    @Slot(int, str)
    def new_topic_slot(self, domain_id, topic_name):
        for idx in range(self.rootItem.childCount()):
            child: TreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                parent_index = self.createIndex(idx, 0, child)
                row_count = child.childCount()
                self.beginInsertRows(parent_index, row_count, row_count)
                topic_child = TreeNode(topic_name, False, False, child)
                child.appendChild(topic_child)
                self.endInsertRows()

    def set_qos_mismatch(self, domain_id: int, topic_name: str, has_mismatch: bool):
        for idx in range(self.rootItem.childCount()):
            child: TreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                child.has_qos_mismatch = has_mismatch
                index_domain = self.index(idx, 0)
                self.dataChanged.emit(index_domain, index_domain, [self.HasQosMismatch])
                for idx_child in range(child.childCount()):
                    topic_child: TreeNode = child.child(idx_child)
                    if topic_name == topic_child.data(0):
                        topic_child.has_qos_mismatch = has_mismatch
                        index1 = self.index(idx_child, 0, self.index(idx, 0))
                        index2 = self.index(idx_child, self.columnCount()-1, self.index(idx, self.columnCount()-1))
                        roles = [self.HasQosMismatch]
                        self.dataChanged.emit(index1, index2, roles)

    @Slot(int, str, list)
    def publish_mismatch_slot(self, domain_id, topicName, mismatches):
        if len(mismatches) > 0:
            self.set_qos_mismatch(domain_id, topicName, True)

    @Slot(int, str)
    def no_more_mismatch_in_topic_slot(self, domain_id, topic_name):
        self.set_qos_mismatch(domain_id, topic_name, False)

    @Slot(int, str)
    def remove_topic_slot(self, domain_id, topic_name):
        for idx in range(self.rootItem.childCount()):
            child: TreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                found_topic_idx = -1
                for idx_topic in range(child.childCount()):
                    child_topic: TreeNode = child.child(idx_topic)
                    if child_topic.data(0) == str(topic_name):
                        self.beginRemoveRows(self.createIndex(idx, 0, child), idx_topic, idx_topic)
                        child.removeChild(idx_topic)
                        self.endRemoveRows()
                        break

    @Slot(int)
    def addDomain(self, domain_id):
        for idx in range(self.rootItem.childCount()):
            child: TreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                return

        self.beginResetModel()
        domainChild = TreeNode(str(domain_id), True, False, self.rootItem)
        self.rootItem.appendChild(domainChild)
        self.endResetModel()

    @Slot(int)
    def removeDomain(self, domain_id):
        dom_child_idx = -1
        for idx in range(self.rootItem.childCount()):
            child: TreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                dom_child_idx = idx
                break

        if  dom_child_idx != -1:
            self.beginResetModel()
            self.rootItem.removeChild(dom_child_idx)
            self.endResetModel()

    @Slot(QModelIndex)
    def removeDomainRequest(self, indx):
        domainId = self.data(indx, role=self.DisplayRole)
        isDomain = self.data(indx, role=self.IsDomainRole)
        if domainId != None or isDomain == True:
            self.remove_domain_request_signal.emit(int(domainId))

    @Slot(int)
    def addDomainRequest(self, domain_id):
        self.dds_data.add_domain(domain_id)

    @Slot(QModelIndex, result=bool)
    def getIsRowDomain(self, index: QModelIndex):
        isDomain = self.data(index, role=self.IsDomainRole)
        return isDomain

    @Slot(QModelIndex, result=int)
    def getDomain(self, index: QModelIndex):
        isDomain = self.data(index, role=self.IsDomainRole)
        if not isDomain:
            parentIndex = self.parent(index)
            dom = self.data(parentIndex, role=self.DisplayRole)
            if dom:
                return int(dom)
            return None

        return int(self.data(index, role=self.DisplayRole))

    @Slot(QModelIndex, result=str)
    def getName(self, index: QModelIndex):
        display = self.data(index, role=self.DisplayRole)
        return str(display)
