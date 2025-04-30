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
import time
import uuid
from dds_access.dispatcher import DispatcherThread
from dds_access.dds_data import DdsData
from dds_access import dds_utils
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
import math
import random


class ShapesDemoModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    shapeUpdateSignale = Signal(str, str, str, int, int, int, bool)

    def __init__(self, parent=typing.Optional[QObject]) -> None:
        super().__init__()
        self.parent = parent
        self.domain_participant = None
        self.writerShapeThreads = {}
        self.dispatcher = None
        self.publishInfos = None
        self.subscribeInfos = None

    @Slot()
    def start(self):
        if self.domain_participant is None:
            self.domain_participant = DomainParticipant(0)
            self.dispatcher = ShapeDispatcherThread(self.domain_participant, self.parent)
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

    @Slot(str, str, int, int)
    def setPublishInfos(self, shapeType: str, color: str, size: int, speed: int):
        self.publishInfos = (shapeType, color, size, speed)

    def publish(self, qos):
        id = str(uuid.uuid4())
        (shapeType, color, size, speed) = self.publishInfos
        self.writerShapeThreads[id] = ShapeDynamicThread(self.domain_participant, qos, shapeType, color.upper(), size, speed)
        self.writerShapeThreads[id].start()

    @Slot(str)
    def setSubscribeInfos(self, shapeType: str):
        self.subscribeInfos = shapeType

    def subscibe(self, qos):
        shapeType = self.subscribeInfos
        self.dispatcher.addEndpoint(shapeType, ishape.ShapeType, qos)

    @Slot(str, object, bool)
    def onData(self, id: str, topicName: str, data: object, disposed: bool):
        if disposed:
            self.shapeUpdateSignale.emit(id, "", "", -1, -1, -1, disposed)
        else:
            self.shapeUpdateSignale.emit(id, topicName, data.color, data.x, data.y, data.shapesize, disposed)

    def stop(self):
        if self.dispatcher:
            self.dispatcher.stop()
        for thread in self.writerShapeThreads.values():
            thread.stop()

    @Slot(int, str, str,
          str, str, str, int, bool, bool, list,
          str, bool, bool, bool, bool, bool, bool,
          str, int,
          str,
          str, int,
          int, int, int, int,
          str, bool, bool,
          bool, int, int, int,
          int, int, int,
          int, str,
          str,
          str, str, str, str, str, str,
          int, str, int,
          int, int, int,
          int)
    def setQosSelection(self, domain_id, topic_name, topic_type,
        q_own, q_dur, q_rel, q_rel_max_block_msec, q_xcdr1, q_xcdr2, partitions,
        type_consis, ig_seq_bnds, ig_str_bnds, ign_mem_nam, prev_ty_wide, fore_type_vali, fore_type_vali_allow,
        history, history_keep_last_nr,
        destination_order,
        liveliness, liveliness_seconds,
        lifespan_seconds, deadline_seconds, latencybudget_seconds, owner_strength,
        presentation_access_scope, pres_acc_scope_coherent, pres_acc_scope_ordered,
        writer_life_autodispose,
        reader_life_nowriter_delay, reader_life_disposed, transport_prio,
        limit_max_samples, limit_max_instances, limit_max_samples_per_instance,
        timebased_filter_time_sec, ignore_local,
        user_data, group_data, entity_name, prop_name, prop_value, bin_prop_name, bin_prop_value,
        durserv_cleanup_delay_minutes, durserv_history, durserv_history_keep_last_nr,
        durserv_max_samples, durserv_max_instances, durserv_max_samples_per_instance,
        entityTypeInteger):

        logging.debug("set qos" + str(domain_id) + " " + str(topic_name) + " " + str(topic_type))

        qos = dds_utils.toQos(
            q_own, q_dur, q_rel, q_rel_max_block_msec, q_xcdr1, q_xcdr2, partitions,
            type_consis, ig_seq_bnds, ig_str_bnds, ign_mem_nam, prev_ty_wide, fore_type_vali, fore_type_vali_allow,
            history, history_keep_last_nr,
            destination_order,
            liveliness, liveliness_seconds,
            lifespan_seconds, deadline_seconds, latencybudget_seconds, owner_strength,
            presentation_access_scope, pres_acc_scope_coherent, pres_acc_scope_ordered,
            writer_life_autodispose,
            reader_life_nowriter_delay, reader_life_disposed, transport_prio,
            limit_max_samples, limit_max_instances, limit_max_samples_per_instance,
            timebased_filter_time_sec, ignore_local,
            user_data, group_data, entity_name, prop_name, prop_value, bin_prop_name, bin_prop_value,
            durserv_cleanup_delay_minutes, durserv_history, durserv_history_keep_last_nr,
            durserv_max_samples, durserv_max_instances, durserv_max_samples_per_instance
        )

        entityType = EntityType(entityTypeInteger)

        if entityType == EntityType.WRITER:
            self.publish(qos)
        elif entityType == EntityType.READER:
            self.subscibe(qos)


