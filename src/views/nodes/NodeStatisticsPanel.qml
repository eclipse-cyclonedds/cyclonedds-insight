/*
 * Copyright(c) 2026 Sven Trittler
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
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import "qrc:/src/views"
import "qrc:/src/views/icons"

Item {
    id: panel
    property bool expanded: false
    property var entries: []
    property string selectedNodeKey: ""
    readonly property int metric: metricComboBox.currentIndex
    readonly property bool showDomains: showDomainsCheckBox.checked
    readonly property var metricColors: [Constants.accentColor, Constants.successColor, "#a566d4"]
    property string pendingNodeKey: ""
    readonly property int maximum: entries.length ? entries[0].value : 0
    signal nodeSelected(string key)

    function showNode(key, isDomain) {
        pendingNodeKey = key
        if (isDomain) showDomainsCheckBox.checked = true
        expanded = true
        Qt.callLater(revealPendingNode)
    }

    function revealPendingNode() {
        if (!expanded || !pendingNodeKey) return
        for (var i = 0; i < entries.length; ++i) {
            if (entries[i].key === pendingNodeKey) {
                rankingList.positionViewAtIndex(i, ListView.Contain)
                pendingNodeKey = ""
                return
            }
        }
    }

    onEntriesChanged: if (pendingNodeKey) Qt.callLater(revealPendingNode)
    onSelectedNodeKeyChanged: if (!selectedNodeKey) pendingNodeKey = ""

    width: expanded ? Math.min(320, parent.width * 0.4) : toggleButton.implicitWidth

    Rectangle {
        anchors.fill: parent
        visible: panel.expanded
        color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
        border.color: Constants.designBorderColor(rootWindow.isDarkMode)
        radius: Constants.cardRadius
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: panel.expanded ? 12 : 0
        spacing: 12
        Basic.Button {
            id: toggleButton
            objectName: "toggleNodeStatisticsButton"
            Layout.fillWidth: true
            flat: true
            text: qsTrId("statistics")
            onClicked: panel.expanded = !panel.expanded
            contentItem: RowLayout {
                spacing: 8
                ChevronIcon {
                    direction: "right"
                    rotation: panel.expanded ? 0 : 180
                    iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                }
                Label {
                    text: toggleButton.text
                    font.bold: true
                    color: rootWindow.isDarkMode ? "#eeeeee" : "#262626"
                }
                Item { Layout.fillWidth: true }
            }
        }
        ComboBox {
            id: metricComboBox
            objectName: "nodeStatisticsMetricComboBox"
            visible: panel.expanded
            Layout.fillWidth: true
            model: [qsTrId("entity.participants"), qsTrId("entity.endpoints"), qsTrId("entity.topics"), qsTrId("node.statistics.combined")]
            currentIndex: 3
        }
        CheckBox {
            id: showDomainsCheckBox
            objectName: "nodeStatisticsShowDomainsCheckBox"
            visible: panel.expanded
            text: qsTrId("node.statistics.show.domains")
            checked: true
        }
        Flow {
            visible: panel.expanded && panel.metric === 3
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [qsTrId("entity.participants"), qsTrId("entity.endpoints"), qsTrId("entity.topics")]
                Row {
                    required property int index
                    required property string modelData
                    spacing: 4
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: panel.metricColors[parent.index]
                    }
                    Label {
                        text: parent.modelData
                        font.pixelSize: 10
                        color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                    }
                }
            }
        }
        ListView {
            id: rankingList
            objectName: "nodeStatisticsRanking"
            visible: panel.expanded
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: panel.entries
            ScrollBar.vertical: ScrollBar { id: rankingScrollBar }
            delegate: Basic.ItemDelegate {
                id: row
                required property var modelData
                objectName: "nodeStatisticRow_" + modelData.key
                width: Math.max(0, rankingList.width - Math.max(12, rankingScrollBar.width + 8))
                height: (modelData.hostName ? 76 : 60) + (panel.metric === 3 ? 20 : 0)
                onClicked: panel.nodeSelected(modelData.key)
                background: Rectangle {
                    radius: Constants.controlRadius
                    color: row.modelData.key === panel.selectedNodeKey
                         ? Qt.rgba(row.modelData.color.r, row.modelData.color.g, row.modelData.color.b, 0.16)
                         : row.hovered ? Constants.mainContentColor(rootWindow.isDarkMode) : "transparent"
                }
                contentItem: ColumnLayout {
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            textFormat: Text.PlainText
                            elide: Text.ElideMiddle
                            font.pixelSize: 12
                            color: rootWindow.isDarkMode ? "#eeeeee" : "#262626"
                        }
                        Label {
                            visible: panel.metric !== 3
                            text: row.modelData.value
                            font.bold: true
                            color: rootWindow.isDarkMode ? "#eeeeee" : "#262626"
                        }
                    }
                    Row {
                        visible: panel.metric === 3
                        spacing: 12
                        Repeater {
                            model: [row.modelData.participants, row.modelData.endpoints, row.modelData.topics]
                            Row {
                                required property int index
                                required property int modelData
                                spacing: 4
                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: panel.metricColors[parent.index]
                                }
                                Label {
                                    text: parent.modelData
                                    font.bold: true
                                    color: rootWindow.isDarkMode ? "#eeeeee" : "#262626"
                                }
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: row.modelData.hostName !== ""
                        text: row.modelData.hostName
                        textFormat: Text.PlainText
                        elide: Text.ElideMiddle
                        font.pixelSize: 10
                        color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        clip: true
                        color: Constants.designBorderColor(rootWindow.isDarkMode)
                        Rectangle {
                            visible: panel.metric !== 3
                            width: panel.maximum > 0 ? parent.width * row.modelData.value / panel.maximum : 0
                            height: parent.height
                            radius: parent.radius
                            color: row.modelData.color
                        }
                        Row {
                            anchors.fill: parent
                            visible: panel.metric === 3
                            Repeater {
                                model: [row.modelData.participants, row.modelData.endpoints, row.modelData.topics]
                                Rectangle {
                                    required property int index
                                    required property int modelData
                                    width: panel.maximum > 0 ? parent.width * modelData / panel.maximum : 0
                                    height: parent.height
                                    color: panel.metricColors[index]
                                }
                            }
                        }
                    }
                }
            }
            Label {
                anchors.centerIn: parent
                width: parent.width
                visible: panel.entries.length === 0
                text: qsTrId("node.statistics.empty")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
            }
        }
        Item { visible: !panel.expanded; Layout.fillHeight: true }
    }
}
