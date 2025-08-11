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

from PySide6.QtCore import Qt, QAbstractItemModel, Qt, Slot, Signal
from dds_access import dds_data
import uuid


class ParticipantDetailsModel(QAbstractItemModel):

    updateQosSignal = Signal(str)
    requestParticipantByKeySignal = Signal(str, int, str)

    def __init__(self, parent=None):
        super(ParticipantDetailsModel, self).__init__(parent)

        self.requestIds = set()
        self.domainId = -1

        self.dds_data = dds_data.DdsData()

        # self to dds_data
        self.requestParticipantByKeySignal.connect(self.dds_data.requestParticipantByKey, Qt.ConnectionType.QueuedConnection)
        # From dds_data to self
        self.dds_data.response_participant_by_key.connect(self.receive_participant, Qt.ConnectionType.QueuedConnection)

    @Slot(int, str)
    def start(self, domainId, pkey):
        self.domainId = domainId
        reqId = str(uuid.uuid4())
        self.requestIds.add(reqId)
        self.requestParticipantByKeySignal.emit(reqId, self.domainId, pkey)

    @Slot(str, int, object)
    def receive_participant(self, requestId: str, participant):
        if participant is None or requestId not in self.requestIds:
            return

        split = "Qos:\n"
        for idx, q in enumerate(participant.qos):
            split += "  " + str(q)
            if idx < len(participant.qos) - 1:
                split += "\n"

        self.updateQosSignal.emit(split)