class ShapeDynamicThread(QThread):

    def __init__(self, domainParticipant, qos, shapeType: str, color: str, size: int, speed: int, parent=None):
        super().__init__()
        self.running = False
        self.domain_participant = domainParticipant
        self.qos = qos
        self.shapeType = shapeType
        self.color = color
        self.size = size
        self.speed = speed

    def run(self):
        self.running = True
        try:
            topic = Topic(self.domain_participant, self.shapeType, ishape.ShapeType, self.qos)
            publisher = Publisher(self.domain_participant, self.qos)
            writer = DataWriter(publisher, topic, self.qos)
            shape = ishape.ShapeType(self.color, 0, 0, self.size)
            widthBound = 266
            heightBound = 234
            angle = random.uniform(0.0, 1.0)
            alpha = random.uniform(0.0, 1.0)

            while self.running:
                shape.x = round(shape.x + self.speed * math.cos(angle))
                shape.y = round(shape.y + self.speed * math.sin(angle))

                if shape.x <= 0:
                    angle = -alpha if self.flip() else alpha
                    shape.x = 0
                elif shape.x >= widthBound:

                    angle = -alpha if self.flip() else math.pi - alpha
                    shape.x = widthBound
                elif shape.y <= 0:
                    angle = -alpha if self.flip() else math.pi - alpha
                    shape.y = 0
                elif shape.y >= heightBound:
                    angle = -alpha if self.flip() else math.pi + alpha
                    shape.y = heightBound

                writer.write(shape)
                time.sleep(0.04)
        except Exception as e:
            logging.error(f"Error in ShapeDynamicThread: {e}")

    def flip(self):
        return random.random() <= 0.5

    def stop(self):
        self.running = False


class ShapeDispatcherThread(QThread):

    onData = Signal(str, str, object, bool)

    def __init__(self, domainParticipant, parent=None):
        super().__init__()
        self.domain_participant = domainParticipant
        self.waitset = None
        self.guardCondition = None
        self.running = False
        self.readerData = []

    @Slot()
    def addEndpoint(self, topic_name: str, topic_type, qos):
        try:
            topic = Topic(self.domain_participant, topic_name, topic_type, qos)
            subscriber = Subscriber(self.domain_participant, qos)
            reader = DataReader(subscriber, topic, qos)
            readCondition = core.ReadCondition(reader, SampleState.Any | ViewState.Any | InstanceState.Any)
            self.guardCondition.set(True)
            self.waitset.attach(readCondition)
            self.guardCondition.set(False)
            self.readerData.append((topic, subscriber, reader, readCondition))

            logging.info("Add endpoint ... DONE")

        except Exception as e:
            logging.error(f"Error creating endpoint {topic_name}: {e}")

    def run(self):
        self.running = True
        self.waitset = core.WaitSet(self.domain_participant)
        self.guardCondition = core.GuardCondition(self.domain_participant)
        self.waitset.attach(self.guardCondition)

        while self.running:
            try:
                self.waitset.wait(duration(infinite=True))
            except:
                pass

            for (topic, _, readItem, condItem) in self.readerData:
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
