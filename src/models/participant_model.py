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
from enum import Enum


class DisplayLayerEnum(Enum):
    ROOT = 0
    DOMAIN = 1
    HOSTNAME = 2
    APP = 3
    PARTICIPANT = 4
    TOPIC = 5


class ParticipantTreeNode:
    def __init__(self, data: DcpsParticipant, layer=DisplayLayerEnum.ROOT, parent=None):
        self.parentItem = parent
        self.itemData: DcpsParticipant = data
        self.childItems = []
        self.layer: DisplayLayerEnum = layer

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
        return self.layer == DisplayLayerEnum.DOMAIN


class ParticipantTreeModel(QAbstractItemModel):

    IsDomainRole = Qt.UserRole + 1
    DisplayRole = Qt.UserRole + 2

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

            if item.layer == DisplayLayerEnum.DOMAIN:
                return item.data(index)
            elif item.layer == DisplayLayerEnum.HOSTNAME:
                p = item.data(index)
                return getProperty(p, HOSTNAMES)
            elif item.layer == DisplayLayerEnum.APP:
                p = item.data(index)
                appNameWithPath = getProperty(p, PROCESS_NAMES)
                appNameStem = Path(appNameWithPath.replace("\\", f"{os.path.sep}")).stem
                return  appNameStem + ":" + getProperty(p, PIDS)
            elif item.layer == DisplayLayerEnum.PARTICIPANT:
                return str(item.data(index).key)
            else:
                return ""
        if role == self.IsDomainRole:
            return item.isDomain()
        return None

    def roleNames(self):
        return {
            self.DisplayRole: b'display',
            self.IsDomainRole: b'is_domain',
        }

    def flags(self, index):
        if not index.isValid():
            return Qt.NoItemFlags
        return super(ParticipantTreeModel, self).flags(index)

    @Slot(int, DcpsParticipant)
    def new_participant_slot(self, domain_id: int, participant: DcpsParticipant):
        logging.debug("New Participant " + str(participant.key))

        # Look for the domain_id node under rootItem
        for idx in range(self.rootItem.childCount()):
            child: ParticipantTreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                parent_index = self.createIndex(idx, 0, child)
                row_count = child.childCount()

                # Find or create the hostname node
                hostname_child = None
                for hostChild in child.childItems:
                    if getProperty(hostChild.data(0), HOSTNAMES) == getProperty(participant, HOSTNAMES):
                        hostname_child = hostChild
                        break

                if hostname_child is None:
                    # Insert only if the hostname does not exist
                    self.beginInsertRows(parent_index, row_count, row_count)
                    hostname_child = ParticipantTreeNode(participant, DisplayLayerEnum.HOSTNAME, child)
                    child.appendChild(hostname_child)
                    self.endInsertRows()

                # Find or create the application node under the hostname node
                app_child = None
                for appChild in hostname_child.childItems:
                    if (getProperty(appChild.data(0), PROCESS_NAMES) == getProperty(participant, PROCESS_NAMES) and
                            getProperty(appChild.data(0), PIDS) == getProperty(participant, PIDS)):
                        app_child = appChild
                        break

                if app_child is None:
                    hostname_index = self.createIndex(hostname_child.row(), 0, hostname_child)
                    app_row_count = hostname_child.childCount()

                    self.beginInsertRows(hostname_index, app_row_count, app_row_count)
                    app_child = ParticipantTreeNode(participant, DisplayLayerEnum.APP, hostname_child)
                    hostname_child.appendChild(app_child)
                    self.endInsertRows()

                # Check if participant already exists under the app, and add if not
                participant_exists = any(
                    partChild.data(0).key == participant.key
                    for partChild in app_child.childItems
                )

                if not participant_exists:
                    app_index = self.createIndex(app_child.row(), 0, app_child)
                    participant_row_count = app_child.childCount()

                    self.beginInsertRows(app_index, participant_row_count, participant_row_count)
                    participant_child = ParticipantTreeNode(participant, DisplayLayerEnum.PARTICIPANT, app_child)
                    app_child.appendChild(participant_child)
                    self.endInsertRows()
                break

    @Slot(int, str)
    def removed_participant_slot(self, domainId: int, participantKey: str):
        logging.debug("Remove Participant " + participantKey)

        for idx in range(self.rootItem.childCount()):
            domain_child: ParticipantTreeNode = self.rootItem.child(idx)
            if domain_child.data(0) == str(domainId):
                # Look for the hostname and app nodes
                for hostname_idx in range(domain_child.childCount()):
                    hostname_child: ParticipantTreeNode = domain_child.child(hostname_idx)

                    for app_idx in range(hostname_child.childCount()):
                        app_child: ParticipantTreeNode = hostname_child.child(app_idx)

                        # Now, look for the participant node under the app node
                        for part_idx in range(app_child.childCount()):
                            participant_child: ParticipantTreeNode = app_child.child(part_idx)

                            if str(participant_child.data(0).key) == participantKey:
                                # Found the participant; now remove it
                                app_index = self.createIndex(app_child.row(), 0, app_child)
                                self.beginRemoveRows(app_index, part_idx, part_idx)
                                app_child.removeChild(part_idx)
                                self.endRemoveRows()

                                # Clean up empty app or hostname nodes if they have no children
                                if app_child.childCount() == 0:
                                    hostname_index = self.createIndex(hostname_child.row(), 0, hostname_child)
                                    self.beginRemoveRows(hostname_index, app_idx, app_idx)
                                    hostname_child.removeChild(app_idx)
                                    self.endRemoveRows()

                                if hostname_child.childCount() == 0:
                                    domain_index = self.createIndex(domain_child.row(), 0, domain_child)
                                    self.beginRemoveRows(domain_index, hostname_idx, hostname_idx)
                                    domain_child.removeChild(hostname_idx)
                                    self.endRemoveRows()

                                return  # Exit once the participant is removed

    @Slot(int)
    def addDomain(self, domain_id: int):
        # Check if the domain already exists
        for idx in range(self.rootItem.childCount()):
            child: ParticipantTreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                return  # Domain already exists, no need to add

        # If domain does not exist, add it
        row_count = self.rootItem.childCount()
        self.beginInsertRows(QModelIndex(), row_count, row_count)
        domainChild = ParticipantTreeNode(str(domain_id), DisplayLayerEnum.DOMAIN, self.rootItem)
        self.rootItem.appendChild(domainChild)
        self.endInsertRows()

    @Slot(int)
    def removeDomain(self, domain_id: int):
        # Locate the domain index to remove
        dom_child_idx = -1
        for idx in range(self.rootItem.childCount()):
            child: ParticipantTreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                dom_child_idx = idx
                break

        # If domain exists, remove it
        if dom_child_idx != -1:
            self.beginRemoveRows(QModelIndex(), dom_child_idx, dom_child_idx)
            self.rootItem.removeChild(dom_child_idx)
            self.endRemoveRows()

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
