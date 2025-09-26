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

import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
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
    property int itemCellHeight: 400
    property int itemChartWidth: 450

    property var markers: []

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

    function addMarkerToAllCharts(time, text) {
        for (let i = 0; i < chartRepeater.count; i++) {
            let chartObj = chartRepeater.itemAt(i);
            if (chartObj && chartObj.addMarker) {
                chartObj.addMarker(time, text);
            }
        }
    }

    function clearMarkers() {
        console.debug("Clear markers, count:", markers.length);
        for (var i = 0; i < markers.length; i++) {
            markers[i].destroy();
        }
        markers = [];
    }

    ScrollView {
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: repeaterItem
            anchors.fill: parent
            spacing: 0

            Repeater {
                id: chartRepeater
                model: statisticModel
                delegate: Item {
                    id: currentStatUnitId
                    Layout.preferredHeight: itemCellHeight
                    Layout.preferredWidth: rootStatViewId.width

                    property var lineSeriesDict: Object.create(null)

                    Component.onCompleted: {
                        axisX.min = new Date(Date.now() - 2 * 60 * 1000)
                        axisX.max = new Date(Date.now())
                    }

                    function addMarker(labelText, timeMs) {
                        var comp = Qt.createComponent("qrc:/src/views/statistics/Marker.qml");
                        if (comp.status === Component.Ready) {
                            var m = comp.createObject(markersLayer, {
                                chart: myChart,
                                axisX: axisX,
                                time: timeMs,
                                text: labelText
                            });
                            if (m) {
                                markers.push(m);
                            }
                        } else {
                            console.log("Marker error:", comp.errorString());
                        }
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
                                currentStatUnitId.lineSeriesDict[guid].color = Qt.rgba(r/255, g/255, b/255, 1);
                            } else {
                                var line = myChart.createSeries(ChartView.SeriesTypeLine, guid, axisX, axisY);
                                line.color = Qt.rgba(r/255, g/255, b/255, 1);
                                axisX.titleText = "time";
                                axisY.titleText = name_role + " [" + unit_name_role + "]";
                                line.append(timestamp, value); 
                                line.hovered.connect(function(point, state) {
                                    tooltip.visible = state;
                                    tooltip.text = line.name;
                                    tooltip.textColor = line.color;
                                    var pos = myChart.mapToPosition(point, line);
                                    tooltip.x = pos.x;
                                    tooltip.y = pos.y;
                                });

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
                                id: myChart

                                Layout.preferredHeight: itemCellHeight * 0.9
                                Layout.preferredWidth: itemChartWidth
                                Layout.alignment: Qt.AlignTop
                                
                                title: name_role
                                antialiasing: true
                                legend.visible: false
                                legend.alignment: Qt.AlignRight
                                localizeNumbers: true

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

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 10
                                    width: 80
                                    height: 20
                                    color: chartControlMiniMouseArea.pressed ? "lightgrey" : "transparent"
                                    
                                    Label {
                                        text: "Export CSV"
                                        anchors.centerIn: parent
                                        color: "black"
                                    }
                                    MouseArea {
                                        id: chartControlMiniMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            exportCsvDialog.open()
                                        }
                                    }
                                }
                                Item {
                                    id: markersLayer
                                    anchors.fill: parent
                                    z: 1000
                                }
                            }

                            ColumnLayout {
                                id: tableLayout
                                Layout.preferredHeight: itemCellHeight * 0.9
                                Layout.preferredWidth: rootStatViewId.width - itemChartWidth
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
                                        implicitWidth: model.column === 0 ? 60 : model.column === 1 ? (tableLayout.implicitWidth) * 0.6 : (tableLayout.implicitWidth) * 0.3
                                        implicitHeight: 25
   
                                        Label {
                                            visible: model.column !== 0
                                            id: displayLabel
                                            text: display
                                            anchors.fill: parent
                                            color: Qt.rgba(model.color_r / 255, model.color_g / 255, model.color_b / 255, 1)
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignVCenter
                                            clip: true
                                        }

                                        RowLayout {
                                            visible: model.column === 0
                                            CheckBox {
                                                checked: is_visible
                                                text: ""
                                                onCheckedChanged: {
                                                    statisticModel.setItemVisible(name, checked)
                                                    if (name in currentStatUnitId.lineSeriesDict) {
                                                        currentStatUnitId.lineSeriesDict[name].visible = checked
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                
                                                width: 20
                                                height: 20
                                                color: Qt.rgba(model.color_r / 255, model.color_g / 255, model.color_b / 255, 1)
                                                border.width: 1
                                                border.color: "black"

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        colorDialog.selectedColor = Qt.rgba(model.color_r / 255, model.color_g / 255, model.color_b / 255, 1)
                                                        colorDialog.name = name
                                                        colorDialog.open()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    FileDialog {
                        id: exportCsvDialog
                        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
                        fileMode: FileDialog.SaveFile
                        defaultSuffix: "json"
                        title: "Export Tester Preset"
                        nameFilters: ["CSV files (*.csv)"]
                        selectedFile: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] + "/" + name_role + ".csv"
                        onAccepted: {
                            console.info("Export CSV to " + selectedFile)
                            qmlUtils.createFileFromQUrl(selectedFile)
                            var localPath = qmlUtils.toLocalFile(selectedFile);
                            var csv = "Timestamp";

                            // CSV Header
                            for (var guid in currentStatUnitId.lineSeriesDict) {
                                csv += "," + guid;
                            }
                            csv += "\n";

                            // Collect all unique timestamps
                            var timestampSet = new Set();
                            var guidList = [];
                            for (var guid in currentStatUnitId.lineSeriesDict) {
                                guidList.push(guid);
                                var line = currentStatUnitId.lineSeriesDict[guid];
                                for (var i = 0; i < line.count; ++i) {
                                    var point = line.at(i);
                                    timestampSet.add(point.x);
                                }
                            }
                            var timestamps = Array.from(timestampSet);
                            timestamps.sort(function(a, b) { return a - b; });

                            // Build a lookup: guid -> {timestamp -> value}
                            var valueMap = {};
                            for (var g = 0; g < guidList.length; ++g) {
                                var guid = guidList[g];
                                var line = currentStatUnitId.lineSeriesDict[guid];
                                valueMap[guid] = {};
                                for (var i = 0; i < line.count; ++i) {
                                    var point = line.at(i);
                                    valueMap[guid][point.x] = point.y;
                                }
                            }

                            // Write CSV rows
                            var lastValues = {};
                            for (var t = 0; t < timestamps.length; ++t) {
                                var row = "" + timestamps[t];
                                for (var g = 0; g < guidList.length; ++g) {
                                    var guid = guidList[g];
                                    var val = valueMap[guid][timestamps[t]];
                                    if (val !== undefined) {
                                        lastValues[guid] = val; // update last known value
                                    }
                                    row += "," + (lastValues[guid] !== undefined ? lastValues[guid] : "");
                                }
                                csv += row + "\n";
                            }

                            qmlUtils.saveFileContent(localPath, csv);
                        }
                    }
                }
            }
        }
    }

    ColorDialog {
        id: colorDialog
        property string name: ""
        onAccepted: {
            console.info("Change color to", selectedColor)
            statisticModel.changeColors(name, selectedColor)
            for (let i = 0; i < chartRepeater.count; i++) {
                let chartObj = chartRepeater.itemAt(i);
                if (chartObj && chartObj.lineSeriesDict && name in chartObj.lineSeriesDict) {
                    chartObj.lineSeriesDict[name].color = selectedColor;
                }
            }
        }
        onRejected: {
            console.info("Color change cancelled")
        }
    }

    ToolTip {
        id: tooltip
        visible: false
        delay: 0
        text: ""
        property color textColor: "black"
        contentItem: Label {
            id: tooltipText
            text: tooltip.text
            padding: 6
            color: tooltip.textColor
        }
        background: Rectangle {
            border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
            border.width: 1
            color: rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor
        }
    }
}
