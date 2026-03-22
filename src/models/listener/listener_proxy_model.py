
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
from PySide6.QtCore import Property
from PySide6.QtCore import Slot
from loguru import logger as logging
from models.listener.listener_model import ListenerModel


class ListenerProxyModel(QSortFilterProxyModel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._search_text = ""

    @Property(str)
    def searchText(self):
        return self._search_text

    @searchText.setter
    def searchText(self, text):
        if self._search_text != text:
            self._search_text = text
            self.invalidateFilter()

    def filterAcceptsRow(self, source_row, source_parent):
        model = self.sourceModel()
        index = model.index(source_row, 0, source_parent)

        topicName = model.data(index, ListenerModel.TopicNameRole) or ""
        topicType = model.data(index, ListenerModel.TopicTypeRole) or ""

        term = self._search_text.strip().lower()
        if not term:
            return True

        return term in topicName.lower() or term in topicType.lower()
