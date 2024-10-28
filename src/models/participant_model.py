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
from pathlib import Path
import os
from cyclonedds.builtin import DcpsParticipant
import logging
import dds_data
from dds_utils import getProperty, HOSTNAMES, PROCESS_NAMES, PIDS, ADDRESSES


class ParticipantTreeNode:
    def __init__(self, data: DcpsParticipant, is_domain=False, has_qos_mismatch=False, parent=None):
        self.parentItem = parent
        self.itemData: DcpsParticipant = data
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

class ParticipantTreeModel(QAbstractItemModel):

    IsDomainRole = Qt.UserRole + 1
    DisplayRole = Qt.UserRole + 2
    HasQosMismatch = Qt.UserRole + 3
    TotalParticipants = Qt.UserRole + 4

    remove_domain_request_signal = Signal(int)

    def __init__(self, rootItem: ParticipantTreeNode, parent=None):
        super(ParticipantTreeModel, self).__init__(parent)
        self.rootItem = rootItem

        self.dds_data = dds_data.DdsData()

        # Connect to from dds_data to self
        self.dds_data.new_participant_signal.connect(self.new_participant_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_participant_signal.connect(self.removed_participant_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_domain_signal.connect(self.addDomain, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_domain_signal.connect(self.removeDomain, Qt.ConnectionType.QueuedConnection)

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
        if role == self.DisplayRole:
            if item.isDomain():
                return item.data(index)
            else:
                p = item.data(index)
                appNameWithPath = getProperty(p, PROCESS_NAMES)
                appNameStem = Path(appNameWithPath.replace("\\", f"{os.path.sep}")).stem
                return  appNameStem + ":" + getProperty(p, PIDS) + "@" + getProperty(p, HOSTNAMES) + " ("+ str(item.data(index).key) + ")"
        if role == self.IsDomainRole:
            return item.isDomain()
        if role == self.HasQosMismatch:
            return item.hasQosMismatch()
        if role == self.TotalParticipants:
            return item.childCount()
        return None

    def roleNames(self):
        return {
            self.DisplayRole: b'display',
            self.IsDomainRole: b'is_domain',
            self.HasQosMismatch: b'has_qos_mismatch',
            self.TotalParticipants: b'total_participants'
        }

    def flags(self, index):
        if not index.isValid():
            return Qt.NoItemFlags
        return super(ParticipantTreeModel, self).flags(index)

    @Slot(int, DcpsParticipant)
    def new_participant_slot(self, domain_id: int, participant: DcpsParticipant):
        logging.debug("New Participant " +  str(participant))

        for idx in range(self.rootItem.childCount()):
            child: ParticipantTreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                parent_index = self.createIndex(idx, 0, child)
                row_count = child.childCount()
                self.beginInsertRows(parent_index, row_count, row_count)
                participant_child = ParticipantTreeNode(participant, False, False, child)
                child.appendChild(participant_child)
                self.endInsertRows()

    @Slot(int, str)
    def removed_participant_slot(self, domainId: int, participantKey: str):
        logging.debug("Remove Participant " + participantKey)

        for idx in range(self.rootItem.childCount()):
            child: ParticipantTreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domainId):
                for idx_topic in range(child.childCount()):
                    child_topic: ParticipantTreeNode = child.child(idx_topic)
                    if str(child_topic.data(0).key) == str(participantKey):
                        self.beginRemoveRows(self.createIndex(idx, 0, child), idx_topic, idx_topic)
                        child.removeChild(idx_topic)
                        self.endRemoveRows()
                        break

    @Slot(int)
    def addDomain(self, domain_id):
        for idx in range(self.rootItem.childCount()):
            child: ParticipantTreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                return

        self.beginResetModel()
        domainChild = ParticipantTreeNode(str(domain_id), True, False, self.rootItem)
        self.rootItem.appendChild(domainChild)
        self.endResetModel()

    @Slot(int)
    def removeDomain(self, domain_id):
        dom_child_idx = -1
        for idx in range(self.rootItem.childCount()):
            child: ParticipantTreeNode = self.rootItem.child(idx)
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
