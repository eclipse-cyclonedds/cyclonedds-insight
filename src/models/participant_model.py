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
import uuid
from typing import List
from cyclonedds.builtin import DcpsParticipant
from loguru import logger as logging
from dds_access import dds_data
from dds_access.dds_utils import getProperty, getHostname, getAppName, PROCESS_NAMES, PIDS, ADDRESSES
from enum import Enum


# defines what type is the current node
class DisplayLayerEnum(Enum):
    ROOT = 0
    DOMAIN = 1
    HOSTNAME = 2
    APP = 3
    PARTICIPANT = 4
    TOPIC = 5
    READER = 6
    WRITER = 7


class ParticipantTreeNode:
    def __init__(self, data: DcpsParticipant, layer=DisplayLayerEnum.ROOT, parent=None):
        self.parentItem = parent
        self.itemData: DcpsParticipant = data
        self.childMap = {}
        self.layer: DisplayLayerEnum = layer

    def appendChild(self, key, item):
        self.childMap[key] = item

    def child(self, row):
        return list(self.childMap.values())[row]

    def childCount(self):
        return len(list(self.childMap.keys()))

    def columnCount(self):
        return 1

    def data(self, column):
        return self.itemData

    def parent(self):
        return self.parentItem

    def row(self):
        if self.parentItem:
            return list(self.parentItem.childMap.values()).index(self)
        return 0

    def removeChild(self, row):
        del self.childMap[list(self.childMap.keys())[row]]

    def removeChildByChild(self, child):
        vals = list(self.childMap.values())
        if child in vals:
            index = vals.index(child)
            self.removeChild(index)

    def isDomain(self):
        return self.layer == DisplayLayerEnum.DOMAIN

    def isHost(self):
        return self.layer == DisplayLayerEnum.HOSTNAME

    def isProcess(self):
        return self.layer == DisplayLayerEnum.APP

    def isParticipant(self):
        return self.layer == DisplayLayerEnum.PARTICIPANT

    def isTopic(self):
        return self.layer == DisplayLayerEnum.TOPIC

    def isReader(self):
        return self.layer == DisplayLayerEnum.READER

    def isWriter(self):
        return self.layer == DisplayLayerEnum.WRITER

