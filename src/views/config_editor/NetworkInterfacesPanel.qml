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

Rectangle {
    id: panel
    property bool expanded: false
    implicitHeight: panelLayout.implicitHeight + 16
    color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    radius: Constants.cardRadius
    border.width: 1
    border.color: Constants.designBorderColor(rootWindow.isDarkMode)

    onExpandedChanged: if (expanded) ddsConfig.refreshNetworkInterfaces()
    onVisibleChanged: if (visible && expanded) ddsConfig.refreshNetworkInterfaces()

    ColumnLayout {
        id: panelLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6

        Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: qsTrId("config.network.interfaces")
            wrapMode: Text.WordWrap
            font.bold: true
        }

        ListView {
            id: interfacesList
            visible: panel.expanded
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(190, Math.max(48, contentHeight))
            clip: true
            spacing: 8
            model: ddsConfig.networkInterfaces
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                id: interfacesScrollBar
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                required property var modelData
                width: interfacesList.width - (interfacesScrollBar.visible ? interfacesScrollBar.width + 6 : 0)
                implicitHeight: adapterContent.implicitHeight + 20
                radius: Constants.controlRadius
                color: rootWindow.isDarkMode ? "#292929" : "#f5f6f8"

                ColumnLayout {
                    id: adapterContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 5

                    TextEdit {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: modelData.name
                        color: rootWindow.isDarkMode ? "#eeeeee" : "#262626"
                        font.bold: true
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        textFormat: TextEdit.PlainText
                    }
                    Label {
                        visible: modelData.displayName.length > 0 && modelData.displayName !== modelData.name
                        Layout.fillWidth: true
                        text: modelData.displayName
                        color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                        wrapMode: Text.WrapAnywhere
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Constants.separatorColor(rootWindow.isDarkMode)
                    }
                    Repeater {
                        model: modelData.addresses

                        RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: 8

                            TextEdit {
                                id: addressText
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: modelData
                                color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.WrapAnywhere
                                textFormat: TextEdit.PlainText
                            }
                            Button {
                                objectName: "copyNetworkAddress"
                                text: qsTrId("config.network.copy.address")
                                onClicked: {
                                    addressText.selectAll()
                                    addressText.copy()
                                    addressText.deselect()
                                }
                            }
                        }
                    }
                }
            }

            Label {
                anchors.fill: parent
                visible: interfacesList.count === 0
                text: qsTrId("config.network.empty")
                color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }

        RowLayout {
            visible: panel.expanded
            Layout.fillWidth: true

            Button {
                text: qsTrId("general.reload")
                onClicked: ddsConfig.refreshNetworkInterfaces()
            }

        }
    }
}
