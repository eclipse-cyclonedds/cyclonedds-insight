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

from loguru import logger as logging

from PySide6.QtCore import Qt, QModelIndex, QAbstractListModel, Qt, Slot


class ReceiverModel(QAbstractListModel):

    ReaderIdRole = Qt.UserRole + 1
    ReceivedMsgRole = Qt.UserRole + 2

    def __init__(self, parent=None):
        super().__init__(parent)
        self._messages = []
        self._rows_by_reader = {}

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._messages)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None

        item = self._messages[index.row()]

        if role == self.ReaderIdRole:
            return item["readerId"]
        if role == self.ReceivedMsgRole:
            return item["msg"]

        return None

    def roleNames(self):
        return {
            self.ReaderIdRole: b"readerId",
            self.ReceivedMsgRole: b"receivedMsg"
        }


    @Slot(str, str)
    def addReceivedMsg(self, readerId, msg):
        row = len(self._messages)

        self.beginInsertRows(QModelIndex(), row, row)

        self._messages.append({
            "readerId": readerId,
            "msg": msg,
        })

        if readerId not in self._rows_by_reader:
            self._rows_by_reader[readerId] = []

        self._rows_by_reader[readerId].append(row)

        self.endInsertRows()


    @Slot()
    def clear(self):
        self.beginResetModel()

        self._messages.clear()
        self._rows_by_reader.clear()

        self.endResetModel()

    @Slot(str)
    def exportToFile(self, filePath):
        logging.info(f"Export messages to file: {filePath}")
        try:
            with open(filePath, "w", encoding="utf-8") as f:
                for item in self._messages:
                    f.write(f"{item['msg']}\n")
        except Exception as e:
            logging.error(f"Error exporting messages to file: {e}")
