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

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"
import "qrc:/src/views/elements"


Rectangle {
    id: participantViewId
    color: Constants.mainContentColor(rootWindow.isDarkMode)

    property int domainId
    property string participantKey
    property string vendorName
    property bool qosLoaded: false

    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)

    ParticipantDetailsModel {
        id: participantModel
    }

    Component.onCompleted: {
        participantModel.start(domainId, participantKey)
    }

    Connections {
        target: participantModel

        function onUpdateQosSignal(qos) {
            qosTextArea.text = qos.startsWith("Qos:\n")
                    ? qos.substring(5)
                    : qos
            participantViewId.qosLoaded = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                DetailBadge {
                    kind: "participant"
                }

                Label {
                    text: qsTrId("participant.title")
                    font.pixelSize: Constants.pageTitleFontSize
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                spacing: 8

                Label {
                    text: qsTrId("participant.domain") + ":"
                    color: participantViewId.secondaryTextColor
                }

                Label {
                    text: participantViewId.domainId
                    font.bold: true
                }

                Label {
                    text: qsTrId("participant.vendor") + ":"
                    color: participantViewId.secondaryTextColor
                    Layout.leftMargin: 12
                }

                Label {
                    Layout.fillWidth: true
                    text: participantViewId.vendorName.length > 0
                          ? participantViewId.vendorName
                          : qsTrId("participant.unknown")
                    font.bold: true
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                spacing: 8

                Label {
                    text: qsTrId("participant.key") + ":"
                    color: participantViewId.secondaryTextColor
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 17
                    text: participantViewId.participantKey
                    color: rootWindow.isDarkMode ? "#e0e0e0" : "#303030"
                    minimumPixelSize: 8
                    fontSizeMode: Text.HorizontalFit
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        DetailGroup {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 140
            title: qsTrId("participant.qos")

            Item {
                anchors.fill: parent

                Label {
                    anchors.centerIn: parent
                    visible: !participantViewId.qosLoaded
                    text: qsTrId("participant.loading")
                    color: participantViewId.secondaryTextColor
                }

                ScrollView {
                    id: qosScrollView
                    anchors.fill: parent
                    visible: participantViewId.qosLoaded
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    TextEdit {
                        id: qosTextArea
                        width: qosScrollView.availableWidth
                        text: ""
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        padding: 0
                        color: rootWindow.isDarkMode
                               ? "#e0e0e0"
                               : "#303030"
                    }
                }
            }
        }
    }
}
