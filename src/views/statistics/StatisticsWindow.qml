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


Window {
    id: shapeDemoViewId
    title: "CycloneDDS Statistics"
    width: 1200
    height: 800
    flags: Qt.Dialog
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
                        Layout.preferredWidth: 60
                        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
                        currentIndex: 2
                        onCurrentTextChanged: statisticModelId.setUpdateInterval(parseInt(currentText))
                    }

                    Label {
                        text: "seconds"
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
                        model: ["Domain", "Host", "Process", "Participant", "Topic", "Endpoint"]
                        currentIndex: 0
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
            domainId: 0
            visible: true
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
    
}
