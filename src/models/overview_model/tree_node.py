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
from PySide6.QtCore import Signal, Slot
from loguru import logger as logging
from dds_access import dds_data
from dds_access.domain_finder import DomainFinder


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

    def isTopic(self):
        return not self.is_domain

    def hasQosMismatch(self):
        return self.has_qos_mismatch
