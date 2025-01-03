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
from PySide6.QtCore import QObject, Signal, Slot
import logging
import typing
import uuid
from dds_access.Dispatcher import DispatcherThread
from dds_access.dds_data import DdsData
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration
from utils import EntityType
from ModuleHandler import DataModelHandler


class DatamodelModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    newDataArrived = Signal(str)
    isLoadingSignal = Signal(bool)
    requestDataType = Signal(str, int, str, str)

    newWriterSignal = Signal(str, int, str, str, str, str)

    def __init__(self, threads, dataModelHandler, parent=typing.Optional[QObject]) -> None:
        super().__init__()
        self.dataModelHandler: DataModelHandler = dataModelHandler
        self.dataModelHandler.isLoadingSignal.connect(self.moduleHanlderIsLoading)
        self.dataModelHandler.beginInsertModuleSignal.connect(self.beginInsertModule)
        self.dataModelHandler.endInsertModuleSignal.connect(self.endInsertModule)

        self.ddsData = DdsData()
        self.requestDataType.connect(self.ddsData.requestDataType)
        self.ddsData.response_data_type_signal.connect(self.receiveDataType)

        self.threads = threads
        self.readerRequests = {}

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> typing.Any:
        if not index.isValid():
            return None
        row = index.row()
        if role == self.NameRole:
            return self.dataModelHandler.getName(row)
        return None

    def roleNames(self) -> typing.Dict[int, QByteArray]:
        return {
            self.NameRole: b'name'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return self.dataModelHandler.count()

    @Slot()
    def loadModules(self):
        self.dataModelHandler.loadModules()

    @Slot(list)
    def addUrls(self, urls):
        self.dataModelHandler.addUrls(urls)

    @Slot(bool)
    def moduleHanlderIsLoading(self, loading: bool):
        self.isLoadingSignal.emit(loading)

    @Slot()
    def clear(self):
        self.beginResetModel()
        self.dataModelHandler.clear()
        self.endResetModel()

    @Slot(int)
    def beginInsertModule(self, position):
        self.beginInsertRows(QModelIndex(), position, position)

    @Slot()
    def endInsertModule(self):
        self.endInsertRows()

    @Slot(str)
    def onData(self, data: str):
        self.newDataArrived.emit(data)

    @Slot()
    def deleteAllReaders(self):
        for key in list(self.threads.keys()):
            self.threads[key].deleteAllReaders()

    @Slot()
    def shutdownEndpoints(self):
        for key in list(self.threads.keys()):
            self.threads[key].stop()
            self.threads[key].wait()
        self.threads.clear()

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
    def addReader(self, domain_id, topic_name, topic_type,
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

        logging.debug("add endpoint request" + str(domain_id) + " " + str(topic_name) + " " + str(topic_type))

        qos = Qos()

        if q_own == "DDS_OWNERSHIP_SHARED":
            qos += Qos(Policy.Ownership.Shared)
        elif q_own == "DDS_OWNERSHIP_EXCLUSIVE":
            qos += Qos(Policy.Ownership.Exclusive)

        if q_dur == "DDS_DURABILITY_VOLATILE":
            qos += Qos(Policy.Durability.Volatile)
        elif q_dur == "DDS_DURABILITY_TRANSIENT_LOCAL":
            qos += Qos(Policy.Durability.TransientLocal)
        elif q_dur == "DDS_DURABILITY_TRANSIENT":
            qos += Qos(Policy.Durability.Transient)
        elif q_dur == "DDS_DURABILITY_PERSISTENT":
            qos += Qos(Policy.Durability.Persistent)

        if q_rel == "DDS_RELIABILITY_BEST_EFFORT":
            qos += Qos(Policy.Reliability.BestEffort)
        elif q_rel == "DDS_RELIABILITY_RELIABLE":
            qos += Qos(Policy.Reliability.Reliable(max_blocking_time=duration(milliseconds=q_rel_max_block_msec)))

        if len(partitions) > 0:
            qos += Qos(Policy.Partition(partitions=partitions))

        if q_xcdr1 or q_xcdr2:
            qos += Qos(Policy.DataRepresentation(use_cdrv0_representation=q_xcdr1, use_xcdrv2_representation=q_xcdr2))

        if type_consis == "AllowTypeCoercion":
            qos += Qos(Policy.TypeConsistency.AllowTypeCoercion(
                ignore_sequence_bounds=ig_seq_bnds,
                ignore_string_bounds=ig_str_bnds,
                ignore_member_names=ign_mem_nam,
                prevent_type_widening=prev_ty_wide,
                force_type_validation=fore_type_vali))
        elif type_consis == "DisallowTypeCoercion":
            qos += Qos(Policy.TypeConsistency.DisallowTypeCoercion(force_type_validation=fore_type_vali_allow))

        if history == "KeepAll":
            qos += Qos(Policy.History.KeepAll)
        elif history == "KeepLast":
            qos += Qos(Policy.History.KeepLast(history_keep_last_nr))

        if destination_order == "ByReceptionTimestamp":
            qos += Qos(Policy.DestinationOrder.ByReceptionTimestamp)
        elif destination_order == "BySourceTimestamp":
            qos += Qos(Policy.DestinationOrder.BySourceTimestamp)

        liveliness_duration = duration(seconds=liveliness_seconds) if liveliness_seconds >= 0 else duration(infinite=True)
        if liveliness == "Automatic":
            qos += Qos(Policy.Liveliness.Automatic(liveliness_duration))
        elif liveliness == "ManualByParticipant":
            qos += Qos(Policy.Liveliness.ManualByParticipant(liveliness_duration))
        elif liveliness == "ManualByTopic":
            qos += Qos(Policy.Liveliness.ManualByTopic(liveliness_duration))

        qos += Qos(Policy.Lifespan(duration(seconds=lifespan_seconds) if lifespan_seconds >= 0 else duration(infinite=True)))
        qos += Qos(Policy.Deadline(duration(seconds=deadline_seconds) if deadline_seconds >= 0 else duration(infinite=True)))
        qos += Qos(Policy.LatencyBudget(duration(seconds=latencybudget_seconds) if latencybudget_seconds >= 0 else duration(infinite=True)))
        qos += Qos(Policy.OwnershipStrength(owner_strength))

        if presentation_access_scope == "Instance":
            qos += Qos(Policy.PresentationAccessScope.Instance(coherent_access=pres_acc_scope_coherent, ordered_access=pres_acc_scope_ordered))
        elif presentation_access_scope == "Topic":
            qos += Qos(Policy.PresentationAccessScope.Topic(coherent_access=pres_acc_scope_coherent, ordered_access=pres_acc_scope_ordered))
        elif presentation_access_scope == "Group":
            qos += Qos(Policy.PresentationAccessScope.Group(coherent_access=pres_acc_scope_coherent, ordered_access=pres_acc_scope_ordered))

        qos += Qos(Policy.WriterDataLifecycle(autodispose=writer_life_autodispose))

        qos += Qos(Policy.ReaderDataLifecycle(
            autopurge_nowriter_samples_delay=duration(seconds=reader_life_nowriter_delay) if reader_life_nowriter_delay >= 0 else duration(infinite=True),
            autopurge_disposed_samples_delay=duration(seconds=reader_life_disposed) if reader_life_disposed >= 0 else duration(infinite=True)
        ))

        qos += Qos(Policy.TransportPriority(transport_prio))
        qos += Qos(Policy.ResourceLimits(
            max_samples=limit_max_samples, max_instances=limit_max_instances, max_samples_per_instance=limit_max_samples_per_instance))
        qos += Qos(Policy.TimeBasedFilter(filter_time=duration(seconds=timebased_filter_time_sec)))

        if ignore_local == "Nothing":
            qos += Qos(Policy.IgnoreLocal.Nothing)
        elif ignore_local == "Participant":
            qos += Qos(Policy.IgnoreLocal.Participant)
        elif ignore_local == "Process":
            qos += Qos(Policy.IgnoreLocal.Process)

        if user_data:
            qos += Qos(Policy.Userdata(data=user_data.encode('utf-8')))

        if group_data:
            qos += Qos(Policy.Groupdata(data=group_data.encode('utf-8')))

        if entity_name:
            qos += Qos(Policy.EntityName(name=entity_name))

        if prop_name and prop_value:
            qos += Qos(Policy.Property(key=prop_name, value=prop_value))

        if bin_prop_name and bin_prop_value:
            qos += Qos(Policy.BinaryProperty(key=bin_prop_name, value=bin_prop_value.encode('utf-8')))

        qos += Qos(Policy.DurabilityService(
            cleanup_delay=duration(minutes=durserv_cleanup_delay_minutes) if durserv_cleanup_delay_minutes >= 0 else duration(infinite=True),
            history=Policy.History.KeepLast(durserv_history_keep_last_nr) if durserv_history == "KeepLast" else Policy.History.KeepAll,
            max_samples=durserv_max_samples,
            max_instances=durserv_max_instances,
            max_samples_per_instance=durserv_max_samples_per_instance))

        entityType = EntityType(entityTypeInteger)

        if self.dataModelHandler.hasType(topic_type):
            module_type, class_type = self.dataModelHandler.getType(topic_type)

            logging.debug(str(module_type))
            logging.debug(str(class_type))
            self.createEndpoint(domain_id, topic_name, class_type, qos, entityType, topic_type)
        else:
            typeRequestId = str(uuid.uuid4())
            self.readerRequests[typeRequestId] = (domain_id, topic_type, topic_name, qos, entityType)
            self.requestDataType.emit(typeRequestId, domain_id, topic_type, topic_name)

    @Slot(str, object)
    def receiveDataType(self, requestId, dataType):
        if requestId in self.readerRequests:
            (domain_id, topic_type, topic_name, qos, entityType) = self.readerRequests[requestId]
            self.createEndpoint(domain_id, topic_name, dataType, qos, entityType, topic_type)
            del self.readerRequests[requestId]

    def createEndpoint(self, domainId: int, topicName: str, dataType, qos, entityType: EntityType, topic_type):
        logging.debug(f"add endpoint with qos: {str(qos)}")

        print("----------->>>>>>>><", domainId, topicName, dataType, qos, entityType, topic_type)

        id = "m" + str(uuid.uuid4()).replace("-", "_")

        if domainId in self.threads:
            self.threads[domainId].addEndpoint(id, topicName, dataType, qos, entityType)
        else:
            self.threads[domainId] = DispatcherThread(id, domainId, topicName, dataType, qos, entityType)
            self.threads[domainId].onData.connect(self.onData, Qt.ConnectionType.QueuedConnection)
            self.threads[domainId].start()

        # Add to Tester tab
        if entityType == EntityType.WRITER:
            self.newWriterSignal.emit(id, domainId, topicName, topic_type, "", "")

        logging.debug("try add endpoint ... DONE")
