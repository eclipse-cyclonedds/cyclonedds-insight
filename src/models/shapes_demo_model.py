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

from PySide6.QtCore import Qt, QModelIndex, QAbstractListModel, Qt, QByteArray
from PySide6.QtCore import QObject, Signal, Slot, QThread
from loguru import logger as logging
import typing
import uuid
from dds_access.dispatcher import DispatcherThread
from dds_access.dds_data import DdsData
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration
from dds_access.datatypes.entity_type import EntityType
from module_handler import DataModelHandler
from dds_access.datatypes import ishape
from cyclonedds import core

from cyclonedds.topic import Topic
from cyclonedds.pub import Publisher, DataWriter
from cyclonedds.sub import Subscriber, DataReader
from cyclonedds.domain import DomainParticipant
from cyclonedds.core import SampleState, ViewState, InstanceState


class ShapesDemoModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    shapeUpdateSignale = Signal(str, str, str, int, int, int, bool)

    def __init__(self, parent=typing.Optional[QObject]) -> None:
        super().__init__()

        self.dispatcher = ShapeDispatcherThread(parent)
        self.dispatcher.onData.connect(self.onData, Qt.ConnectionType.QueuedConnection)
        self.dispatcher.start()

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> typing.Any:
        if not index.isValid():
            return None
        row = index.row()
        if role == self.NameRole:
            return "a"
        return None

    def roleNames(self) -> typing.Dict[int, QByteArray]:
        return {
            self.NameRole: b'name'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return self.dataModelHandler.count()

    @Slot(str, str, int, int, int, int)
    def publish(self, shapeType: str, color: str, x: int, y: int, size: int, speed: int):
        self.domain_participant = DomainParticipant(0)
        self.topic = Topic(self.domain_participant, shapeType, ishape.ShapeType)
        self.publisher = Publisher(self.domain_participant)
        self.writer = DataWriter(self.publisher, self.topic)
        self.writer.write(ishape.ShapeType(color, x, y, size))

    @Slot(str)
    def subscibe(self, shapeType: str):
        self.dispatcher.addEndpoint("test", shapeType, ishape.ShapeType, Qos(), EntityType.READER)

    @Slot(str, object, bool)
    def onData(self, id: str, topicName: str, data: object, disposed: bool):
        #print(data.__dict__)
        #print(f"onData {id}", data.__dict__, disposed)

        if disposed:
            self.shapeUpdateSignale.emit(id, "", "", -1, -1, -1, disposed)
        else:
            self.shapeUpdateSignale.emit(id, topicName, data.color, data.x, data.y, data.shapesize, disposed)

    def stop(self):
        self.dispatcher.stop()

class ShapeDispatcherThread(QThread):

    onData = Signal(str, str, object, bool)

    def __init__(self, parent=None):
        super().__init__()
        self.domain_participant = None
        self.waitset = None
        self.guardCondition = None
        self.running = False
        self.readerData = []

    @Slot()
    def addEndpoint(self, id: str, topic_name: str, topic_type, qos, entity_type: EntityType):
        logging.info(f"Add endpoint {id} ...")
        try:
            topic = Topic(self.domain_participant, topic_name, topic_type)

            subscriber = Subscriber(self.domain_participant)
            reader = DataReader(subscriber, topic)
            readCondition = core.ReadCondition(reader, SampleState.Any | ViewState.Any | InstanceState.Any)
            self.guardCondition.set(True)
            self.waitset.attach(readCondition)
            self.guardCondition.set(False)
            self.readerData.append((id, topic, subscriber, reader, readCondition))

            logging.info("Add endpoint ... DONE")

        except Exception as e:
            logging.error(f"Error creating endpoint {topic_name}: {e}")

    def run(self):
        self.running = True
        self.domain_participant = DomainParticipant(0)
        self.waitset = core.WaitSet(self.domain_participant)
        self.guardCondition = core.GuardCondition(self.domain_participant)
        self.waitset.attach(self.guardCondition)

        while self.running:
            try:
                self.waitset.wait(duration(infinite=True))
            except:
                pass

            for (_, topic, _, readItem, condItem) in self.readerData:
                for sample in readItem.take(condition=condItem):
                    id = str(sample.sample_info.instance_handle) + "_" + str(sample.sample_info.publication_handle)
                    if sample.sample_info.sample_state == SampleState.NotRead and sample.sample_info.instance_state == core.InstanceState.Alive and sample.sample_info.valid_data:
                        self.onData.emit(id, topic.get_name(), sample, False)
                    else:
                        self.onData.emit(id, "", None, True)

    def stop(self):
        self.running = False
        if self.guardCondition:
            self.guardCondition.set(True)

