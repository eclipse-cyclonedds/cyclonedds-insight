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

from PySide6.QtCore import QSortFilterProxyModel, Slot


class ReceiverProxyModel(QSortFilterProxyModel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._hidden_reader_ids = set()

    @Slot(str, bool)
    def showReaderId(self, reader_id: str, show: bool):
        if not reader_id:
            return

        if show:
            if reader_id in self._hidden_reader_ids:
                self._hidden_reader_ids.remove(reader_id)
        else:
            if reader_id not in self._hidden_reader_ids:
                self._hidden_reader_ids.add(reader_id)
        
        self.invalidateFilter()

    @Slot()
    def clearHiddenReaderIds(self):
        if self._hidden_reader_ids:
            self._hidden_reader_ids.clear()
            self.invalidateFilter()

    def filterAcceptsRow(self, source_row, source_parent):
        model = self.sourceModel()
        if model is None:
            return False

        index = model.index(source_row, 0, source_parent)
        if not index.isValid():
            return False

        reader_id = model.data(index, model.ReaderIdRole)
        return reader_id not in self._hidden_reader_ids
