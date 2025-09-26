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

        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 0

            GroupBox {
                id: settingsGroubBox
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
                            currentIndex: 2
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

            GroupBox {
                id: chatGroubBox
                title: qsTr("Chart Controls")
                spacing: 0
                Layout.preferredHeight: settingsGroubBox.height

                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        spacing: 0

                        Button {
                            text: "←"
                            onClicked: {
                                if (statisticsView.itemChartWidth >= 400) {
                                    statisticsView.itemChartWidth -= 50
                                }
                            }
                        }
                        Button {
                            text: "→"
                            onClicked: {
                                statisticsView.itemChartWidth += 50
                            }
                        }
                        Button {
                            text: "↑"
                            onClicked: {
                                if (statisticsView.itemCellHeight >= 300) {
                                    statisticsView.itemCellHeight -= 50
                                }
                            }
                        }
                        Button {
                            text: "↓"
                            onClicked: {
                                statisticsView.itemCellHeight += 50
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 0

                        Button {
                            text: "Add Marker"
                            enabled: statsRunning
                            onClicked: {
                                statisticsView.addMarkerToAllCharts(markerTextField.text, Date.now()); 
                            }
                        }
                        Button {
                            text: "Clear Markers"
                            onClicked: clearMarkerDialog.open()
                        }
                    }
                    TextField {
                        id: markerTextField
                        placeholderText: "Enter Marker Name"
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                id: statErrorWindow
                color: "transparent"
                Layout.fillWidth: true   
                Layout.preferredHeight: settingsGroubBox.height
                visible: false

                Flickable {
                    id: statisticErrorsScrollView
                    anchors.fill: parent
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: true
                    ScrollBar.vertical: ScrollBar {}

                    TextArea.flickable: TextArea {
                        id: statErrorTextArea
                        readOnly: true
                        tabStopDistance: 40
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        selectByKeyboard: true
                        onContentHeightChanged: {
                            statErrorTextArea.cursorPosition = statErrorTextArea.length
                            statisticErrorsScrollView.contentY = statErrorTextArea.height - statisticErrorsScrollView.height
                        }
                    }
                }
                Button {
                    text: "Clear"
                    anchors.top: statErrorWindow.top
                    anchors.right: statErrorWindow.right
                    anchors.margins: 10
                    onClicked: {
                        statErrorWindow.visible = false
                        statErrorTextArea.text = ""
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

        Connections {
            target: statisticModelId
            function onStatisticError(msg) {
                if (!statErrorWindow.visible) {
                    statErrorWindow.visible = true
                }

                statErrorTextArea.append(msg)
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

    MessageDialog {
        id: clearMarkerDialog
        title: qsTr("Alert");
        text: qsTr("Sure to clear all markers?");
        buttons: MessageDialog.Ok | MessageDialog.Cancel;
        onButtonClicked: function (button, role) {
            if (role === MessageDialog.AcceptRole || role === MessageDialog.YesRole) {
                statisticsView.clearMarkers()
            }
        }
    }

    function aboutToClose() {
        console.log("StatisticsWindow is closing")
        statisticsView.stopStatistics()
        statsRunning = false
    }
}
