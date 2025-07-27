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
from models.overview_model.tree_model import TreeModel


class TreeFilterProxyModel(QSortFilterProxyModel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._filter = ""

    @Slot(result=QAbstractItemModel)
    def getSourceModel(self):
        return self.sourceModel()

    @Slot(str)
    def setFilter(self, text):
        self._filter = text
        self.invalidateFilter()

    def filterAcceptsRow(self, source_row, source_parent):
        model = self.sourceModel()
        index = model.index(source_row, 0, source_parent)
        return self.filterAcceptsIndex(index)

    def filterAcceptsIndex(self, index):
        model = self.sourceModel()
        if not index.isValid():
            return False

        if self._filter.lower() in model.data(index, TreeModel.DisplayRole).lower():
            return True

        for i in range(model.rowCount(index)):
            if self.filterAcceptsIndex(model.index(i, 0, index)):
                return True

        return False

    @Slot(QModelIndex, result=bool)
    def getIsRowTopic(self, index: QModelIndex):
        if not index.isValid():
            return False
        source_index = self.mapToSource(index)
        return self.sourceModel().getIsRowTopic(source_index)

    @Slot(QModelIndex, result=bool)
    def getIsRowDomain(self, index: QModelIndex):
        if not index.isValid():
            return False
        source_index = self.mapToSource(index)
        return self.sourceModel().getIsRowDomain(source_index)

    @Slot(QModelIndex, result=int)
    def getDomain(self, index: QModelIndex):
        if not index.isValid():
            return None
        source_index = self.mapToSource(index)
        return self.sourceModel().getDomain(source_index)

    @Slot(QModelIndex, result=str)
    def getName(self, index: QModelIndex):
        if not index.isValid():
            return ""
        source_index = self.mapToSource(index)
        return self.sourceModel().getName(source_index)

    @Slot(QModelIndex)
    def removeDomainRequest(self, index: QModelIndex):
        if not index.isValid():
            return
        self.sourceModel()._removeDomainRequest(self.mapToSource(index))
