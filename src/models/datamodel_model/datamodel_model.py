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
from dds_access.qos_provider_utils import (
    get_qos_provider_keys,
    load_qos_from_provider,
)
from cyclonedds.core import Qos
from dds_access.datatypes.entity_type import EntityType
from module_handler import DataModelHandler
from utils.qml_utils import QmlUtils
import time
from pathlib import Path


class DatamodelModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    newDataArrived = Signal(
        str, str, str, bool, str, str, str, str, str, str, str, str, str, str,
        str
    )
    isLoadingSignal = Signal(bool)
    requestDataType = Signal(str, int, str, str)
    newWriterSignal = Signal(str, int, str, str, object)
    newReaderSignal = Signal(str, int, str, str, object)
    qosProviderError = Signal(str)
    operationError = Signal(str)

    def __init__(self, threads, dataModelHandler, parent=typing.Optional[QObject]) -> None:
        super().__init__()
        self.dataModelHandler: DataModelHandler = dataModelHandler
        self.dataModelHandler.isLoadingSignal.connect(self.moduleHanlderIsLoading)
        self.dataModelHandler.beginInsertModuleSignal.connect(self.beginInsertModule)
        self.dataModelHandler.endInsertModuleSignal.connect(self.endInsertModule)
        self.dataModelHandler.operationError.connect(self.operationError.emit)

        self.ddsData = DdsData()
        self.requestDataType.connect(self.ddsData.requestDataType)
        self.ddsData.response_data_type_signal.connect(self.receiveDataType)

        self.threads = threads
        self.readerRequests = {}
        self.pendingEndpoints = {}

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

    @Slot(str, str, str, bool, str, str, str, str, str, int, str, str, str)
    def onData(self, _id: str, data: str, sample_info: str, valid_data: bool,
               source_timestamp: str, transmission_time: str,
               received_timestamp: str, writer_id: str, reader_id: str,
               domain_id: int, writer_participant_id: str, topic_type: str,
               topic_name: str):
        participant = None
        if domain_id in self.ddsData.the_domains:
            participant = self.ddsData.the_domains[domain_id].getParticipantByKey(
                writer_participant_id
            )

        process_name = dds_utils.getProperty(participant, dds_utils.PROCESS_NAMES)
        if process_name != "Unknown":
            process_name = Path(process_name.replace("\\", os.path.sep)).stem
        hostname = dds_utils.getHostname(participant)
        process_id = dds_utils.getProperty(participant, dds_utils.PIDS)
        addresses = dds_utils.getProperty(participant, dds_utils.ADDRESSES)

        self.newDataArrived.emit(
            _id, data, sample_info, valid_data, source_timestamp,
            transmission_time, received_timestamp, writer_id, reader_id,
            process_name, hostname, process_id, addresses, topic_type, topic_name
        )

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

        id = "m" + str(uuid.uuid4()).replace("-", "_")
        self.handleEndpointCreation(id, domain_id, topic_name, topic_type, qos, entityType)

    @Slot(int, str, str, int, str, str, result=bool)
    def setQosProviderSelection(
            self, domain_id, topic_name, topic_type, entityTypeInteger,
            file_path, profile_key):
        try:
            entityType = EntityType(entityTypeInteger)
            qos = load_qos_from_provider(
                file_path, profile_key, entityType
            )
            endpointId = "m" + str(uuid.uuid4()).replace("-", "_")
            self.handleEndpointCreation(
                endpointId, domain_id, topic_name, topic_type, qos, entityType
            )
            return True
        except Exception as error:
            message = f"Failed to load QoS provider: {error}"
            logging.error(message)
            self.qosProviderError.emit(message)
            return False

    @Slot(str, int, result=list)
    def getQosProviderKeys(self, file_path, entityTypeInteger):
        return get_qos_provider_keys(
            file_path, EntityType(entityTypeInteger)
        )

    def handleEndpointCreation(self, mId, domain_id, topic_name, topic_type, qos, entityType):
        if self.dataModelHandler.hasType(topic_type):
            class_type = self.dataModelHandler.getType(topic_type)

            logging.debug(str(class_type))
            self.createEndpoint(mId, domain_id, topic_name, class_type, qos, entityType, topic_type)
        else:
            typeRequestId = str(uuid.uuid4())
            self.readerRequests[typeRequestId] = (mId, domain_id, topic_type, topic_name, qos, entityType)
            self.requestDataType.emit(typeRequestId, domain_id, topic_type, topic_name)

    @Slot(str, int, str, str, int, str, object, object)
    def createEndpointFromTester(self, _id, domainId, topic_name, topic_type, entityType, presetName, messageRoot, allQosDict):
        try:
            logging.debug("add endpoint request" + str(domainId) + " " + str(topic_name) + " " + str(topic_type) + " with qos: " + str(allQosDict))
            dpQos = Qos()
            topicQos = Qos.fromdict(allQosDict.get("topic_qos", {}))
            endpointQos = Qos.fromdict(allQosDict.get("endpoint_qos", {}))
            pubSubQos = Qos.fromdict(allQosDict.get(
                "publisher_qos", allQosDict.get("subscriber_qos", {})
            ))
            self.handleEndpointCreation(_id, domainId, topic_name, topic_type,
                                        (dpQos, topicQos, pubSubQos, endpointQos),
                                        EntityType(entityType))
        except Exception as error:
            message = f"Failed to create endpoint '{topic_name}': {error}"
            logging.error(message)
            self.operationError.emit(message)

    @Slot(str, int)
    def setQosSelectionFromFile(self, filePath: str, entityType: int):
        try:
            self._setQosSelectionFromFile(filePath, entityType)
        except Exception as error:
            message = f"Cannot import listener preset '{os.path.basename(filePath)}': {error}"
            logging.error(message)
            self.operationError.emit(message)

    def _setQosSelectionFromFile(self, filePath: str, entityType: int):
        logging.info(f"Import preset from {filePath}")
        if not os.path.isfile(filePath):
            raise FileNotFoundError(filePath)
            return

        with open(filePath, "r", encoding="utf-8") as f:
            content = f.read()
            j = json.loads(content)

            presets = j.get("presets", [])
            for preset in presets:
                _id = preset.get("id", str(uuid.uuid4()))
                domainId = preset.get("domain_id", 0)
                topic_name = preset.get("topic_name", "")
                topic_type = preset.get("topic_type", "")

                if "qos" in preset:
                    allQosDict = preset["qos"]

                    dpQos = Qos()

                    topicQos = Qos.fromdict(allQosDict.get("topic_qos", {}))
                    endpointQos = Qos.fromdict(allQosDict.get("endpoint_qos", {}))
                    pubSubQos = Qos.fromdict(allQosDict.get(
                        "publisher_qos", allQosDict.get("subscriber_qos", {})
                    ))

                    self.handleEndpointCreation(_id, domainId, topic_name, topic_type, (dpQos, topicQos, pubSubQos, endpointQos), EntityType(entityType))

    @Slot(str, object)
    def receiveDataType(self, requestId, dataType):
        if requestId in self.readerRequests:
            if dataType is not None:
                (_id, domain_id, topic_type, topic_name, qos, entityType) = self.readerRequests[requestId]
                self.dataModelHandler.addTypeFromNetwork(topic_type, dataType)
                self.createEndpoint(_id, domain_id, topic_name, dataType, qos, entityType, topic_type)
            else:
                message = f"Failed to retrieve datatype '{self.readerRequests[requestId][2]}' from the network."
                logging.error(message)
                self.operationError.emit(message)

            del self.readerRequests[requestId]

    def createEndpoint(self, id, domainId: int, topicName: str, dataType, qos, entityType: EntityType, topic_type):
        logging.debug(f"add endpoint with qos: {str(qos)}")

        self.pendingEndpoints[id] = (domainId, topicName, topic_type, qos, entityType)
        if domainId in self.threads:
            self.threads[domainId].addEndpoint(id, topicName, dataType, qos, entityType)
        else:
            self.threads[domainId] = DispatcherThread(id, domainId, topicName, dataType, qos, entityType)
            self.threads[domainId].onData.connect(self.onData, Qt.ConnectionType.QueuedConnection)
            self.threads[domainId].endpointCreated.connect(self.endpointCreated)
            self.threads[domainId].endpointCreationFailed.connect(self.endpointCreationFailed)
            self.threads[domainId].start()
            while not self.threads[domainId].isSetUpDone():
                logging.debug("Waiting for worker thread to set up...")
                time.sleep(0.01)

        logging.debug("Endpoint creation requested")

    @Slot(str)
    def endpointCreated(self, id):
        pending = self.pendingEndpoints.pop(id, None)
        if pending is None:
            return
        (domainId, topicName, topic_type, qos, entityType) = pending
        (dpQos, topicQos, pubSubQos, endpointQos) = qos
        qosDict = {
            "domain_partition_qos": dpQos.asdict(),
            "topic_qos": topicQos.asdict(),
            "endpoint_qos": endpointQos.asdict(),
            "publisher_qos": pubSubQos.asdict(),
            "subscriber_qos": pubSubQos.asdict()
        }

        # Add to Tester tab
        if entityType == EntityType.WRITER:
            self.newWriterSignal.emit(id, domainId, topicName, topic_type, qosDict)
        if entityType == EntityType.READER:
            self.newReaderSignal.emit(id, domainId, topicName, topic_type, qosDict)

        logging.debug("add endpoint ... DONE")

    @Slot(str, str)
    def endpointCreationFailed(self, id, message):
        self.pendingEndpoints.pop(id, None)
        self.operationError.emit(message)

    @Slot(str)
    def exportListenerPresets(self, filePath: str):
        logging.info(f"Export listener presets to {filePath}")

        exportData = { "presets": [] }
        for _, dspThread in self.threads.items():
            for (_, topic, subscriber, reader, _) in dspThread.readerData:
                exportData["presets"].append({
                    "domain_id": dspThread.domain_id,
                    "topic_name": topic.name,
                    "topic_type": topic.typename,
                    "qos": {
                        "topic_qos": topic.get_qos().asdict(),
                        "subscriber_qos": subscriber.get_qos().asdict(),
                        "endpoint_qos": reader.get_qos().asdict()
                    }
                })

        qmlUtils = QmlUtils()
        if not qmlUtils.saveFileContent(filePath, json.dumps(exportData, indent=4)):
            self.operationError.emit(f"Could not export listener presets to '{filePath}'.")
