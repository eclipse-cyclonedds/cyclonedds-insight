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

from PySide6.QtCore import QSortFilterProxyModel
from PySide6.QtCore import Slot
from loguru import logger as logging
from models.datamodel_model.datamodel_model import DatamodelModel


class DatamodelProxyModel(QSortFilterProxyModel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._filter = ""

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

        if self._filter.lower() in model.data(index, DatamodelModel.NameRole).lower():
            return True

        for i in range(model.rowCount(index)):
            if self.filterAcceptsIndex(model.index(i, 0, index)):
                return True

        return False
