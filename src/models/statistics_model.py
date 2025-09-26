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

from PySide6.QtCore import Qt, QModelIndex, Qt, QThread, Signal, Slot, QAbstractTableModel, QLocale
from PySide6.QtGui import QColor
from loguru import logger as logging
import uuid
import requests
import json
from dds_access import dds_data
from cyclonedds.builtin import DcpsParticipant
from dds_access import dds_utils
from dds_access.dds_utils import getProperty, DEBUG_MONITORS, getAppName, getHostname
import random
import colorsys
import datetime
import time
from threading import Lock


class PollingThread(QThread):

    onData = Signal(str, object, object)
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__()
        self.running = False
        self.mutex = Lock()
        self.color_mapping = {}
        self.pollIntervalSeconds = 3
        self.aggregateBy = "writer"
        self.aggregateByRequest = self.aggregateBy
        self.dgbPorts = {}
        self.dgbPortsRequest = self.dgbPorts
        self.dgbPortChangeRequest = False

    def getRandomColor(self):
        h = random.random()
        s = random.uniform(0.5, 1.0)  # not too gray
        v = random.uniform(0.7, 1.0)  # not too dark
        r, g, b = colorsys.hsv_to_rgb(h, s, v)
        return (int(r * 255), int(g * 255), int(b * 255))

    def poll(self):
        logging.trace("Debug monitor timer triggered")

        ag_sent_bytes = {}
        ag_received_bytes = {}
        ag_rexmit_bytes = {}
        ag_n_nacks_received = {}
        ag_rexmit_count = {}
        ag_n_acks_received = {}
        ag_n_reliable_readers = {}

        already_processed_ip_port = []
        for participant_key in self.dgbPorts.keys():
            (ip, port, _, _, _) = self.dgbPorts[participant_key]
            if f"{ip}:{port}" in already_processed_ip_port:
                logging.trace(f"skip {ip}:{port} - already processed.")
                continue
            already_processed_ip_port.append(f"{ip}:{port}")

            json_data = {}
            try:
                url = "http://" + ip + ":" + port + "/"
                logging.trace(f"Downloading JSON from: {url}")
                headers = {
                    'Connection': 'close'
                }
                response = requests.get(url, timeout=(3, 5), verify=False, headers=headers)
                logging.trace(f"Response code: {str(response.status_code)}")
                response.raise_for_status()
                json_data = response.json()
                # logging.trace(json.dumps(json_data, indent=4))
            except Exception as e:
                logging.error(str(e))
                self.error.emit("[" + datetime.datetime.now().isoformat() + "] " + url + " " + str(e))
                continue

            if "participants" in json_data:
                for participant in json_data["participants"]:
                    pKeyCurrent = dds_utils.normalizeGuid(participant["guid"])
                    if pKeyCurrent not in self.dgbPorts:
                        logging.warning(f"{pKeyCurrent} not in dgbPorts")
                        continue

                    (_, _, appName, host, domainId) = self.dgbPorts[pKeyCurrent]

                    aggkey = "undefined"
                    if self.aggregateBy == "domain":
                        aggkey = str(domainId)
                    if self.aggregateBy == "process":
                        aggkey = appName
                    if self.aggregateBy == "host":
                        aggkey = host
                    if self.aggregateBy == "participant":
                        aggkey = pKeyCurrent

                    if "writers" in participant:
                        for writer in participant["writers"]:
                            if self.aggregateBy == "writer":
                                aggkey = dds_utils.normalizeGuid(writer["guid"])
                            if self.aggregateBy == "topic":
                                topic = writer["topic"]
                                aggkey = topic

                            if aggkey not in self.color_mapping:
                                self.color_mapping[aggkey] = self.getRandomColor()

                            if "rexmit_bytes" in writer:
                                if aggkey in ag_rexmit_bytes:
                                    ag_rexmit_bytes[aggkey] += writer["rexmit_bytes"]
                                else:
                                    ag_rexmit_bytes[aggkey] = writer["rexmit_bytes"]

                            if "sent_bytes" in writer:
                                if aggkey in ag_sent_bytes:
                                    ag_sent_bytes[aggkey] += writer["sent_bytes"]
                                else:
                                    ag_sent_bytes[aggkey] = writer["sent_bytes"]

                            if "ack" in writer:
                                ack = writer["ack"]
                                if "n_acks_received" in ack:
                                    if aggkey in ag_n_acks_received:
                                        ag_n_acks_received[aggkey] += ack["n_acks_received"]
                                    else:
                                        ag_n_acks_received[aggkey] = ack["n_acks_received"]
                                if "n_nacks_received" in ack:
                                    if aggkey in ag_n_nacks_received:
                                        ag_n_nacks_received[aggkey] += ack["n_nacks_received"]
                                    else:
                                        ag_n_nacks_received[aggkey] = ack["n_nacks_received"]
                                if "rexmit_count" in ack:
                                    if aggkey in ag_rexmit_count:
                                        ag_rexmit_count[aggkey] += ack["rexmit_count"]
                                    else:
                                        ag_rexmit_count[aggkey] = ack["rexmit_count"]

                            if "heartbeat" in writer:
                                heartbeat = writer["heartbeat"]
                                if "n_reliable_readers" in heartbeat:
                                    if aggkey in ag_n_reliable_readers:
                                        ag_n_reliable_readers[aggkey] += heartbeat["n_reliable_readers"]
                                    else:
                                        ag_n_reliable_readers[aggkey] = heartbeat["n_reliable_readers"]

                    if "readers" in participant:
                        for reader in participant["readers"]:
                            if self.aggregateBy == "reader":
                                aggkey = dds_utils.normalizeGuid(reader["guid"])
                            if self.aggregateBy == "topic":
                                topic = reader["topic"]
                                aggkey = topic

                            if aggkey not in self.color_mapping:
                                self.color_mapping[aggkey] = self.getRandomColor()

                            if "received_bytes" in reader:
                                if aggkey in ag_received_bytes:
                                    ag_received_bytes[aggkey] += reader["received_bytes"]
                                else:
                                    ag_received_bytes[aggkey] = reader["received_bytes"]

        self.onData.emit("sent_bytes", ag_sent_bytes.copy(), self.color_mapping.copy())
        self.onData.emit("received_bytes", ag_received_bytes.copy(), self.color_mapping.copy())
        self.onData.emit("rexmit_bytes", ag_rexmit_bytes.copy(), self.color_mapping.copy())
        self.onData.emit("n_acks_received", ag_n_acks_received.copy(), self.color_mapping.copy())
        self.onData.emit("n_nacks_received", ag_n_nacks_received.copy(), self.color_mapping.copy())
        self.onData.emit("rexmit_count", ag_rexmit_count.copy(), self.color_mapping.copy())
        self.onData.emit("n_reliable_readers", ag_n_reliable_readers.copy(), self.color_mapping.copy())


    def run(self):
        self.running = True

        start_time = time.monotonic()
        while self.running:

            if time.monotonic() - start_time >= self.pollIntervalSeconds:
                with self.mutex:
                    if self.aggregateByRequest != self.aggregateBy:
                        self.color_mapping.clear()
                        self.aggregateBy = self.aggregateByRequest
                    if self.dgbPortChangeRequest:
                        self.dgbPorts = self.dgbPortsRequest.copy()
                
                self.poll()
                start_time = time.monotonic()  # reset the timer
            else:
                time.sleep(0.1) # fast exit

        logging.trace("Statistics-Polling thread stopped")

    def stop(self):
        self.running = False

    def stillRunning(self):
        return self.running

    def setInterval(self, seconds):
        logging.trace(f"Set update interval to: {seconds} seconds")
        self.pollIntervalSeconds = seconds

    def setDbgPorts(self, dgbPorts):
        with self.mutex:
            self.dgbPortsRequest = dgbPorts.copy()
            self.dgbPortChangeRequest = True

    def setAggregation(self, aggre: str):
        with self.mutex:
            logging.trace(f"Set aggregateByRequest to: {aggre}")
            self.aggregateByRequest = aggre

    def changeColor(self, aggkey: str, color: QColor):
        with self.mutex:
            if aggkey in self.color_mapping:
                self.color_mapping[aggkey] = color.red(), color.green(), color.blue()


