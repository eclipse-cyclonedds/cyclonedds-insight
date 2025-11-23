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
from loguru import logger as logging
import typing
import uuid
import os
import json
from dds_access.dispatcher import DispatcherThread
from dds_access.dds_data import DdsData
from dds_access import dds_utils
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration
from dds_access.datatypes.entity_type import EntityType
from module_handler import DataModelHandler


class DatamodelModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    newDataArrived = Signal(str)
    isLoadingSignal = Signal(bool)
    requestDataType = Signal(str, int, str, str)
    newWriterSignal = Signal(str, int, str, str, str, str, str, object)

    untitiledCount = 1

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

    @Slot(int, str, str, int,
        str, str, str, int, bool, bool, str, bool, bool, bool, bool, bool, bool, str, int, str, str, int, int, int, int, int, bool, int, int, int, int, int, int, int, str, str, str, str, str, bool, str, str, bool, int, str, int, int, int, int, 
        list, str, bool, bool, str,
        str, str, str, int, bool, bool, str, int, str, str, int, int, int, int, int, int, int, int, str, int, str, int, int, int, int,
        bool, str, bool)
    def setQosSelection(self, domain_id, topic_name, topic_type, entityTypeInteger,
        q_own, q_dur, q_rel, q_rel_max_block_msec, q_xcdr1, q_xcdr2, type_consis, ig_seq_bnds, ig_str_bnds, ign_mem_nam, prev_ty_wide, fore_type_vali, fore_type_vali_allow, history, history_keep_last_nr, destination_order, liveliness, liveliness_seconds, lifespan_seconds, deadline_seconds, latencybudget_seconds, owner_strength, writer_life_autodispose, reader_life_nowriter_delay, reader_life_disposed, transport_prio, limit_max_samples, limit_max_instances, limit_max_samples_per_instance, timebased_filter_time_sec, ignore_local, user_data, entity_name, prop_name, prop_value, prop_propagate, bin_prop_name, bin_prop_value, bin_prop_propagate, durserv_cleanup_delay_minutes, durserv_history, durserv_history_keep_last_nr, durserv_max_samples, durserv_max_instances, durserv_max_samples_per_instance,
        partitions, presentation_access_scope, pres_acc_scope_coherent, pres_acc_scope_ordered, pubSubGroupData,
        topicQosOwn, topicQosDur, topicQosRel, topicQosRelMaxBlockMsec, topicQosXcdr1, topicQosXcdr2, topicQosHistory, topicQosHistoryKeepLastNr, topicQosDestinationOrder, topicQosLiveliness, topicQosLivelinessSeconds, topicQosLifespanSeconds, topicQosDeadlineSeconds, topicQosLatencybudgetSeconds, topicQosTransportPrio, topicQosLimitMaxSamples, topicQosLimitMaxInstances, topicQosLimitMaxSamplesPerInstance, topicQosTopicData, topicQosDurservCleanupDelayMinutes, topicQosDurservHistory, topicQosDurservHistoryKeepLastNr, topicQosDurservMaxSamples, topicQosDurservMaxInstances, topicQosDurservMaxSamplesPerInstance,
        dpUseDefault, dpUserdataField, dpAutoEnable):

        logging.debug("add endpoint request" + str(domain_id) + " " + str(topic_name) + " " + str(topic_type))

        dpQps, topicQos, pubSubQos, endpQos = dds_utils.toQos(
            q_own, q_dur, q_rel, q_rel_max_block_msec, q_xcdr1, q_xcdr2, type_consis, ig_seq_bnds, ig_str_bnds, ign_mem_nam, prev_ty_wide, fore_type_vali, fore_type_vali_allow, history, history_keep_last_nr, destination_order, liveliness, liveliness_seconds, lifespan_seconds, deadline_seconds, latencybudget_seconds, owner_strength, writer_life_autodispose, reader_life_nowriter_delay, reader_life_disposed, transport_prio, limit_max_samples, limit_max_instances, limit_max_samples_per_instance, timebased_filter_time_sec, ignore_local, user_data, entity_name, prop_name, prop_value, prop_propagate, bin_prop_name, bin_prop_value, bin_prop_propagate, durserv_cleanup_delay_minutes, durserv_history, durserv_history_keep_last_nr, durserv_max_samples, durserv_max_instances, durserv_max_samples_per_instance,
            partitions, presentation_access_scope, pres_acc_scope_coherent, pres_acc_scope_ordered, pubSubGroupData,
            topicQosOwn, topicQosDur, topicQosRel, topicQosRelMaxBlockMsec, topicQosXcdr1, topicQosXcdr2, topicQosHistory, topicQosHistoryKeepLastNr, topicQosDestinationOrder, topicQosLiveliness, topicQosLivelinessSeconds, topicQosLifespanSeconds, topicQosDeadlineSeconds, topicQosLatencybudgetSeconds, topicQosTransportPrio, topicQosLimitMaxSamples, topicQosLimitMaxInstances, topicQosLimitMaxSamplesPerInstance, topicQosTopicData, topicQosDurservCleanupDelayMinutes, topicQosDurservHistory, topicQosDurservHistoryKeepLastNr, topicQosDurservMaxSamples, topicQosDurservMaxInstances, topicQosDurservMaxSamplesPerInstance,
            dpUserdataField, dpAutoEnable
        )
        qos = (dpQps, topicQos, pubSubQos, endpQos)
        entityType = EntityType(entityTypeInteger)

        self.handleEndpointCreation(domain_id, topic_name, topic_type, qos, entityType, f"Untitled-{DatamodelModel.untitiledCount}", {})
        DatamodelModel.untitiledCount += 1

    def handleEndpointCreation(self, domain_id, topic_name, topic_type, qos, entityType, presetName, msgDict):
        if self.dataModelHandler.hasType(topic_type):
            module_type, class_type = self.dataModelHandler.getType(topic_type)

            logging.debug(str(module_type))
            logging.debug(str(class_type))
            self.createEndpoint(domain_id, topic_name, class_type, qos, entityType, topic_type, presetName, msgDict)
        else:
            typeRequestId = str(uuid.uuid4())
            self.readerRequests[typeRequestId] = (domain_id, topic_type, topic_name, qos, entityType, presetName, msgDict)
            self.requestDataType.emit(typeRequestId, domain_id, topic_type, topic_name)

    @Slot(str)
    def setQosSelectionFromFile(self, filePath: str):
        logging.info(f"Import preset from {filePath}")
        if not os.path.isfile(filePath):
            logging.error(f"File does not exist: {filePath}")
            return

        with open(filePath, "r", encoding="utf-8") as f:
            content = f.read()
            j = json.loads(content)

            presets = j.get("presets", [])
            for preset in presets:
                presetName = preset.get("preset_name", "ImportedPreset")
                domainId = preset.get("domain_id", 0)
                topic_name = preset.get("topic_name", "")
                topic_type = preset.get("topic_type", "")
                message = preset.get("message", {"root": {}})

                if "qos" in preset:
                    allQosDict = preset["qos"]

                    dpQos = Qos()

                    if "topic_qos" in allQosDict:
                        topicQos = Qos.fromdict(allQosDict["topic_qos"])

                    if "endpoint_qos" in allQosDict:
                        endpointQos = Qos.fromdict(allQosDict["endpoint_qos"])

                    if "publisher_qos" in allQosDict:
                        publisherQos = Qos.fromdict(allQosDict["publisher_qos"])

                    self.handleEndpointCreation(domainId, topic_name, topic_type, (dpQos, topicQos, publisherQos, endpointQos), EntityType.WRITER, presetName, message["root"])

    @Slot(str, object)
    def receiveDataType(self, requestId, dataType):
        if requestId in self.readerRequests:
            (domain_id, topic_type, topic_name, qos, entityType, presetName, msgDict) = self.readerRequests[requestId]
            self.dataModelHandler.addTypeFromNetwork(topic_type, dataType)
            self.createEndpoint(domain_id, topic_name, dataType, qos, entityType, topic_type, presetName, msgDict)
            del self.readerRequests[requestId]

    def createEndpoint(self, domainId: int, topicName: str, dataType, qos, entityType: EntityType, topic_type, presetName: str, msgDict: dict):
        logging.debug(f"add endpoint with qos: {str(qos)}")

        id = "m" + str(uuid.uuid4()).replace("-", "_")

        if domainId in self.threads:
            self.threads[domainId].addEndpoint(id, topicName, dataType, qos, entityType)
        else:
            self.threads[domainId] = DispatcherThread(id, domainId, topicName, dataType, qos, entityType)
            self.threads[domainId].onData.connect(self.onData, Qt.ConnectionType.QueuedConnection)
            self.threads[domainId].start()

        # Add to Tester tab
        if entityType == EntityType.WRITER:
            self.newWriterSignal.emit(id, domainId, topicName, topic_type, "", "", presetName, msgDict)

        logging.debug("try add endpoint ... DONE")
