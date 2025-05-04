/*
 * Copyright(c) 2024 Sven Trittler
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0, or the Eclipse Distribution License
 * v. 1.0 which is available at
 * http://www.eclipse.org/org/documents/edl-v10.php.
 *
 * SPDX-License-Identifier: EPL-2.0 OR BSD-3-Clause
*/

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts
import Qt.labs.qmlmodels

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"


Rectangle {
    id: rootStatViewId
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent
    property var statisticModel: Object.create(null)
    property int keepHistoryMinutes: 10

    function startStatistics() {
        if (statisticModel) {
            console.log("Starting statistics");
            statisticModel.startStatistics()
        } else {
            console.error("Statistic model is not initialized.");
        }
    }

    function stopStatistics() {
        if (statisticModel) {
            console.log("Stopping statistics");
            statisticModel.stop();
        } else {
            console.error("Statistic model is not initialized.");
        }
    }

    function clearStatistics() {
        statisticModel.clearStatistics()
    }

    function setKeepHistoryMinutes(minutes) {
        keepHistoryMinutes = minutes
    }

    ScrollView {
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: repeaterItem
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: statisticModel
                delegate: Item {
                    id: currentStatUnitId
                    Layout.preferredHeight: 400
                    Layout.preferredWidth: rootStatViewId.width

                    property var lineSeriesDict: Object.create(null)

                    Component.onCompleted: {
                        axisX.min = new Date(Date.now() - 2 * 60 * 1000)
                        axisX.max = new Date(Date.now())
                    }

                    Connections {
                        target: table_model_role
                        function onNewData(guid, value, r, g, b, clearOnNextData) {

                            if (lineSeriesDict === undefined) {
                                lineSeriesDict = new Map();
                            }

                            if (clearOnNextData) {
                                myChart.removeAllSeries()
                                lineSeriesDict = new Map();
                            }

                            var timestamp = Date.now()

                            if (guid in currentStatUnitId.lineSeriesDict) {
                                if (currentStatUnitId.lineSeriesDict[guid].count >= (keepHistoryMinutes * 60)) {
                                    currentStatUnitId.lineSeriesDict[guid].remove(0);
                                }
                                currentStatUnitId.lineSeriesDict[guid].append(timestamp, value);
                            } else {
                                var line = myChart.createSeries(ChartView.SeriesTypeLine, guid, axisX, axisY);
                                line.color = Qt.rgba(r/255, g/255, b/255, 1);
                                axisX.titleText = "time";
                                axisY.titleText = name_role + " [" + unit_name_role + "]";
                                line.append(timestamp, value);

                                currentStatUnitId.lineSeriesDict[guid] = line;
                            }

                            axisX.min = new Date(Date.now() - keepHistoryMinutes * 60 * 1000)
                            axisX.max = new Date(Date.now())

                            axisY.min = 0
                            axisY.max = Math.max(axisY.max, value + (value * 0.1));
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Label {
                            text: name_role
                            font.bold: true
                            padding: 5
                        }

                        Label {
                            text: description_role
                            padding: 2
                        }

                        RowLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 0

                            ChartView {
                                Layout.preferredHeight: 350
                                Layout.preferredWidth: 450
                                Layout.alignment: Qt.AlignTop

                                id: myChart
                                title: name_role
                                antialiasing: true
                                legend.visible: false
                                legend.alignment: Qt.AlignRight

                                ValueAxis {
                                    id: axisY
                                    gridVisible: true
                                    tickCount: 5
                                    min: 500
                                    max: 10
                                }

                                DateTimeAxis {
                                    id: axisX
                                    format: "hh:mm:ss"
                                    tickCount: 5
                                    min: (Date.now() / 1000) - (60 * keepHistoryMinutes);
                                    max: (Date.now() / 1000) + (60 * keepHistoryMinutes);
                                }
                            }

                            ColumnLayout {
                                Layout.preferredHeight: 350
                                Layout.preferredWidth: rootStatViewId.width - 450
                                Layout.alignment: Qt.AlignTop
                                spacing: 0

                                HorizontalHeaderView {
                                    id: horizontalHeader
                                    syncView: tableView
                                    Layout.fillWidth: true
                                    clip: true
                                }

                                TableView {
                                    id: tableView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    columnSpacing: 1
                                    rowSpacing: 1
                                    clip: true
                                    interactive: true

                                    model: table_model_role

                                    delegate: Item {
                                        implicitWidth: model.column === 0 ? (rootStatViewId.width - 450) * 0.7 : (rootStatViewId.width - 450) * 0.3
                                        implicitHeight: 25
   
                                        Label {
                                            text: display
                                            anchors.fill: parent
                                            color: Qt.rgba(model.color_r / 255, model.color_g / 255, model.color_b / 255, 1)
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignVCenter
                                            clip: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
