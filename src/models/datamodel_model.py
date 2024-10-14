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

from PySide6.QtCore import Qt, QModelIndex, QAbstractListModel, Qt, QByteArray, QStandardPaths, QFile, QDir, QProcess, QThread
from PySide6.QtCore import QObject, Signal, Slot
import logging
import os
import sys
import importlib
import inspect
from pathlib import Path
import subprocess
import glob
import uuid
from dataclasses import dataclass
import typing
from dds_service import WorkerThread
from dds_data import DdsData
from cyclonedds.core import Qos, Policy
from cyclonedds.util import duration


@dataclass
class DataModelItem:
    id: str
    parts: dict


class DatamodelModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    newDataArrived = Signal(str)
    isLoadingSignal = Signal(bool)
    requestDataType = Signal(str, int, str, str)

    def __init__(self, parent=typing.Optional[QObject]) -> None:
        super().__init__()
        self.ddsData = DdsData()
        self.requestDataType.connect(self.ddsData.requestDataType)
        self.ddsData.response_data_type_signal.connect(self.receiveDataType)
        self.idlcWorker = None
        self.dataModelItems = {}
        self.threads = {}
        self.app_data_dir = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
        self.datamodel_dir = os.path.join(self.app_data_dir, "datamodel")
        self.destination_folder_idl = os.path.join(self.datamodel_dir, "idl")
        self.destination_folder_py = os.path.join(self.datamodel_dir, "py")
        self.readerRequests = {}

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> typing.Any:
        if not index.isValid():
            return None
        row = index.row()
        if role == self.NameRole:
            return str(list(self.dataModelItems.keys())[row])
        elif False:
            pass

        return None

    def roleNames(self) -> typing.Dict[int, QByteArray]:
        return {
            self.NameRole: b'name'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return len(self.dataModelItems.keys())

    def execute_command(self, command, cwd):
        logging.debug("start executing command ...")
        try:
            # Run the command and capture stdout, stderr
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, cwd=cwd)
            stdout, stderr = process.communicate()
            logging.debug("command executed, eval result.")

            # Check if there was an error
            if process.returncode != 0:
                logging.debug("Error occurred:")
                logging.debug(stdout.decode("utf-8"))
                logging.debug(stderr.decode("utf-8"))
                return None

            logging.debug("Command Done,")
            logging.debug(stdout.decode("utf-8"))
            logging.debug(stderr.decode("utf-8"))

        except Exception as e:
            logging.debug("An error occurred:", e)

    @Slot(list)
    def addUrls(self, urls):
        if self.idlcWorker:
            return

        logging.info("add urls:" + str(urls))

        self.isLoadingSignal.emit(True)

        self.idlcWorker = IdlcWorkerThread(urls, self.destination_folder_py, self.destination_folder_idl)
        self.idlcWorker.doneSignale.connect(self.idlcWorkerDone)
        self.idlcWorker.start()

    @Slot()
    def idlcWorkerDone(self):
        self.loadModules()
        self.idlcWorker = None
        self.isLoadingSignal.emit(False)

    @Slot()
    def clear(self):
        self.beginResetModel()
        self.delete_folder(self.datamodel_dir)
        self.dataModelItems.clear()
        self.endResetModel()

    def delete_folder(self, folder_path):
        dir = QDir(folder_path)
        if dir.exists():
            success = dir.removeRecursively()
            if success:
                logging.info(f"Successfully deleted folder: {folder_path}")
            else:
                logging.error(f"Failed to delete folder: {folder_path}")
        else:
            logging.error(f"Folder does not exist: {folder_path}")

    @Slot()
    def loadModules(self):
        logging.debug("")

        dir = QDir(self.destination_folder_py)
        if not dir.exists():
            return

        parent_dir = self.destination_folder_py
        sys.path.insert(0, parent_dir)

        # Structs without any module, can only appear on root level
        py_files = [f for f in os.listdir(parent_dir) if f.endswith('.py')]
        for py_file in py_files:            
            module_name = Path(py_file).stem
            try:
                module = importlib.import_module(module_name)
                self.add_idl_without_module(module)
            except Exception as e:
                logging.error(f"Error importing {module_name}")

        submodules = [name for name in os.listdir(parent_dir) if os.path.isdir(os.path.join(parent_dir, name))]
        for submodule in submodules:
            self.import_module_and_nested(submodule)

    def import_module_and_nested(self, module_name):
        try:
            module = importlib.import_module(module_name)
            all_types = getattr(module, '__all__', [])
            for type_name in all_types:
                try:
                    cls = getattr(module, type_name)
                    if inspect.isclass(cls):
                        if not self.has_nested_annotation(cls) and not self.is_enum(cls):
                            sId: str = f"{module_name}::{cls.__name__}".replace(".", "::")
                            if sId not in self.dataModelItems:
                                self.beginInsertRows(QModelIndex(), self.rowCount(), self.rowCount())
                                self.dataModelItems[sId] = DataModelItem(sId, [module_name, cls.__name__])
                                self.endInsertRows()
                    elif inspect.ismodule(cls):
                        self.import_module_and_nested(cls.__name__)
                except Exception as e:
                    logging.error(f"Error importing {module_name} : {type_name} : {e}")
        except Exception as e:
            logging.error(f"Error importing {module_name}: {e}")

    def has_nested_annotation(self, cls):
        return 'nested' in getattr(cls, '__idl_annotations__', {})

    def is_enum(self, cls):
        return getattr(cls, '__doc__', None) == "An enumeration."

    def print_class_attributes(self, cls):
        logging.debug(f"Attributes of class {cls.__name__}:")
        for attr_name in dir(cls):
            logging.debug(f"  {attr_name}: {getattr(cls, attr_name)}")

    def add_idl_without_module(self, module):
        classes = [getattr(module, name) for name in dir(module) if isinstance(getattr(module, name), type)]
        for cls in classes:
            if not self.has_nested_annotation(cls) and "(IdlStruct" in str(cls):
                sId: str = f"{module.__name__}::{cls.__name__}"
                if sId not in self.dataModelItems:
                    self.beginInsertRows(QModelIndex(), self.rowCount(), self.rowCount())
                    self.dataModelItems[sId] = DataModelItem(sId, [module.__name__, cls.__name__])
                    self.endInsertRows()

    @Slot(int, str, str, str, str, str, int, bool, bool, list, str, bool, bool, bool, bool, bool, bool, str, int, str, str, int, int, int, int, int, str, bool, bool, bool, int, int, int, int, int, int, int, str, str, str, str, str, str, str, str, int, str, int, int, int, int)
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
        durserv_max_samples, durserv_max_instances, durserv_max_samples_per_instance):

        logging.debug("try add reader " + str(domain_id) + " " + str(topic_name) + " " + str(topic_type))

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

        if topic_type in self.dataModelItems:
            module_type = importlib.import_module(self.dataModelItems[topic_type].parts[0])
            class_type = getattr(module_type, self.dataModelItems[topic_type].parts[1])

            logging.debug(str(module_type))
            logging.debug(str(class_type))
            self.createReader(domain_id, topic_name, class_type, qos)
        else:
            typeRequestId = str(uuid.uuid4())
            self.readerRequests[typeRequestId] = (domain_id, topic_type, topic_name, qos)
            self.requestDataType.emit(typeRequestId, domain_id, topic_type, topic_name)

    def createReader(self, domainId, topicName, dataType, qos):
        logging.debug(f"add reader with qos: {str(qos)}")

        if domainId in self.threads:
            self.threads[domainId].receive_data(topicName, dataType, qos)
        else:
            self.threads[domainId] = WorkerThread(domainId, topicName, dataType, qos)
            self.threads[domainId].data_emitted.connect(self.received_data, Qt.ConnectionType.QueuedConnection)
            self.threads[domainId].start()

    @Slot(str, object)
    def receiveDataType(self, requestId, dataType):
        if requestId in self.readerRequests:
            (domain_id, topic_type, topic_name, qos) = self.readerRequests[requestId]
            self.createReader(domain_id, topic_name, dataType, qos)
            del self.readerRequests[requestId]

    @Slot(str)
    def received_data(self, data: str):
        self.newDataArrived.emit(data)

    @Slot()
    def deleteAllReaders(self):
        for key in list(self.threads.keys()):
            if self.threads[key]:
                self.threads[key].stop()
                self.threads[key].wait()
        self.threads.clear()


