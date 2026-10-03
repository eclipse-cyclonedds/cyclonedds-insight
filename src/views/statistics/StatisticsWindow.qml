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
import "qrc:/src/views/icons"
import "qrc:/src/views/elements"
import "qrc:/src/views/selection_details"


Rectangle {
    id: statisticsMainViewId
    anchors.fill: parent
    color: Constants.mainContentColor(rootWindow.isDarkMode)
    property bool statsRunning: false
    readonly property bool compactLayout: width < 700 || height < 550
    property bool controlsExpanded: !compactLayout
    clip: true
    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)

    ColumnLayout {
        anchors.fill: parent
        spacing: 14
        anchors.margins: Constants.pageMargin

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                DetailBadge {
                    kind: "statistics"
                }

                Label {
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    text: qsTrId("statistics")
                    font.pixelSize: Constants.pageTitleFontSize
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: statisticsMainViewId.statsRunning
                           ? Constants.successColor
                           : Constants.errorColor
                }

                Label {
                    text: statisticsMainViewId.statsRunning
                          ? qsTrId("statistic.status.running")
                          : qsTrId("statistic.status.stopped")
                    font.bold: true
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.minimumWidth: 0
                text: qsTrId("statistic.monitor.usage.hint")
                color: statisticsMainViewId.secondaryTextColor
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ExpandButton {
                text: qsTrId("general.settings")
                expanded: statisticsMainViewId.controlsExpanded
                onClicked: statisticsMainViewId.controlsExpanded = !statisticsMainViewId.controlsExpanded
            }
            Item { Layout.fillWidth: true }
            Button {
                text: statsRunning ? qsTrId("statistics.stop") : qsTrId("statistics.start")
                onClicked: {
                    if (statsRunning) {
                        statisticsView.stopStatistics()
                    } else {
                        statisticsView.startStatistics()
                    }
                    statsRunning = !statsRunning
                }
            }
        }

        ScrollView {
            id: controlsScroll
            visible: statisticsMainViewId.controlsExpanded
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(controlsGrid.implicitHeight,
                                            statisticsMainViewId.height * 0.4)
            clip: true
            contentWidth: availableWidth
            contentHeight: controlsGrid.implicitHeight
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            GridLayout {
                id: controlsGrid
                width: controlsScroll.availableWidth
                columns: width < 650 ? 1 : 2
                columnSpacing: 12
                rowSpacing: 10

                DetailGroup {
                    id: settingsGroubBox
                    title: qsTrId("general.settings")
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    ColumnLayout {
                        anchors.fill: parent
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 0

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                wrapMode: Text.Wrap
                                text: qsTrId("statistics.update.interval")
                            }

                            ComboBox {
                                id: updateRateSelector
                                Layout.preferredWidth: 70
                                model: ["1", "2", "3", "5", "8", "10", "30", "60", "900", "1800", "3600"]
                                currentIndex: 2
                                onCurrentTextChanged: statisticModelId.setUpdateInterval(parseInt(currentText))
                            }

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                wrapMode: Text.Wrap
                                text: qsTrId("statistics.seconds")
                            }
                        }

                        RowLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 0

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                wrapMode: Text.Wrap
                                text: qsTrId("statistics.show.last")
                            }

                            ComboBox {
                                Layout.preferredWidth: 70
                                model: ["1", "2", "3", "5", "8", "13", "21", "34", "55", "89", "144", "233", "720" ,"1440"]
                                currentIndex: 1
                                onCurrentTextChanged: statisticsView.setKeepHistoryMinutes(parseInt(currentText))
                            }

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                wrapMode: Text.Wrap
                                text: qsTrId("statistics.minutes")
                            }
                        }


                        RowLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 0

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                wrapMode: Text.Wrap
                                text: qsTrId("statistics.aggregate")
                            }

                            ComboBox {
                                id: aggregateByComboBoxId
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                model: ["Domain", "Host", "Process", "Participant", "Topic", "Writer"]
                                currentIndex: 2
                                onCurrentTextChanged: {
                                    statisticsView.clearStatistics()
                                    statisticModelId.setAggregation(currentText)
                                }
                            }
                        }


                    }
                }

                DetailGroup {
                    id: chatGroubBox
                    title: qsTrId("statistic.chart.controls")
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    ColumnLayout {
                        anchors.fill: parent
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 0

                            Button {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                implicitWidth: 40
                                ArrowIcon {
                                    anchors.centerIn: parent
                                    z: 1
                                    direction: "left"
                                    iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                                }
                                onClicked: {
                                    if (statisticsView.itemChartWidth >= 400) {
                                        statisticsView.itemChartWidth -= 50
                                    }
                                }
                            }
                            Button {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                implicitWidth: 40
                                ArrowIcon {
                                    anchors.centerIn: parent
                                    z: 1
                                    direction: "right"
                                    iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                                }
                                onClicked: {
                                    statisticsView.itemChartWidth += 50
                                }
                            }
                            Button {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                implicitWidth: 40
                                ArrowIcon {
                                    anchors.centerIn: parent
                                    z: 1
                                    direction: "up"
                                    iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                                }
                                onClicked: {
                                    if (statisticsView.itemCellHeight >= 300) {
                                        statisticsView.itemCellHeight -= 50
                                    }
                                }
                            }
                            Button {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                implicitWidth: 40
                                ArrowIcon {
                                    anchors.centerIn: parent
                                    z: 1
                                    direction: "down"
                                    iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                                }
                                onClicked: {
                                    statisticsView.itemCellHeight += 50
                                }
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width < 380 ? 1 : 2
                            columnSpacing: 6
                            rowSpacing: 4

                            Button {
                                text: qsTrId("statistics.marker.add")
                                enabled: statsRunning
                                onClicked: {
                                    statisticsView.addMarkerToAllCharts(markerTextField.text, Date.now());
                                }
                            }
                            Button {
                                text: qsTrId("statistics.markers.clear")
                                onClicked: clearMarkerDialog.open()
                            }
                        }
                        TextField {
                            id: markerTextField
                            placeholderText: qsTrId("statistics.marker.placeholder")
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    id: statErrorWindow
                    color: "transparent"
                    Layout.fillWidth: true
                    Layout.columnSpan: controlsGrid.columns
                    Layout.preferredHeight: 110
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
                        text: qsTrId("general.clear")
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
                statisticsMainViewId.controlsExpanded = true
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
        title: qsTrId("general.alert");
        text: qsTrId("statistic.clear.markers.confirm");
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