class StatisticsModel(QAbstractTableModel):

    newData = Signal(str, str, int, int, int, int)
    requestParticipants = Signal(str)
    statisticError = Signal(str)

    NameRole = Qt.UserRole + 1
    TableModelRole = Qt.UserRole + 2
    DescriptionRole = Qt.UserRole + 3
    UnitNameRole = Qt.UserRole + 4

    def roleNames(self):
        roles = {
            self.NameRole: b'name_role',
            self.TableModelRole: b'table_model_role',
            self.DescriptionRole: b'description_role',
            self.UnitNameRole: b'unit_name_role'
        }
        return roles

    def __init__(self, parent=None):
        super().__init__(parent)
        self.dgbPorts = {}
        self.data_list = {} 

        self.pollingThread = PollingThread(self)
        self.pollingThread.error.connect(self.statisticError)

        self.dds_data = dds_data.DdsData()
        self.requestParticipants.connect(self.dds_data.requestParticipants, Qt.ConnectionType.QueuedConnection)
        self.dds_data.new_participant_signal.connect(self.new_participant_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.response_participants_signal.connect(self.response_participants_slot, Qt.ConnectionType.QueuedConnection)
        self.dds_data.removed_participant_signal.connect(self.removed_participant_slot, Qt.ConnectionType.QueuedConnection)

        self.request_ids = []

        self.unitModels = {}
        self.unitModels["sent_bytes"] = StatisticsUnitModel(self.pollingThread, "sent_bytes")
        self.unitModels["received_bytes"] = StatisticsUnitModel(self.pollingThread, "received_bytes")
        self.unitModels["rexmit_bytes"] = StatisticsUnitModel(self.pollingThread, "rexmit_bytes")
        self.unitModels["rexmit_count"] = StatisticsUnitModel(self.pollingThread, "rexmit_count")
        self.unitModels["n_acks_received"] = StatisticsUnitModel(self.pollingThread, "n_acks_received")
        self.unitModels["n_nacks_received"] = StatisticsUnitModel(self.pollingThread, "n_nacks_received")
        self.unitModels["n_reliable_readers"] = StatisticsUnitModel(self.pollingThread, "n_reliable_readers")

        self.unitDescriptions = {
            "sent_bytes": {
                "description": "Total number of bytes sent by a writer (excluding retransmits).",
                "unit": "bytes"
            },
            "received_bytes": {
                "description": "Total number of bytes received by a reader (excluding retransmits).",
                "unit": "bytes"
            },
            "rexmit_bytes": {
                "description": "Total number of bytes retransmitted for a writer.",
                "unit": "bytes"
            },
            "n_acks_received": {
                "description": "Total number of ACKNACK messages not requesting a retransmit.",
                "unit": "ACKNACK"
            },
            "n_nacks_received": {
                "description": "Total number of ACKNACK messages requesting a retransmit.",
                "unit": "ACKNACK"
            },
            "rexmit_count": {
                "description": "Number of samples retransmitted (counts events, a single sample can count multiple times).",
                "unit": "Samples"
            },
            "n_reliable_readers": {
                "description": "the current number of matched reliable readers.",
                "unit": "Matched"   
            }
        }

    @Slot()
    def startStatistics(self):

        logging.info("Start statistics model")

        if self.pollingThread.isRunning():
            self.pollingThread.stop()
            self.pollingThread.wait()

        self.pollingThread.setDbgPorts(self.dgbPorts)
        self.pollingThread.start()

        reqId = str(uuid.uuid4())
        self.request_ids.append(reqId)
        self.requestParticipants.emit(reqId)

    def rowCount(self, parent=QModelIndex()):
        return len(self.unitModels)

    def columnCount(self, parent=QModelIndex()):
        return 1

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()
        if row >= len(self.unitModels):
            return None

        key = (list(self.unitModels.keys()))[row]
        item = self.unitModels[key]
    
        if role == self.NameRole:
            return key
        elif role == self.TableModelRole:
            return item
        elif role == self.DescriptionRole:
            if key in self.unitDescriptions:
                return self.unitDescriptions[key]["description"]
            else:
                return "n/a"
        elif role == self.UnitNameRole:
            if key in self.unitDescriptions:
                return self.unitDescriptions[key]["unit"]
            else:
                return "n/a"

        return None

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if role != Qt.DisplayRole:
            return None
        if orientation == Qt.Horizontal:
            headers = ["Name", "Value"]
            if section < len(headers):
                return headers[section]
        return None

    @Slot(int, DcpsParticipant)
    def new_participant_slot(self, domain_id: int, participant: DcpsParticipant):

        dbg_mon_str: str = getProperty(participant, DEBUG_MONITORS)
        appName: str = getAppName(participant)
        host: str = getHostname(participant)

        splitProtoAdr = dbg_mon_str.split("/")
        if len(splitProtoAdr) > 0:
            if splitProtoAdr[0] == "tcp":
                splitIpPort = splitProtoAdr[1].split(":")
                if len(splitIpPort) > 1:
                    ip = splitIpPort[0]
                    port = splitIpPort[1]
                    self.dgbPorts[str(participant.key)] = (ip, port, appName, host, domain_id)

        self.pollingThread.setDbgPorts(self.dgbPorts)

    @Slot(str, int, object)
    def response_participants_slot(self, request_id: str, domain_id: int, participants):
        if request_id not in self.request_ids:
            return

        for participant in participants:
            self.new_participant_slot(domain_id, participant)

        self.request_ids.remove(request_id)

    @Slot(int, str)
    def removed_participant_slot(self, domain_id: int, participant_key: str):
        if participant_key in self.dgbPorts:
            del self.dgbPorts[participant_key]
        self.pollingThread.setDbgPorts(self.dgbPorts)

    @Slot()
    def stop(self):
        logging.trace("Stop statistics model")
        if self.pollingThread:
            if self.pollingThread.stillRunning():
                self.pollingThread.stop()
                self.pollingThread.wait()

    @Slot(int)
    def setUpdateInterval(self, interval: int):
        self.pollingThread.setInterval(interval)

    @Slot(str)
    def setAggregation(self, aggre: str):
        self.pollingThread.setAggregation(aggre.lower())

    @Slot()
    def clearStatistics(self):
        for key in self.unitModels.keys():
            self.unitModels[key].clearStatistics()

    @Slot(str, QColor)
    def changeColors(self, item: str, color: QColor):
        logging.debug(f"Change colors for: {item} to {color.red()},{color.green()},{color.blue()}")
        self.pollingThread.changeColor(item, color)

        for k in self.unitModels.keys():
            self.unitModels[k].updateColors(item, color)

    @Slot(str, bool)
    def setItemVisible(self, item: str, isVisible: bool):
        for k in self.unitModels.keys():
            self.unitModels[k].setItemVisible(item, isVisible)

class StatisticsUnitModel(QAbstractTableModel):
    newData = Signal(str, float, int, int, int, bool)

    NameRole = Qt.UserRole + 1
    ValueRole = Qt.UserRole + 2
    RoleColorR = Qt.UserRole + 3
    RoleColorG = Qt.UserRole + 4
    RoleColorB = Qt.UserRole + 5
    IsVisibleRole = Qt.UserRole + 6

    def roleNames(self):
        roles = {
            Qt.DisplayRole: b'display',
            self.NameRole: b'name',
            self.ValueRole: b'value',
            self.RoleColorR: b'color_r',
            self.RoleColorG: b'color_g',
            self.RoleColorB: b'color_b',
            self.IsVisibleRole: b'is_visible'
        }
        return roles

    def __init__(self, pollingThread, prop, parent=None):
        super().__init__(parent)
        self.data_list = []
        self.visibleItems = {}
        self.prop = prop
        self.clearOnNextData = False
        self.pollingThread = pollingThread
        self.pollingThread.onData.connect(self.onAggregatedData, Qt.ConnectionType.QueuedConnection)

    def rowCount(self, parent=QModelIndex()):
        return len(self.data_list)

    def columnCount(self, parent=QModelIndex()):
        return 3

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()
        if row >= len(self.data_list):
            return None
        item = self.data_list[row]
        if role == self.NameRole:
            return item[0]
        elif role == self.ValueRole:
            return item[1]
        elif role == self.RoleColorR:
            return item[2]
        elif role == self.RoleColorG:
            return item[3]
        elif role == self.RoleColorB:
            return item[4]
        elif role == self.IsVisibleRole:
            if item[0] in self.visibleItems:
                return self.visibleItems[item[0]]
            else:
                return True
        elif role == Qt.DisplayRole:
            column = index.column()
            curItem = item[index.column()-1]
            if column == 2:
                if isinstance(curItem, float) or (isinstance(curItem, int) and not isinstance(curItem, bool)):
                    return QLocale().toString(curItem)
            return curItem
        return None

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if role != Qt.DisplayRole:
            return None
        if orientation == Qt.Horizontal:
            headers = ["", "Name", "Value"]
            if section < len(headers):
                return headers[section]
        return None

    @Slot(str, object, object)
    def onAggregatedData(self, prop, aggregated_data, color_mapping):
        if prop != self.prop:
            return

        logging.trace(f"New data received {prop}: {str(len(aggregated_data))}")
        self.beginResetModel()
        self.data_list.clear()
        for topc_guid in aggregated_data.keys():
            value = float(aggregated_data[topc_guid]) # in qml there is no uint64, so we use float aka. double in qml
            (r, g, b) = color_mapping[topc_guid]
            self.newData.emit(topc_guid, value, r, g, b, self.clearOnNextData)
            self.data_list.append([topc_guid, value, r, g, b])
            self.visibleItems[topc_guid] = True if topc_guid not in self.visibleItems else self.visibleItems[topc_guid]
        self.endResetModel()

        self.clearOnNextData = False

    def clearStatistics(self):
        self.clearOnNextData = True

    def updateColors(self, item: str, color: QColor):
        for i in range(len(self.data_list)):
            if self.data_list[i][0] == item:
                self.data_list[i][2] = color.red()
                self.data_list[i][3] = color.green()
                self.data_list[i][4] = color.blue()
                self.dataChanged.emit(self.index(i, 0), self.index(i, self.columnCount() - 1), [self.RoleColorR, self.RoleColorG, self.RoleColorB, self.ValueRole, self.NameRole, self.IsVisibleRole])
                logging.debug(f"Updated color for {item} to {color.red()},{color.green()},{color.blue()}")
                break

    @Slot(str, bool)
    def setItemVisible(self, item: str, is_visible: bool):
        if item not in self.visibleItems:
            return # unknown

        if self.visibleItems[item] == is_visible:
            return # no change

        self.visibleItems[item] = is_visible

        for i in range(len(self.data_list)):
            if self.data_list[i][0] == item:
                self.dataChanged.emit(self.index(i, 0), self.index(i, self.columnCount() - 1), [self.RoleColorR, self.RoleColorG, self.RoleColorB, self.ValueRole, self.NameRole, self.IsVisibleRole])
                logging.debug(f"Set visibility for {item} to {is_visible}")
                break
