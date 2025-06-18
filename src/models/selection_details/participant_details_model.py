from PySide6.QtCore import Qt, QModelIndex, QAbstractItemModel, Qt, Slot, Signal, QThread
from dds_access import dds_data
import uuid

class ParticipantDetailsModel(QAbstractItemModel):

    KeyRole = Qt.UserRole + 1
    QosRole = Qt.UserRole + 2

    updateQosSignal = Signal(str)
    totalEndpointsSignal = Signal(int)

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
