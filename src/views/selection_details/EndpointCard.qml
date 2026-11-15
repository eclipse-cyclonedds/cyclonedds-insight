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
import QtQuick.Layouts

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"

Item {
    id: card
    objectName: "endpointCard"

    required property bool isWriter
    required property var readerModel
    required property var writerModel
    required property int domainId

    signal createEndpointRequested(int entityType)
    required property string endpoint_key
    required property string endpoint_participant_key
    required property string endpoint_participant_instance_handle
    required property string endpoint_topic_name
    required property string endpoint_topic_type
    required property string endpoint_qos
    required property string endpoint_type_id
    required property string endpoint_hostname
    required property string endpoint_process_id
    required property string endpoint_process_name
    required property string addresses
    required property bool endpoint_has_qos_mismatch
    required property string endpoint_qos_mismatch_text
    required property var partitions
    required property bool has_partitions

    width: ListView.view ? ListView.view.width : 0
    height: 104

    readonly property var ownerModel: card.isWriter ? testerModel : listenerModel
    property bool isManagedEndpoint: false
    readonly property color ownerColor: Constants.endpointOwnerColor(rootWindow.isDarkMode)

    function refreshOwnership() {
        isManagedEndpoint = ownerModel
            && ownerModel.endpointIdForGuid(domainId, endpoint_key) !== ""
    }

    Component.onCompleted: refreshOwnership()
    onOwnerModelChanged: refreshOwnership()
    onDomainIdChanged: refreshOwnership()
    onEndpoint_keyChanged: refreshOwnership()

    Connections {
        target: card.ownerModel
        function onRowsInserted() { card.refreshOwnership() }
        function onRowsRemoved() { card.refreshOwnership() }
        function onModelReset() { card.refreshOwnership() }
        function onDataChanged() { card.refreshOwnership() }
    }

    readonly property color accentColor: card.isWriter
        ? rootWindow.isDarkMode ? "#8cc8ff" : "#145c9e"
        : Constants.accentColor

    readonly property string endpointDetails:
        "Key: " + endpoint_key
        + "\nParticipant Key: " + endpoint_participant_key
        + "\nInstance Handle: " + endpoint_participant_instance_handle
        + "\nTopic Name: " + endpoint_topic_name
        + "\nTopic Type: " + endpoint_topic_type
        + endpoint_qos_mismatch_text
        + "\nQos:\n" + endpoint_qos
        + "\nType Id: " + endpoint_type_id

    function openDetails(globalPosition) {
        if (detailWindow.visible) {
            detailWindow.raise()
            return
        }
        detailWindow.x = globalPosition.x - detailWindow.width / 2
        detailWindow.y = globalPosition.y
        detailWindow.visible = true
    }

    function openContextMenu() {
        refreshOwnership()
        const menu = isManagedEndpoint ? managedEndpointMenu : endpointMenu
        menu.popup()
    }

    Action {
        id: createReaderAction
        text: qsTrId("listener.create.reader")
        onTriggered: card.createEndpointRequested(3)
    }

    Action {
        id: createWriterAction
        text: qsTrId("tester.create.writer")
        onTriggered: card.createEndpointRequested(4)
    }

    Menu {
        id: endpointMenu
        objectName: "endpointContextMenu"

        MenuItem {
            objectName: "createReaderAction"
            action: createReaderAction
        }

        MenuItem {
            objectName: "createWriterAction"
            action: createWriterAction
        }
    }

    // Keep native menu contents stable while the platform tracks hover and selection.
    Menu {
        id: managedEndpointMenu
        objectName: "managedEndpointContextMenu"

        MenuItem {
            objectName: "createReaderAction"
            action: createReaderAction
        }

        MenuItem {
            objectName: "createWriterAction"
            action: createWriterAction
        }

        MenuSeparator {}

        MenuItem {
            objectName: "deleteEndpointAction"
            text: qsTrId("endpoint.delete")
            onTriggered: {
                if (card.isWriter) {
                    testerModel.deleteEndpoint(card.domainId, card.endpoint_key)
                } else {
                    listenerModel.deleteEndpoint(card.domainId, card.endpoint_key)
                }
            }
        }
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        anchors.leftMargin: 1
        anchors.rightMargin: 6
        anchors.bottomMargin: 8
        radius: Constants.cardRadius
        color: cardMouseArea.pressed
               ? rootWindow.isDarkMode ? "#3d3d3d" : "#e3e3e3"
               : cardMouseArea.containsMouse
                 ? rootWindow.isDarkMode ? "#383838" : "#ededed"
                 : Constants.cardBackgroundColor(rootWindow.isDarkMode)
        border.width: 1
        border.color: card.endpoint_has_qos_mismatch
                      ? Constants.warningColor
                      : cardMouseArea.containsMouse
                        ? rootWindow.isDarkMode ? "#666666" : "#c2c2c2"
                        : Constants.designBorderColor(rootWindow.isDarkMode)

        Rectangle {
            objectName: "endpointOwnerStripe"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 2
            anchors.topMargin: Constants.cardRadius
            anchors.bottomMargin: Constants.cardRadius
            width: 3
            radius: 1.5
            color: card.ownerColor
            visible: card.isManagedEndpoint
        }

        MouseArea {
            id: cardMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    card.openContextMenu()
                } else {
                    card.openDetails(mapToGlobal(mouse.x, mouse.y))
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: card.isManagedEndpoint ? 16 : 12
            anchors.rightMargin: 10
            anchors.topMargin: 6
            anchors.bottomMargin: 5
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Constants.warningColor
                    visible: card.endpoint_has_qos_mismatch
                }

                Label {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: card.endpoint_process_name.length > 0
                          ? card.endpoint_process_name
                          : qsTrId("entity.process.unknown")
                    font.bold: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    objectName: "endpointOwnerBadge"
                    Layout.preferredWidth: ownerLabel.implicitWidth + 12
                    Layout.preferredHeight: 20
                    radius: Constants.badgeRadius
                    color: Qt.rgba(card.ownerColor.r, card.ownerColor.g, card.ownerColor.b,
                                   rootWindow.isDarkMode ? 0.18 : 0.1)
                    border.color: Qt.rgba(card.ownerColor.r, card.ownerColor.g, card.ownerColor.b, 0.4)
                    visible: card.isManagedEndpoint

                    Label {
                        id: ownerLabel
                        objectName: "endpointOwnerLabel"
                        anchors.centerIn: parent
                        text: card.isWriter ? qsTrId("tab.tester") : qsTrId("tab.listener")
                        color: card.ownerColor
                        font.pixelSize: Constants.captionFontSize
                        font.bold: true
                    }
                }

                Label {
                    text: card.endpoint_process_id.length > 0
                          ? qsTrId("entity.pid.value").arg(card.endpoint_process_id)
                          : ""
                    visible: text.length > 0
                    opacity: 0.6
                }
            }

            Label {
                id: hostAddressLabel
                Layout.fillWidth: true
                text: card.endpoint_hostname
                      + (card.addresses.length > 0
                         ? "  |  " + card.addresses
                         : "")
                font.pixelSize: Constants.bodyFontSize
                color: rootWindow.isDarkMode ? Constants.darkMutedForeground : "#454545"
                elide: Text.ElideRight

                HoverHandler {
                    id: hostAddressHover
                }

                ToolTip {
                    parent: hostAddressLabel
                    visible: hostAddressHover.hovered
                             && hostAddressLabel.truncated
                    delay: 500
                    text: hostAddressLabel.text
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                text: card.endpoint_key
                color: rootWindow.isDarkMode ? "#a8a8a8" : "#666666"
                font.pixelSize: Constants.captionFontSize
                fontSizeMode: Text.HorizontalFit
                verticalAlignment: Text.AlignVCenter
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: endpointActions.width + 6
                spacing: 6

                Label {
                    text: qsTrId("endpoint.no.partition")
                    visible: !card.has_partitions
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    contentWidth: partitionRow.width
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    visible: card.has_partitions

                    Row {
                        id: partitionRow
                        spacing: 5

                        Repeater {
                            model: card.partitions

                            Rectangle {
                                height: 18
                                width: partitionLabel.implicitWidth + 12
                                radius: 4
                                color: partition_matched
                                       ? "#258a4b"
                                       : rootWindow.isDarkMode ? "#292929" : "#eeeeee"
                                border.width: partition_selected ? 2 : 1
                                border.color: partition_selected
                                              ? Constants.warningColor
                                              : partition_matched ? "#35b86b"
                                                                  : rootWindow.isDarkMode ? "#555555" : "#d0d0d0"

                                Label {
                                    id: partitionLabel
                                    anchors.centerIn: parent
                                    text: partition_name
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (partition_selected) {
                                            card.readerModel.clearPartitionMatching()
                                            card.writerModel.clearPartitionMatching()
                                        } else if (card.isWriter) {
                                            card.readerModel.setSelectedPartition(partition_name, "")
                                            card.writerModel.setSelectedPartition(
                                                partition_name, card.endpoint_key)
                                        } else {
                                            card.readerModel.setSelectedPartition(
                                                partition_name, card.endpoint_key)
                                            card.writerModel.setSelectedPartition(partition_name, "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }

        Row {
            id: endpointActions
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 10
            anchors.bottomMargin: 5
            spacing: 4
            height: 18

            Rectangle {
                id: previewButton
                width: previewLabel.implicitWidth + 12
                height: parent.height
                radius: 4
                color: previewMouseArea.containsMouse
                       ? rootWindow.isDarkMode ? "#444444" : "#d9d9d9"
                       : rootWindow.isDarkMode ? "#292929" : "#eeeeee"
                border.width: 1
                border.color: rootWindow.isDarkMode ? "#666666" : "#b5b5b5"

                Label {
                    id: previewLabel
                    anchors.centerIn: parent
                    text: qsTrId("endpoint.preview")
                    color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                }

                MouseArea {
                    id: previewMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                ToolTip {
                    id: endpointPreview
                    parent: previewButton
                    visible: previewMouseArea.containsMouse
                    delay: 400
                    text: card.endpointDetails
                    contentItem: Label {
                        text: endpointPreview.text
                    }
                    background: Rectangle {
                        border.color: Constants.borderColor(rootWindow.isDarkMode)
                        border.width: 1
                        color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
                        radius: Constants.controlRadius
                    }
                }
            }

        }
    }

    EndpointDetailWindow {
        id: detailWindow
        title: (card.isWriter
                ? qsTrId("entity.writer.value")
                : qsTrId("entity.reader.value")).arg(card.endpoint_key)
        endpointText: card.endpointDetails
        structured: true
        isWriter: card.isWriter
        endpointKey: card.endpoint_key
        participantKey: card.endpoint_participant_key
        instanceHandle: card.endpoint_participant_instance_handle
        topicName: card.endpoint_topic_name
        topicType: card.endpoint_topic_type
        typeId: card.endpoint_type_id
        hostname: card.endpoint_hostname
        processId: card.endpoint_process_id
        processName: card.endpoint_process_name
        addresses: card.addresses
        qos: card.endpoint_qos
        hasQosMismatch: card.endpoint_has_qos_mismatch
        qosMismatchText: card.endpoint_qos_mismatch_text
    }
}
