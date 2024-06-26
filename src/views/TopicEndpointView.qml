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


Rectangle {
    id: topicEndpointView
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent

    property int domainId
    property string topicName
    property bool hasQosMismatch: false
    property int writerCount: 0
    property int readerCount: 0

    EndpointModel {
        id: endpointWriterModel
    }

    EndpointModel {
        id: endpointReaderModel
    }

    Connections {
        target: endpointWriterModel
        function onTopicHasQosMismatchSignal(mismatch) {
            topicEndpointView.hasQosMismatch = mismatch
        }

        function onTotalEndpointsSignal(count) {
            topicEndpointView.writerCount = count
        }
    }

    Connections {
        target: endpointReaderModel
        function onTopicHasQosMismatchSignal(mismatch) {
            topicEndpointView.hasQosMismatch = mismatch
        }

        function onTotalEndpointsSignal(count) {
            topicEndpointView.readerCount = count
        }
    }

    Component.onCompleted: {
        console.log("TopicEndpointView for topic:", topicName, ", domainId:", domainId)
        endpointWriterModel.setDomainId(parseInt(domainId), topicName, 4)
        endpointReaderModel.setDomainId(parseInt(domainId), topicName, 3)
    }

    ColumnLayout  {
        anchors.fill: parent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            Layout.leftMargin: 1

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 10
                Layout.rightMargin: 10

                Column {
                    id: headlineLabel
                    Label {
                        text: "Domain Id: " + domainId
                    }
                    Label {
                        text: "Topic Name: " + topicName
                    }
                }

                Item {
                    Layout.preferredHeight: 1
                    Layout.fillWidth: true
                }

                WarningTriangle {
                    id: warning_triangle
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 30
                    enableTooltip: true
                    tooltipText: "Qos mismatch detected."
                    visible: topicEndpointView.hasQosMismatch
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Layout.leftMargin: 10

                    Label {
                        text: "Writer (Total: " + writerCount + ")"
                    }

                    ListView {
                        id: listViewWriter
                        model: endpointWriterModel
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        interactive: true
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Item {
                            height: 50
                            width: listViewWriter.width

                            Rectangle {
                                id: writerRec
                                property bool showTooltip: false

                                anchors.fill: parent
                                color: rootWindow.isDarkMode ? mouseAreaEndpointWriter.pressed ? Constants.darkPressedColor : Constants.darkCardBackgroundColor : mouseAreaEndpointWriter.pressed ? Constants.lightPressedColor : Constants.lightCardBackgroundColor
                                border.color: endpoint_has_qos_mismatch ? Constants.warningColor : rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
                                border.width: 0.5
                                Column {
                                    spacing: 0
                                    padding: 10

                                    Label {
                                        text: endpoint_key
                                        font.pixelSize: 14
                                    }
                                    Label {
                                        text: endpoint_process_name + ":" + endpoint_process_id + "@" + endpoint_hostname
                                        font.pixelSize: 12
                                    }
                                }
                                MouseArea {
                                    id: mouseAreaEndpointWriter
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        writerRec.showTooltip = true
                                    }
                                    onExited: {
                                        writerRec.showTooltip = false
                                    }
                                }
                                ToolTip {
                                    id: writerTooltip
                                    parent: writerRec
                                    visible: writerRec.showTooltip
                                    delay: 200
                                    text: "Key: " +endpoint_key + "\nParticipant Key:" + endpoint_participant_key + "\nInstance Handle: " + endpoint_participant_instance_handle + "\nTopic Name:" + endpoint_topic_name + "\nTopic Type: " + endpoint_topic_type + endpoint_qos_mismatch_text + "\nQos:\n" + endpoint_qos + "\nType Id: " + endpoint_type_id
                                    contentItem: Label {
                                        text: writerTooltip.text
                                    }
                                    background: Rectangle {
                                        border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
                                        border.width: 1
                                        color: rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredHeight : 1
                    Layout.preferredWidth : 2
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Layout.leftMargin: 1
                    Layout.rightMargin: 10

                    Label {
                        text: "Reader (Total: " + readerCount + ")"
                    }
                    ListView {
                        id: listViewReader
                        model: endpointReaderModel
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        interactive: true

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Item {
                            height: 50
                            width: listViewReader.width

                            Rectangle {
                                anchors.fill: parent
                                color: rootWindow.isDarkMode ? mouseAreaEndpointReader.pressed ? Constants.darkPressedColor : Constants.darkCardBackgroundColor : mouseAreaEndpointReader.pressed ? Constants.lightPressedColor : Constants.lightCardBackgroundColor
                                border.color: endpoint_has_qos_mismatch ? Constants.warningColor : rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
                                border.width: 0.5
                                id: readerRec
                                property bool showTooltip: false

                                Column {
                                    spacing: 0
                                    padding: 10

                                    Label {
                                        text: endpoint_key
                                        font.pixelSize: 14
                                    }
                                    Label {
                                        text: endpoint_process_name + ":" + endpoint_process_id + "@" + endpoint_hostname
                                        font.pixelSize: 12
                                    }
                                }
                                MouseArea {
                                    id: mouseAreaEndpointReader
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        readerRec.showTooltip = true
                                    }
                                    onExited: {
                                        readerRec.showTooltip = false
                                    }
                                }
                                ToolTip {
                                    id: readerTooltip
                                    parent: readerRec
                                    visible: readerRec.showTooltip
                                    delay: 200
                                    text: "Key: " + endpoint_key + "\nParticipant Key:" + endpoint_participant_key + "\nInstance Handle: " + endpoint_participant_instance_handle + "\nTopic Name:" + endpoint_topic_name + "\nTopic Type: " + endpoint_topic_type + endpoint_qos_mismatch_text + "\nQos:\n" + endpoint_qos + "\nType Id: " + endpoint_type_id
                                    contentItem: Label {
                                        text: readerTooltip.text
                                    }
                                    background: Rectangle {
                                        border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
                                        border.width: 1
                                        color: rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
