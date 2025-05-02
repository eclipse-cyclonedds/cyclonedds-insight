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


Rectangle {
    id: topicEndpointView
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent
    property var lineSeriesDict: Object.create(null)
    property var statisticModel: Object.create(null)
    property int domainId

    Component.onCompleted: {
        console.log("StatisticsView.qml: Component.onCompleted");
        axisX.min = new Date(Date.now() - 2 * 60 * 1000)
        axisX.max = new Date(Date.now())
    }

    function startStatistics() {
        if (statisticModel) {
            console.log("Starting statistics");
            statisticModel.startStatistics(domainId, "topic")
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



    Connections {
        target: statisticModel
        function onNewData(guid, value, r, g, b) {

            if (lineSeriesDict === undefined) {
                lineSeriesDict = new Map();
            }

            var timestamp = Date.now()

            if (guid in topicEndpointView.lineSeriesDict) {
                if (topicEndpointView.lineSeriesDict[guid].count >= 120) {
                    topicEndpointView.lineSeriesDict[guid].remove(0);
                }
                topicEndpointView.lineSeriesDict[guid].append(timestamp, value);
            } else {
                var line = myChart.createSeries(ChartView.SeriesTypeLine, guid, axisX, axisY);
                line.color = Qt.rgba(r/255, g/255, b/255, 1);
                axisX.titleText = "time";
                axisY.titleText = "rexmit_bytes [bytes]";
                line.append(timestamp, value);

                topicEndpointView.lineSeriesDict[guid] = line;
            }

            axisX.min = new Date(Date.now() - 2 * 60 * 1000)
            axisX.max = new Date(Date.now())

            axisY.min = 0
            axisY.max = Math.max(axisY.max, value + (value * 0.1));
        }
    }

    ScrollView {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Label {
                text: "This feature is only available for Cyclone DDS endpoints which have enabled Internal/MonitorPort."
                padding: 5
            }

            Label {
                text: "rexmit_bytes"
                font.bold: true
                padding: 5
            }

            Label {
                text: "Total number of bytes retransmitted for a writer."
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
                    title: "rexmit_bytes"
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
                        min: (Date.now() / 1000) - 120;
                        max: (Date.now() / 1000) + 120;
                    }
                }

                ColumnLayout {
                    Layout.preferredHeight: 350
                    Layout.preferredWidth: topicEndpointView.width - 450
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

                        model: statisticModel

                        delegate: Rectangle {
                            implicitWidth: model.column === 0 ? topicEndpointView.width * 0.3 : topicEndpointView.width * 0.1
                            implicitHeight: 25

                            Text {
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