class IdlcWorkerThread(QThread):

    doneSignale = Signal()
    
    def __init__(self, urls, destination_folder_py, destination_folder_idl, parent=None):
        super().__init__(parent)
        self.urls = urls
        self.destination_folder_idl = destination_folder_idl
        self.destination_folder_py = destination_folder_py

    def run(self):
        for url in self.urls:
            logging.debug("Copy " + str(url) + " ...")
            if url.isLocalFile():
                # Copy idl source file
                source_file = url.toLocalFile()
                logging.debug("IDL-Folder: " + self.destination_folder_idl)
                if not QDir(self.destination_folder_idl).exists():
                    QDir().mkpath(self.destination_folder_idl)

                destination_file = os.path.join(self.destination_folder_idl, os.path.basename(source_file))

                if (QFile.exists(destination_file)):
                    QFile.remove(destination_file)

                if QFile.copy(source_file, destination_file):
                    logging.debug("File copied successfully. " + os.path.basename(source_file))
                else:
                    logging.error("Failed to copy file.")
                    break

        parent_dir = self.destination_folder_idl
        idls = [name for name in os.listdir(parent_dir) if os.path.isfile(os.path.join(parent_dir, name))]

        for idl in idls:
            logging.debug("Process " + idl + " ...")

            destination_file = os.path.join(self.destination_folder_idl, idl)

            # Compile idl to py file
            if not QDir(self.destination_folder_py).exists():
                QDir().mkpath(self.destination_folder_py)

            arguments = ["-l"]
            application_path = "./"

            if getattr(sys, 'frozen', False):
                # Bundled as App - use idlc and _idlpy from app binaries
                application_path = sys._MEIPASS
                search_pattern = os.path.join(application_path, "_idlpy.*")
                matching_files = glob.glob(search_pattern)
                matching_files.sort()
                if matching_files:
                    arguments.append(os.path.normpath(matching_files[0]))
                    logging.debug("Found _idlpy: " + matching_files[0])
                else:
                    logging.critical("No _idlpy lib found")
            else:
                arguments.append("py")
                # Started as python program
                #   - use idlc from cyclonedds_home
                #   - use _idlpy from pip package
                if "CYCLONEDDS_HOME" in os.environ:
                    application_path = os.environ["CYCLONEDDS_HOME"] + "/bin"

            arguments.append("-o")
            arguments.append(os.path.normpath(self.destination_folder_py))
            arguments.append(os.path.normpath(destination_file))

            command = os.path.normpath(f"{application_path}/idlc")

            logging.info("Execute: " + command + " " + " ".join(arguments))

            process = QProcess()
            process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
            process.setWorkingDirectory(self.destination_folder_py)
            process.start(command, arguments)

            if process.waitForFinished():
                if process.exitStatus() == QProcess.NormalExit:
                    logging.debug(str(process.readAll()))
                    logging.debug("Process finished successfully.") 
                else:
                    logging.debug("Process failed with error code: " + str(process.exitCode()))
            else:
                logging.debug("Failed to start process:" + str(process.errorString()))

        self.doneSignale.emit()
