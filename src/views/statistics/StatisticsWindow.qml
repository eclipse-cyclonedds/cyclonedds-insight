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
import QtQuick.Dialogs

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"


Rectangle {
    id: statisticsMainViewId
    anchors.fill: parent
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent
    property bool statsRunning: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        anchors.margins: 10

        Label {
            text: qsTr("Statistics")
            font.pixelSize: 18
            font.bold: true
        }

        Label {
            text: "This feature is only available for Cyclone DDS endpoints which have enabled Internal/MonitorPort."
            font.italic: true
        }

        GroupBox {
            title: qsTr("Settings")
            spacing: 0

            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: "Update Interval:"
                    }

                    ComboBox {
                        id: updateRateSelector
                        Layout.preferredWidth: 70
                        model: ["1", "2", "3", "5", "8", "10", "30", "60", "900", "1800", "3600"]
                        currentIndex: 2
                        onCurrentTextChanged: statisticModelId.setUpdateInterval(parseInt(currentText))
                    }

                    Label {
                        text: "seconds."
                    }
                }

                RowLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: "Show data from last"
                    }

                    ComboBox {
                        Layout.preferredWidth: 70
                        model: ["1", "2", "3", "5", "8", "13", "21", "34", "55", "89", "144", "233", "720" ,"1440"]
                        currentIndex: 1
                        onCurrentTextChanged: statisticsView.setKeepHistoryMinutes(parseInt(currentText))
                    }

                    Label {
                        text: "minutes."
                    }
                }


                RowLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: "Aggregate by:"
                    }

                    ComboBox {
                        id: aggregateByComboBoxId
                        Layout.preferredWidth: 150
                        model: ["Domain", "Host", "Process", "Participant", "Topic", "Writer"]
                        currentIndex: 0
                        onCurrentTextChanged: {
                            statisticsView.clearStatistics()
                            statisticModelId.setAggregation(currentText)
                        }
                    }
                }

                RowLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 0
                    Button {
                        text: statsRunning ? qsTr("Stop Statistics") : qsTr("Start Statistics")
                        onClicked: {
                            if (statsRunning) {
                                statisticsView.stopStatistics()
                            } else {
                                statisticsView.startStatistics()
                            }
                            statsRunning = !statsRunning
                        }
                    }
                    Label {
                        text: qsTr("Status: ")
                    }
                    Label {
                        text: statsRunning ? qsTr("Running") : qsTr("Stopped")
                    }
                    Rectangle {
                        width: 10
                        height: 10
                        radius: width / 2
                        clip: true
                        color: statsRunning ? "green" : "red"
                        Layout.leftMargin: 5
                    }
                }
            }
        }

        StatisticsModel {
            id: statisticModelId
            Component.onDestruction: {
                statisticModelId.stop()
            }
        }

        StatisticsView {
            id: statisticsView
            statisticModel: statisticModelId
            visible: true
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    function aboutToClose() {
        console.log("StatisticsWindow is closing")
        statisticsView.stopStatistics()
        statsRunning = false
    }
}
