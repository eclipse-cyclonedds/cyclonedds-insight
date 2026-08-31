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
    SampleInfoRole = Qt.UserRole + 3
    ValidDataRole = Qt.UserRole + 4
    SourceTimestampRole = Qt.UserRole + 5
    TransmissionTimeRole = Qt.UserRole + 6
    ReceivedTimestampRole = Qt.UserRole + 7
    WriterIdRole = Qt.UserRole + 8
    DdsReaderIdRole = Qt.UserRole + 9
    WriterApplicationRole = Qt.UserRole + 10
    WriterHostnameRole = Qt.UserRole + 11
    WriterProcessIdRole = Qt.UserRole + 12
    WriterAddressesRole = Qt.UserRole + 13
    TopicTypeRole = Qt.UserRole + 14
    TopicNameRole = Qt.UserRole + 15

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
        if role == self.SampleInfoRole:
            return item["sampleInfo"]
        if role == self.ValidDataRole:
            return item["validData"]
        if role == self.SourceTimestampRole:
            return item["sourceTimestamp"]
        if role == self.TransmissionTimeRole:
            return item["transmissionTime"]
        if role == self.ReceivedTimestampRole:
            return item["receivedTimestamp"]
        if role == self.WriterIdRole:
            return item["writerId"]
        if role == self.DdsReaderIdRole:
            return item["ddsReaderId"]
        if role == self.WriterApplicationRole:
            return item["writerApplication"]
        if role == self.WriterHostnameRole:
            return item["writerHostname"]
        if role == self.WriterProcessIdRole:
            return item["writerProcessId"]
        if role == self.WriterAddressesRole:
            return item["writerAddresses"]
        if role == self.TopicTypeRole:
            return item["topicType"]
        if role == self.TopicNameRole:
            return item["topicName"]

        return None

    def roleNames(self):
        return {
            self.ReaderIdRole: b"readerId",
            self.ReceivedMsgRole: b"receivedMsg",
            self.SampleInfoRole: b"sampleInfo",
            self.ValidDataRole: b"validData",
            self.SourceTimestampRole: b"sourceTimestamp",
            self.TransmissionTimeRole: b"transmissionTime",
            self.ReceivedTimestampRole: b"receivedTimestamp",
            self.WriterIdRole: b"writerId",
            self.DdsReaderIdRole: b"ddsReaderId",
            self.WriterApplicationRole: b"writerApplication",
            self.WriterHostnameRole: b"writerHostname",
            self.WriterProcessIdRole: b"writerProcessId",
            self.WriterAddressesRole: b"writerAddresses",
            self.TopicTypeRole: b"topicType",
            self.TopicNameRole: b"topicName"
        }


    @Slot(str, str, str, bool, str, str, str, str, str, str, str, str, str, str,
          str)
    def addReceivedMsg(self, readerId, msg, sampleInfo, validData,
                       sourceTimestamp, transmissionTime, receivedTimestamp,
                       writerId, ddsReaderId, writerApplication,
                       writerHostname, writerProcessId, writerAddresses,
                       topicType, topicName):
        row = len(self._messages)

        self.beginInsertRows(QModelIndex(), row, row)

        self._messages.append({
            "readerId": readerId,
            "msg": msg,
            "sampleInfo": sampleInfo,
            "validData": validData,
            "sourceTimestamp": sourceTimestamp,
            "transmissionTime": transmissionTime,
            "receivedTimestamp": receivedTimestamp,
            "writerId": writerId,
            "ddsReaderId": ddsReaderId,
            "writerApplication": writerApplication,
            "writerHostname": writerHostname,
            "writerProcessId": writerProcessId,
            "writerAddresses": writerAddresses,
            "topicType": topicType,
            "topicName": topicName,
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
                    f.write(f"[{item['receivedTimestamp']}]  -  {item['msg']}\n")
        except Exception as e:
            logging.error(f"Error exporting messages to file: {e}")
