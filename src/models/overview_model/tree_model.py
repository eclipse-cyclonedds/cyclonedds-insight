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

from PySide6.QtCore import Qt, QModelIndex, QAbstractItemModel, Qt, QSortFilterProxyModel
from PySide6.QtCore import QObject, QTimer, Signal, Slot, Property, qtTrId
from loguru import logger as logging
from dds_access import dds_data
from dds_access.domain_finder import DomainScanner, _available_probe_slots
from collections import deque
from models.overview_model.tree_node import TreeNode


class TreeModel(QAbstractItemModel):

    IsDomainRole = Qt.UserRole + 1
    DisplayRole = Qt.UserRole + 2
    HasQosMismatch = Qt.UserRole + 3
    IsTopicRole = Qt.UserRole + 4

    add_domain_request_signal = Signal(int)
    operationError = Signal(str)
    domainJoinChanged = Signal()
    remove_domain_request_signal = Signal(int)
    discover_domains_running_signal = Signal(bool)

    def __init__(self, rootItem: TreeNode, parent=None):
        super(TreeModel, self).__init__(parent)
        self.rootItem = rootItem

        self.dds_data = dds_data.DdsData()

        self.domainScanner = DomainScanner(self)
        self.domainScanner.changed.connect(
            lambda: self.discover_domains_running_signal.emit(self.domainScanner.running))
        self.domainScanner.finished.connect(self._scanFinished)
        self.domainScanner.pausedChanged.connect(self._scanPaused)
        self._join_queue = deque()
        self._joining = False
        self._joining_domain = None
        self._join_errors = {}
        self._failed_join = None

        # Connect to from dds_data to self
        self.dds_data.new_topic_signal.connect(self.new_topic_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.remove_topic_signal.connect(self.remove_topic_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_domain_signal.connect(self._addDomain, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_domain_signal.connect(self.removeDomain, Qt.ConnectionType.QueuedConnection)
        self.dds_data.no_more_mismatch_in_topic_signal.connect(self.no_more_mismatch_in_topic_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.publish_mismatch_signal.connect(self.publish_mismatch_slot, Qt.ConnectionType.QueuedConnection)

        self.dds_data.domain_ready_signal.connect(self._domainReady, Qt.ConnectionType.QueuedConnection)
        self.dds_data.domain_initialization_failed_signal.connect(self._domainJoinFailed, Qt.ConnectionType.QueuedConnection)

        # Connect from self to dds_data
        self.remove_domain_request_signal.connect(self.dds_data.remove_domain, Qt.ConnectionType.QueuedConnection)
        self.add_domain_request_signal.connect(self.dds_data.add_domain, Qt.ConnectionType.QueuedConnection)

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
        if role == self.IsTopicRole:
            return item.isTopic()
        if role == self.HasQosMismatch:
            return item.hasQosMismatch()
        return None

    def roleNames(self):
        return {
            self.DisplayRole: b'display',
            self.IsDomainRole: b'is_domain',
            self.HasQosMismatch: b'has_qos_mismatch',
            self.IsTopicRole: b'is_topic'
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

    def _addDomain(self, domain_id: int):
        if domain_id != self._joining_domain:
            self.domainScanner.mark_joined(domain_id)
        # Check if the domain already exists
        for idx in range(self.rootItem.childCount()):
            child: TreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                return  # Domain already exists, no need to add

        # Add new domain if it doesn't exist
        row_count = self.rootItem.childCount()
        self.beginInsertRows(QModelIndex(), row_count, row_count)
        domainChild = TreeNode(str(domain_id), True, False, self.rootItem)
        self.rootItem.appendChild(domainChild)
        self.endInsertRows()

    @Slot(int)
    def removeDomain(self, domain_id: int):
        self.domainScanner.mark_joined(domain_id, False)
        if self._failed_join == domain_id:
            self._failed_join = None
            self._joining_domain = None
            QTimer.singleShot(0, self._continueDomainJoins)
        # Locate the domain index to remove
        dom_child_idx = -1
        for idx in range(self.rootItem.childCount()):
            child: TreeNode = self.rootItem.child(idx)
            if child.data(0) == str(domain_id):
                dom_child_idx = idx
                break

        # Remove the domain if it exists
        if dom_child_idx != -1:
            self.beginRemoveRows(QModelIndex(), dom_child_idx, dom_child_idx)
            self.rootItem.removeChild(dom_child_idx)
            self.endRemoveRows()

    @Slot(QModelIndex)
    def _removeDomainRequest(self, indx):
        domainId = self.data(indx, role=self.DisplayRole)
        isDomain = self.data(indx, role=self.IsDomainRole)
        if domainId != None or isDomain == True:
            self.remove_domain_request_signal.emit(int(domainId))

    @Slot(int)
    def addDomainRequest(self, domain_id: int):
        self.add_domain_request_signal.emit(domain_id)

    @Slot(QModelIndex, result=bool)
    def getIsRowDomain(self, index: QModelIndex):
        isDomain = False
        if index.isValid():
            isDomain = self.data(index, role=self.IsDomainRole)
        return isDomain

    @Slot(QModelIndex, result=bool)
    def getIsRowTopic(self, index: QModelIndex):
        isTopic = False
        if index.isValid():
            isTopic = self.data(index, role=self.IsTopicRole)
        return isTopic

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

    @Property(QObject, constant=True)
    def scanner(self):
        return self.domainScanner

    @Slot()
    def scanDomains(self):
        if self._joining:
            return
        self._join_errors.clear()
        self.domainJoinChanged.emit()
        joined = [int(self.rootItem.child(i).data(0)) for i in range(self.rootItem.childCount())]
        self.domainScanner.start(joined)

    def _scanFinished(self):
        if self.domainScanner.errorCount:
            message = qtTrId("domain.scan.error").replace("%1", str(self.domainScanner.errorCount))
            self.operationError.emit(message.replace("%2", self.domainScanner.error_details()))
        if self._joining:
            self._continueDomainJoins()

    @Property(bool, notify=domainJoinChanged)
    def joiningDomains(self):
        return self._joining

    @Property("QVariantList", notify=domainJoinChanged)
    def pendingDomainIds(self):
        return ([self._joining_domain] if self._joining_domain is not None else []) + list(self._join_queue)

    @Property(str, notify=domainJoinChanged)
    def domainJoinErrorDetails(self):
        return "\n".join(f"{domain}: " + (qtTrId("domain.scan.resource.limit")
                         if detail == "RESOURCE_HEADROOM_UNAVAILABLE" else detail)
                         for domain, detail in sorted(self._join_errors.items()))

    @Slot("QVariantList")
    def joinDiscoveredDomains(self, domains):
        if self._joining:
            return
        candidates = set(self.domainScanner.candidateDomains)
        selected = sorted({int(domain) for domain in domains if type(domain) in (int, float) and domain in candidates})
        if not selected:
            return
        self._join_queue = deque(selected)
        self._join_errors.clear()
        self._joining = True
        self._joining_domain = None
        self.domainJoinChanged.emit()
        # Temporarily release probes for safe native initialization, then
        # continue the same search with its progress and results intact.
        if self.domainScanner.running:
            self.domainScanner.pause()
        else:
            self._continueDomainJoins()

    @Slot(bool)
    def _scanPaused(self, paused):
        if paused and self._joining:
            self._continueDomainJoins()

    def _continueDomainJoins(self):
        if self.domainScanner.running and not self.domainScanner.paused:
            return
        if not self._joining or self._joining_domain is not None:
            return
        while self._join_queue:
            domain = self._join_queue.popleft()
            if domain in self.domainScanner.joinedDomains:
                continue
            if _available_probe_slots() < 1:
                for failed in [domain] + list(self._join_queue):
                    self._join_errors[failed] = "RESOURCE_HEADROOM_UNAVAILABLE"
                self._join_queue.clear()
                break
            self._joining_domain = domain
            self.domainJoinChanged.emit()
            self.add_domain_request_signal.emit(domain)
            return
        self._joining = False
        self.domainScanner.resume()
        self.domainJoinChanged.emit()
        if self._join_errors:
            message = qtTrId("domain.scan.join.error").replace("%1", str(len(self._join_errors)))
            self.operationError.emit(message.replace("%2", self.domainJoinErrorDetails))

    @Slot(int)
    def _domainReady(self, domain):
        if self._joining_domain == domain:
            self.domainScanner.mark_joined(domain)
            self._joining_domain = None
            self.domainJoinChanged.emit()
            QTimer.singleShot(0, self._continueDomainJoins)

    @Slot(int, str)
    def _domainJoinFailed(self, domain, detail):
        if self._joining_domain == domain and self._failed_join is None:
            self._join_errors[domain] = detail
            self._failed_join = domain
            self.remove_domain_request_signal.emit(domain)
            self.domainJoinChanged.emit()

    @Slot(result=None)
    def aboutToClose(self):
        self._joining = False
        self._join_queue.clear()
        self.domainScanner.cancel()
