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
    property bool hasQosMissmatch: false

    EndpointModel {
        id: endpointWriterModel
    }

    EndpointModel {
        id: endpointReaderModel
    }

    Connections {
        target: endpointWriterModel
        function onTopicHasQosMissmatchSignal(missmatch) {
            topicEndpointView.hasQosMissmatch = missmatch
        }
    }

    Component.onCompleted: {
        console.log("TopicEndpointView for topic:", topicName, ", domainId:", domainId)
        endpointWriterModel.setDomainId(parseInt(domainId), topicName, 4)
        endpointReaderModel.setDomainId(parseInt(domainId), topicName, 3)
    }

    Column {
        anchors.fill: parent
        padding: 10

        ScrollView {
            contentWidth: topicEndpointView.width
            height: topicEndpointView.height

            Column {
                width: parent.width - 20
                spacing: 10

                Row {
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
                        height: 1
                        width: topicEndpointView.width - headlineLabel.width - warning_triangle.width - 20
                    }

                    WarningTriangle {
                        id: warning_triangle
                        width: 30
                        height: 30
                        Layout.alignment: Qt.AlignVCenter
                        enableTooltip: true
                        tooltipText: "Qos missmatch detected."
                        visible: topicEndpointView.hasQosMissmatch
                    }
                }

                Row {
                    width: parent.width - 10

                    Column {
                        width: parent.width / 2

                        Label {
                            text: "Writer"
                        }

                        ListView {
                            id: listViewWriter
                            model: endpointWriterModel
                            width: parent.width
                            height: contentHeight
                            clip: true
                            interactive: false

                            delegate: Item {
                                height: 50
                                width: listViewWriter.width

                                Rectangle {
                                    id: writerRec
                                    property bool showTooltip: false

                                    anchors.fill: parent
                                    color: rootWindow.isDarkMode ? mouseAreaEndpointWriter.pressed ? Constants.darkPressedColor : Constants.darkCardBackgroundColor : mouseAreaEndpointWriter.pressed ? Constants.lightPressedColor : Constants.lightCardBackgroundColor
                                    border.color: endpoint_has_qos_missmatch ? Constants.warningColor : rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
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
                                        text: "Key: " +endpoint_key + "\nParticipant Key:" + endpoint_participant_key + "\nInstance Handle: " + endpoint_participant_instance_handle + "\nTopic Name:" + endpoint_topic_name + "\nTopic Type: " + endpoint_topic_type + endpoint_qos_missmatch_text + "\nQos:\n" + endpoint_qos + "\nType Id: " + endpoint_type_id
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
                        width: 10
                        height: 10
                    }

                    Column {
                        width: parent.width / 2

                        Label {
                            text: "Reader"
                        }
                        ListView {
                            id: listViewReader
                            model: endpointReaderModel
                            width: parent.width
                            height: contentHeight
                            clip: true
                            interactive: false

                            delegate: Item {
                                height: 50
                                width: listViewReader.width

                                Rectangle {
                                    anchors.fill: parent
                                    color: rootWindow.isDarkMode ? mouseAreaEndpointReader.pressed ? Constants.darkPressedColor : Constants.darkCardBackgroundColor : mouseAreaEndpointReader.pressed ? Constants.lightPressedColor : Constants.lightCardBackgroundColor
                                    border.color: endpoint_has_qos_missmatch ? Constants.warningColor : rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
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
                                        text: "Key: " + endpoint_key + "\nParticipant Key:" + endpoint_participant_key + "\nInstance Handle: " + endpoint_participant_instance_handle + "\nTopic Name:" + endpoint_topic_name + "\nTopic Type: " + endpoint_topic_type + endpoint_qos_missmatch_text + "\nQos:\n" + endpoint_qos + "\nType Id: " + endpoint_type_id
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
}
