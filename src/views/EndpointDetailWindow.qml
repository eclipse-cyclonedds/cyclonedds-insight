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

import org.eclipse.cyclonedds.insight
import "qrc:/src/views/selection_details"


Window {
    id: detailWindow

    property string endpointText: ""
    property bool structured: false
    property bool isWriter: false
    property string endpointKey: ""
    property string participantKey: ""
    property string instanceHandle: ""
    property string topicName: ""
    property string topicType: ""
    property string typeId: ""
    property string hostname: ""
    property string processId: ""
    property string processName: ""
    property string addresses: ""
    property string qos: ""
    property bool hasQosMismatch: false
    property string qosMismatchText: ""

    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    readonly property color borderColor: Constants.designBorderColor(rootWindow.isDarkMode)
    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)

    visible: false
    width: 680
    minimumWidth: 500
    height: 520
    minimumHeight: 380
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint | Qt.WindowTitleHint
           | Qt.WindowCloseButtonHint
    color: Constants.mainContentColor(rootWindow.isDarkMode)

    component DetailValue: ColumnLayout {
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 2

        Label {
            text: parent.label
            color: detailWindow.secondaryTextColor
        }

        TextEdit {
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            text: parent.value.length > 0 ? parent.value : "-"
            color: rootWindow.isDarkMode ? "#eeeeee" : "#262626"
            readOnly: true
            wrapMode: TextEdit.WrapAnywhere
            selectByMouse: true
            padding: 0
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            DetailBadge {
                kind: "endpoint"
            }

            ColumnLayout {
                spacing: 0

                Label {
                    text: detailWindow.structured
                          ? detailWindow.isWriter
                            ? qsTrId("entity.writer")
                            : qsTrId("entity.reader")
                          : qsTrId("entity.endpoint")
                    font.pixelSize: Constants.pageTitleFontSize
                    font.bold: true
                }

                Label {
                    visible: detailWindow.structured
                    text: detailWindow.topicName
                    color: detailWindow.secondaryTextColor
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                visible: detailWindow.hasQosMismatch
                Layout.preferredWidth: mismatchLabel.implicitWidth + 16
                Layout.preferredHeight: 24
                radius: 12
                color: rootWindow.isDarkMode ? "#55451f" : "#fff1cf"
                border.width: 1
                border.color: Constants.warningColor

                Label {
                    id: mismatchLabel
                    anchors.centerIn: parent
                    text: qsTrId("endpoint.qos.mismatch")
                    font.bold: true
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                spacing: 10

                Rectangle {
                    visible: detailWindow.structured
                    Layout.fillWidth: true
                    implicitHeight: identityGrid.implicitHeight + 20
                    radius: Constants.cardRadius
                    color: detailWindow.surfaceColor
                    border.width: 1
                    border.color: detailWindow.borderColor

                    GridLayout {
                        id: identityGrid
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 9

                        DetailValue {
                            label: qsTrId("entity.process")
                            value: detailWindow.processName
                        }
                        DetailValue {
                            label: qsTrId("entity.process.id")
                            value: detailWindow.processId
                        }
                        DetailValue {
                            label: qsTrId("entity.host")
                            value: detailWindow.hostname
                        }
                        DetailValue {
                            label: qsTrId("entity.addresses")
                            value: detailWindow.addresses
                        }
                        DetailValue {
                            label: qsTrId("entity.topic")
                            value: detailWindow.topicName
                        }
                        DetailValue {
                            label: qsTrId("qos.topic.type")
                            value: detailWindow.topicType
                        }
                    }
                }

                Rectangle {
                    visible: detailWindow.structured
                    Layout.fillWidth: true
                    implicitHeight: identifiersColumn.implicitHeight + 20
                    radius: Constants.cardRadius
                    color: detailWindow.surfaceColor
                    border.width: 1
                    border.color: detailWindow.borderColor

                    ColumnLayout {
                        id: identifiersColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        Label {
                            text: qsTrId("endpoint.identifiers")
                            font.bold: true
                        }
                        DetailValue {
                            label: qsTrId("entity.endpoint.key")
                            value: detailWindow.endpointKey
                        }
                        DetailValue {
                            label: qsTrId("entity.participant.key")
                            value: detailWindow.participantKey
                        }
                        DetailValue {
                            label: qsTrId("entity.instance.handle")
                            value: detailWindow.instanceHandle
                        }
                        DetailValue {
                            label: qsTrId("entity.type.id")
                            value: detailWindow.typeId
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: qosColumn.implicitHeight + 20
                    radius: Constants.cardRadius
                    color: detailWindow.surfaceColor
                    border.width: 1
                    border.color: detailWindow.hasQosMismatch
                                  ? Constants.warningColor
                                  : detailWindow.borderColor

                    ColumnLayout {
                        id: qosColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 7

                        Label {
                            text: detailWindow.structured
                                  ? qsTrId("qos.full.name")
                                  : qsTrId("tab.details")
                            font.bold: true
                        }

                        Label {
                            visible: detailWindow.hasQosMismatch
                                     && detailWindow.qosMismatchText.length > 0
                            Layout.fillWidth: true
                            text: detailWindow.qosMismatchText
                            wrapMode: Text.Wrap
                            color: Constants.warningColor
                        }

                        TextEdit {
                            Layout.fillWidth: true
                            text: detailWindow.structured
                                  ? detailWindow.qos
                                  : detailWindow.endpointText
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            color: rootWindow.isDarkMode
                                   ? "#e5e5e5" : "#303030"
                        }
                    }
                }
            }
        }
    }
}