class ParticipantTreeModel(QAbstractItemModel):

    # Defines which variables of the model are avaiable in qml
    DisplayRole = Qt.UserRole + 1
    IsDomainRole = Qt.UserRole + 2
    IsParticipantRole = Qt.UserRole + 3
    IsTopicRole = Qt.UserRole + 4
    IsReaderRole = Qt.UserRole + 5
    IsWriterRole = Qt.UserRole + 6
    IsHostRole = Qt.UserRole + 7
    IsProcessRole = Qt.UserRole + 8

    remove_domain_request_signal = Signal(int)
    request_endpoints_by_participant_key_signal = Signal(str, int, str)

    def __init__(self, rootItem: ParticipantTreeNode, parent=None):
        super(ParticipantTreeModel, self).__init__(parent)
        self.rootItem = rootItem
        self.currentRequests: List[str] = []

        self.dds_data = dds_data.DdsData()

        # Connect to from dds_data to self
        self.dds_data.new_participant_signal.connect(self.new_participant_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_participant_signal.connect(self.removed_participant_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.update_participant_signal.connect(self.update_participant_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_domain_signal.connect(self.addDomain, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_domain_signal.connect(self.removeDomain, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_endpoint_signal.connect(self.remove_endpoint_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_endpoint_signal.connect(self.new_endpoint_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.response_endpoints_by_participant_key_signal.connect(self.response_endpoints_by_participant_key_slot, Qt.ConnectionType.QueuedConnection)

        # Connect from self to dds_data
        self.remove_domain_request_signal.connect(self.dds_data.remove_domain, Qt.ConnectionType.QueuedConnection)
        self.request_endpoints_by_participant_key_signal.connect(self.dds_data.requestEndpointsByParticipantKey, Qt.ConnectionType.QueuedConnection)

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
                return getHostname(p)
            elif item.layer == DisplayLayerEnum.APP:
                p = item.data(index)
                return getAppName(p)
            elif item.layer == DisplayLayerEnum.PARTICIPANT:
                return str(item.data(index).key)
            elif item.layer == DisplayLayerEnum.TOPIC:
                return str(item.data(index))
            elif item.layer == DisplayLayerEnum.READER or item.layer == DisplayLayerEnum.WRITER:
                return str(item.data(index))
            else:
                return ""
        if role == self.IsDomainRole:
            return item.isDomain()
        elif role == self.IsHostRole:
            return item.isHost()
        elif role == self.IsProcessRole:
            return item.isProcess()
        elif role == self.IsParticipantRole:
            return item.isParticipant()
        elif role == self.IsTopicRole:
            return item.isTopic()
        elif role == self.IsReaderRole:
            return item.isReader()
        elif role == self.IsWriterRole:
            return item.isWriter()

        return None

    def roleNames(self):
        return {
            self.DisplayRole: b'display',
            self.IsDomainRole: b'is_domain',
            self.IsTopicRole: b'is_topic',
            self.IsParticipantRole: b'is_participant',
            self.IsReaderRole: b'is_reader',
            self.IsWriterRole: b'is_writer',
            self.IsHostRole: b'is_host',
            self.IsProcessRole: b'is_process'
        }

    def flags(self, index):
        if not index.isValid():
            return Qt.NoItemFlags
        return super(ParticipantTreeModel, self).flags(index)

    @Slot(int, DcpsParticipant)
    def new_participant_slot(self, domain_id: int, participant: DcpsParticipant):
        logging.trace("Add Participant " + str(participant.key) + " to participant model")

        # Look for the domain_id node under rootItem
        hostname = getHostname(participant)
        appName = getAppName(participant)

        if domain_id in self.rootItem.childMap:
            domain_child = self.rootItem.childMap[domain_id]

            parent_index = self.createIndex(domain_child.row(), 0, domain_child)
            row_count = domain_child.childCount()

            # Add hostname
            if hostname in domain_child.childMap:
                hostname_child = domain_child.childMap[hostname]
            else:
                self.beginInsertRows(parent_index, row_count, row_count)
                hostname_child = ParticipantTreeNode(participant, DisplayLayerEnum.HOSTNAME, domain_child)
                domain_child.appendChild(getHostname(participant), hostname_child)
                self.endInsertRows()
        
            # Add app
            if appName in hostname_child.childMap:
                app_child = hostname_child.childMap[appName]
            else:
                hostname_index = self.createIndex(hostname_child.row(), 0, hostname_child)
                app_row_count = hostname_child.childCount()

                self.beginInsertRows(hostname_index, app_row_count, app_row_count)
                app_child = ParticipantTreeNode(participant, DisplayLayerEnum.APP, hostname_child)
                hostname_child.appendChild(appName, app_child)
                self.endInsertRows()

            # Add participant
            if str(participant.key) not in app_child.childMap:
                app_index = self.createIndex(app_child.row(), 0, app_child)
                participant_row_count = app_child.childCount()

                self.beginInsertRows(app_index, participant_row_count, participant_row_count)
                participant_child = ParticipantTreeNode(participant, DisplayLayerEnum.PARTICIPANT, app_child)
                app_child.appendChild(str(participant.key), participant_child)
                self.endInsertRows()

    @Slot(int, DcpsParticipant)
    def update_participant_slot(self, domain_id: int, participant: DcpsParticipant):
        logging.trace("Update Participant " + str(participant.key))

        self.removed_participant_slot(domain_id, str(participant.key))
        self.new_participant_slot(domain_id, participant)

        requestId: str = str(uuid.uuid4())
        self.currentRequests.append(requestId)
        self.request_endpoints_by_participant_key_signal.emit(requestId, domain_id, str(participant.key))

    @Slot(int, str)
    def removed_participant_slot(self, domainId: int, participantKey: str):
        logging.trace("Remove Participant " + participantKey)

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

                                return

    @Slot(int)
    def addDomain(self, domain_id: int):
        if domain_id not in self.rootItem.childMap:
            row_count = self.rootItem.childCount()
            self.beginInsertRows(QModelIndex(), row_count, row_count)
            domainChild = ParticipantTreeNode(str(domain_id), DisplayLayerEnum.DOMAIN, self.rootItem)
            self.rootItem.appendChild(domain_id, domainChild)
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
        isDomain = False
        if index.isValid():
            isDomain = self.data(index, role=self.IsDomainRole)
        return isDomain

    @Slot(QModelIndex, result=bool)
    def getIsHost(self, index: QModelIndex):
        if index.isValid():
            return self.data(index, role=self.IsHostRole)
        return False

    @Slot(QModelIndex, result=bool)
    def getIsProcess(self, index: QModelIndex):
        if index.isValid():
            return self.data(index, role=self.IsProcessRole)
        return False

    @Slot(QModelIndex, result=bool)
    def getIsParticipant(self, index: QModelIndex):
        if index.isValid():
            return self.data(index, role=self.IsParticipantRole)
        return False

    @Slot(QModelIndex, result=bool)
    def getIsTopic(self, index: QModelIndex):
        if index.isValid():
            return self.data(index, role=self.IsTopicRole)
        return False

    @Slot(QModelIndex, result=bool)
    def getIsEndpoint(self, index: QModelIndex):
        if index.isValid():
            return self.data(index, role=self.IsWriterRole) or self.data(index, role=self.IsReaderRole)
        return False

    @Slot(QModelIndex, result=int)
    def getDomain(self, index: QModelIndex):
        if not index.isValid():
            return None
        if self.getIsRowDomain(index):
            return int(self.data(index, role=self.DisplayRole))
        elif self.getIsHost(index):
            parentIndex = self.parent(index)
            dom = self.data(parentIndex, role=self.DisplayRole)
            if dom:
                return int(dom)
            return None
        elif self.getIsProcess(index):
            parentIndex = self.parent(self.parent(index))
            dom = self.data(parentIndex, role=self.DisplayRole)
            if dom:
                return int(dom)
            return None
        elif self.getIsParticipant(index):
            parentIndex = self.parent(self.parent(self.parent(index)))
            dom = self.data(parentIndex, role=self.DisplayRole)
            if dom:
                return int(dom)
            return None
        elif self.getIsTopic(index):
            parentIndex = self.parent(self.parent(self.parent(self.parent(index))))
            dom = self.data(parentIndex, role=self.DisplayRole)
            if dom:
                return int(dom)
            return None
        elif self.getIsEndpoint(index):
            parentIndex = self.parent(self.parent(self.parent(self.parent(self.parent(index)))))
            dom = self.data(parentIndex, role=self.DisplayRole)
            if dom:
                return int(dom)
            return None

        return None

    @Slot(QModelIndex, result=str)
    def getName(self, index: QModelIndex):
        if index.isValid():
            display = self.data(index, role=self.DisplayRole)
            return str(display)
        return ""

    @Slot(str, int, dds_data.DataEndpoint)
    def new_endpoint_slot(self, unkown: str, domain_id: int, participant: dds_data.DataEndpoint):

        hostname = getHostname(participant.participant)
        appName = getAppName(participant.participant)

        if domain_id in self.rootItem.childMap:
            domain_child = self.rootItem.childMap[domain_id]
            if hostname in domain_child.childMap:
                hostname_child = domain_child.childMap[hostname]
                if appName in hostname_child.childMap:
                    app_child = hostname_child.childMap[appName]
                    if str(participant.participant.key) in app_child.childMap:
                        participant_child = app_child.childMap[str(participant.participant.key)]

                        # Add or get topic
                        if participant.endpoint.topic_name in participant_child.childMap:
                            topic_child = participant_child.childMap[participant.endpoint.topic_name]
                        else:
                            part_index = self.createIndex(participant_child.row(), 0, participant_child)
                            topic_row = participant_child.childCount()
                            self.beginInsertRows(part_index, topic_row, topic_row)
                            topic_child = ParticipantTreeNode(participant.endpoint.topic_name, DisplayLayerEnum.TOPIC, participant_child)
                            participant_child.appendChild(participant.endpoint.topic_name, topic_child)
                            self.endInsertRows()

                        # Add endpoint under topic
                        if str(participant.endpoint.key) not in topic_child.childMap:
                            topic_index = self.createIndex(topic_child.row(), 0, topic_child)
                            endpoint_row = topic_child.childCount()
                            self.beginInsertRows(topic_index, endpoint_row, endpoint_row)
                            endpoint_child = ParticipantTreeNode(participant.endpoint.key, DisplayLayerEnum.READER if participant.isReader() else DisplayLayerEnum.WRITER,  topic_child)
                            topic_child.appendChild(str(participant.endpoint.key), endpoint_child)
                            self.endInsertRows()

    @Slot(int, str)
    def remove_endpoint_slot(self, domain_id: int, endpoint_key: str):

        if domain_id in self.rootItem.childMap:
            domain_child = self.rootItem.childMap[domain_id]
            for hostname_child in domain_child.childMap.values():
                for app_child in hostname_child.childMap.values():
                    for participant_child in app_child.childMap.values():
                        for topic_child in participant_child.childMap.values():

                            # Found the endpoint, remove it
                            if endpoint_key in topic_child.childMap:
                                endpoint_child = topic_child.childMap[endpoint_key]
                                endpoint_index = self.createIndex(endpoint_child.row(), 0, endpoint_child)
                                self.beginRemoveRows(endpoint_index.parent(), endpoint_child.row(), endpoint_child.row())
                                topic_child.removeChildByChild(endpoint_child)
                                self.endRemoveRows()

                                # If the topic is now empty, remove the topic
                                if not topic_child.childMap.values():
                                    topic_index = self.createIndex(topic_child.row(), 0, topic_child)
                                    self.beginRemoveRows(topic_index.parent(), topic_child.row(), topic_child.row())
                                    participant_child.removeChildByChild(topic_child)
                                    self.endRemoveRows()

                                return

    @Slot(str, int, dds_data.DataEndpoint)
    def response_endpoints_by_participant_key_slot(self, requestId: str, domainId: int, endpoints: dds_data.DataEndpoint):
        if requestId not in self.currentRequests:
            return

        logging.trace("Response Endpoints By Participant Key, requestId: " + requestId)

        self.currentRequests.remove(requestId)
        for endpoint in endpoints:
            self.new_endpoint_slot("", domainId, endpoint)
