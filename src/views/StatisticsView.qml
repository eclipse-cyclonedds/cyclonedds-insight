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

    Component.onCompleted: {
        console.log("StatisticsView.qml: Component.onCompleted");
        var timestamp = Date.now() / 1000; 
        axisX.min = timestamp;
        axisX.max = timestamp + 120;
    }

    Connections {
        target: statisticModel
        function onNewData(guid, value, r, g, b) {
            console.log("New data received: " + guid + ", " + value, r, g, b, Math.random());

            if (lineSeriesDict === undefined) {
                lineSeriesDict = new Map();
            }

            var timestamp = Date.now() / 1000; // seconds since 1970

            if (guid in topicEndpointView.lineSeriesDict) {
                console.log("Line series already exists for guid: " + guid, topicEndpointView.lineSeriesDict[guid].count);
                topicEndpointView.lineSeriesDict[guid].append(timestamp, value);
            } else {
                console.log("Creating new line series for guid: " + guid);
                var line = myChart.createSeries(ChartView.SeriesTypeLine, guid, axisX, axisY);
                line.color = Qt.rgba(r/255, g/255, b/255, 1);
                axisX.titleText = "time";
                axisY.titleText = "rexmit_bytes [bytes]";
                topicEndpointView.lineSeriesDict[guid] = line;
                line.append(timestamp, value);
            }

            axisX.min = Math.min(axisX.min, timestamp);
            axisX.max = Math.max(axisX.max, timestamp);

            axisY.min = Math.min(axisY.min, value);
            axisY.max = Math.max(axisY.max, value);
        }
    }

    function add() {
        var line = myChart.createSeries(ChartView.SeriesTypeLine, "Line series", axisX, axisY);
        
        topicEndpointView.lineSeries = line;
        line.name = "N: " + Math.floor(Math.random() * 10);
        line.color = Qt.rgba(Math.random(), Math.random(), Math.random(), 1);
        //line.color = "red";

        for (var i = 0; i < 10; i++) {
            line.append(i, Math.random() * 10);
        }

        axisX.min = 0;
        axisX.max = 10;

        axisY.min = 0;
        axisY.max = 10;
    }

    function eliminate() {
        myChart.removeAllSeries();
    }

    ScrollView {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Label {
                text: "This feature is only available for Cyclone DDS endpoints which have enabled Internal/MonitorPort."
                padding: 10
            }

            Label {
                text: "Acks"
                font.bold: true
                padding: 10
            }

            RowLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true

                ChartView {
                    Layout.preferredHeight: 350
                    Layout.preferredWidth: 450

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


                    ValueAxis {
                        id: axisX
                        min: 500
                        max: (Date.now() / 1000) + 120;
                        gridVisible: true
                        tickCount: 4
                    }
                }

                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    Label {
                        text: "This is a placeholder for the statistics view."
                        padding: 10
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Button{
                            id: addButton
                            text: "Add"
                            onClicked: add()
                        }
                        Button {
                            id: addValueButton
                            text: "Add Value"
                            onClicked: {
                                if (topicEndpointView.lineSeries) {
                                    var x = topicEndpointView.lineSeries.count;
                                    var y = Math.random() * 10;
                                    topicEndpointView.lineSeries.append(x, y);
                                    axisX.max = x + 1;
                                }
                            }
                        }
                        Button{
                            id: eliminateButton
                            text: "Reset"
                            onClicked: eliminate()
                        }
                    }
                    ScrollView {
                        Layout.preferredHeight: 250
                        //Layout.preferredWidth: 200
                        Layout.fillWidth: true

                        TableView {
                            anchors.fill: parent

                            columnSpacing: 1
                            rowSpacing: 1
                            clip: true
                            interactive: true

                            model: TableModel {
                                TableModelColumn { display: "name" }
                                TableModelColumn { display: "color" }

                                rows: [
                                    {
                                        "name": "cat",
                                        "color": "black"
                                    },
                                    {
                                        "name": "dog",
                                        "color": "brown"
                                    },
                                    {
                                        "name": "bird",
                                        "color": "white"
                                    },
                                    {
                                        "name": "fish",
                                        "color": "blue"
                                    },
                                    {
                                        "name": "horse",
                                        "color": "brown"
                                    },
                                    {
                                        "name": "rabbit",
                                        "color": "gray"
                                    },
                                    {
                                        "name": "turtle",
                                        "color": "green"
                                    },
                                    {
                                        "name": "hamster",
                                        "color": "golden"
                                    },
                                    {
                                        "name": "parrot",
                                        "color": "red"
                                    },
                                    {
                                        "name": "lizard",
                                        "color": "green"
                                    },
                                    {
                                        "name": "snake",
                                        "color": "black"
                                    },
                                    {
                                        "name": "frog",
                                        "color": "green"
                                    },
                                    {
                                        "name": "mouse",
                                        "color": "white"
                                    }
                                ]
                            }

                            delegate: Rectangle {
                                implicitWidth: 100
                                implicitHeight: 50
                                //border.width: 1

                                Text {
                                    text: display
                                    anchors.centerIn: parent
                                }
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
