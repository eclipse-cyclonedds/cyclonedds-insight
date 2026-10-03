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
import QtQuick.Controls
import QtQuick.Layouts
import "qrc:/src/views"
import "qrc:/src/views/elements"

Rectangle {
    id: view
    property int domainId
    property var summary: ({})
    property bool process: false
    readonly property color textColor: rootWindow.isDarkMode ? "#eeeeee" : "#262626"
    readonly property color mutedColor: Constants.secondaryTextColor(rootWindow.isDarkMode)
    color: Constants.mainContentColor(rootWindow.isDarkMode)
    clip: true

    component DetailRow: ColumnLayout {
        id: detail
        property string label
        property string value
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 4
        Label {
            text: detail.label
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            wrapMode: Text.Wrap
            color: view.mutedColor
        }
        TextEdit {
            text: detail.value || qsTrId("participant.unknown")
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.WrapAnywhere
            color: view.textColor
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        contentWidth: availableWidth
        contentHeight: content.implicitHeight
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: content
            width: scroll.availableWidth
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                RowLayout {
                    spacing: 8
                    DetailBadge { kind: view.process ? "process" : "host" }
                    Label {
                        text: view.process ? qsTrId("entity.process") : qsTrId("entity.host")
                        color: view.textColor
                        font.pixelSize: Constants.pageTitleFontSize
                        font.bold: true
                    }
                }

            }

            DetailGroup {
                Layout.fillWidth: true
                title: qsTrId("tab.details")
                GridLayout {
                    id: identity
                    anchors.fill: parent
                    columns: width < 450 ? 1 : 2
                    columnSpacing: 18
                    rowSpacing: 12
                    DetailRow {
                        label: view.process ? qsTrId("entity.process") : qsTrId("entity.host")
                        value: (view.process ? view.summary.processName : view.summary.hostname) || ""
                    }
                    DetailRow {
                        label: qsTrId("entity.domain.id.label")
                        value: String(view.domainId)
                    }
                    DetailRow {
                        visible: view.process
                        label: qsTrId("entity.process.id")
                        value: view.summary.processId || ""
                    }
                    DetailRow {
                        visible: view.process
                        label: qsTrId("entity.host")
                        value: view.summary.hostname || ""
                    }
                    DetailRow {
                        visible: !!view.summary.addresses
                        label: qsTrId("entity.addresses")
                        value: view.summary.addresses || ""
                    }
                }
            }

            DetailGroup {
                Layout.fillWidth: true
                title: qsTrId("summary.overview")
                ColumnLayout {
                    id: metrics
                    anchors.fill: parent
                    spacing: 12
                    Repeater {
                        model: {
                            const counts = [
                                {label: qsTrId("entity.participants"), value: view.summary.participants},
                                {label: qsTrId("entity.topics"), value: view.summary.topics},
                                {label: qsTrId("entity.reader"), value: view.summary.readers},
                                {label: qsTrId("entity.writer"), value: view.summary.writers}
                            ]
                            if (!view.process)
                                counts.unshift({label: qsTrId("summary.processes"), value: view.summary.processes})
                            return counts
                        }
                        RowLayout {
                            id: metricRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 16
                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: metricRow.modelData.label
                                wrapMode: Text.Wrap
                                color: view.mutedColor
                            }
                            Label {
                                text: String(metricRow.modelData.value || 0)
                                color: view.textColor
                                font.pixelSize: Constants.sectionTitleFontSize
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

        }
    }
}
