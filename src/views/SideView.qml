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
import "qrc:/src/views/icons"


ColumnLayout {
    anchors.fill: parent
    spacing: 0

    RowLayout {
        id: viewToolbar
        readonly property int controlHeight:
            Qt.platform.os === "osx" ? 30 : 24
        readonly property int actionWidth:
            Qt.platform.os === "osx" ? 38 : 32

        spacing: 0

        Rectangle {
            id: viewSelector
            property int currentIndex: 0

            Layout.fillWidth: true
            Layout.preferredHeight: viewToolbar.controlHeight
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            radius: 5
            color: rootWindow.isDarkMode ? "#292929" : "#e9e9e9"
            border.width: 1
            border.color: rootWindow.isDarkMode ? "#484848" : "#d0d0d0"

            Row {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 2

                Repeater {
                    model: [qsTrId("entity.topics"), qsTrId("entity.participants")]

                    Rectangle {
                        id: viewOption

                        required property int index
                        required property string modelData
                        readonly property bool selected:
                            viewSelector.currentIndex === index

                        width: (parent.width - 2) / 2
                        height: parent.height
                        radius: 3
                        color: selected
                               ? rootWindow.isDarkMode
                                 ? "#484848" : "#ffffff"
                               : optionMouseArea.containsMouse
                                 ? rootWindow.isDarkMode
                                   ? "#363636" : Constants.lightDesignBorder
                                 : rootWindow.isDarkMode
                                   ? "#242424" : "transparent"
                        border.width: 1
                        border.color: selected
                                      ? rootWindow.isDarkMode
                                        ? "#747474" : "#c6c6c6"
                                      : "transparent"

                        Rectangle {
                            visible: viewOption.selected
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 5
                            width: 2
                            height: parent.height - 8
                            radius: 1
                            color: Constants.accentColor
                        }

                        Label {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 11
                            anchors.rightMargin: 6
                            text: viewOption.modelData
                            font.bold: viewOption.selected
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            color: rootWindow.isDarkMode
                                   ? viewOption.selected
                                     ? "#ffffff" : "#b8b8b8"
                                   : "#262626"
                        }

                        MouseArea {
                            id: optionMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: viewSelector.currentIndex =
                                           viewOption.index
                        }

                        ToolTip {
                            id: viewOptionTooltip
                            parent: viewOption
                            visible: optionMouseArea.containsMouse
                                     && viewOption.width < 105
                            delay: 400
                            text: viewOption.modelData
                            contentItem: Label {
                                text: viewOptionTooltip.text
                                padding: 4
                                color: rootWindow.isDarkMode
                                       ? "#eeeeee" : "#262626"
                            }
                            background: Rectangle {
                                radius: 5
                                border.width: 1
                                border.color: Constants.borderColor(rootWindow.isDarkMode)
                                color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
                            }
                        }
                    }
                }
            }
        }

        Button {
            id: addDomainButton
            text: "+"
            onClicked: menu.open()
            hoverEnabled: true
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: viewToolbar.actionWidth
            Layout.minimumWidth: viewToolbar.actionWidth
            Layout.maximumWidth: viewToolbar.actionWidth
            Layout.preferredHeight: viewToolbar.controlHeight

            Menu {
                id: menu
                y: addDomainButton.height

                MenuItem {
                    text: qsTrId("domain.add")
                    onClicked: addDomainView.open()
                }
                MenuItem {
                    text: qsTrId("domain.discover.automatically")
                    onClicked: treeModel.scanDomains()
                }
            }
            ToolTip {
                id: addDomainTooltip
                parent: addDomainButton
                visible: addDomainButton.hovered
                delay: 200
                text: qsTrId("domain.discover.automatically.hint")
                contentItem: Label {
                    text: addDomainTooltip.text
                }
                background: Rectangle {
                    border.color: Constants.borderColor(rootWindow.isDarkMode)
                    border.width: 1
                    color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
                }
            }
        }

        Button {
            id: removeDomainButton
            text: "-"
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: viewToolbar.actionWidth
            Layout.minimumWidth: viewToolbar.actionWidth
            Layout.maximumWidth: viewToolbar.actionWidth
            Layout.preferredHeight: viewToolbar.controlHeight
            onClicked: {
                if (viewSelector.currentIndex === 0) {
                    if (treeModelProxy.getIsRowDomain(topicOverview.getCurrentIndex())) {
                        treeModelProxy.removeDomainRequest(topicOverview.getCurrentIndex())
                        stackView.clear()
                    } else {
                        noDomainSelectedDialog.open()
                    }
                } else {
                    if (participantModel.getIsRowDomain(participantOverview.getCurrentIndex())) {
                        participantModel.removeDomainRequest(participantOverview.getCurrentIndex())
                        stackView.clear()
                    } else {
                        noDomainSelectedDialog.open()
                    }
                }
            }
            hoverEnabled: true
            ToolTip {
                id: removeDomainTooltip
                parent: removeDomainButton
                visible: removeDomainButton.hovered
                delay: 200
                text: qsTrId("domain.remove.selected")
                contentItem: Label {
                    text: removeDomainTooltip.text
                }
                background: Rectangle {
                    border.color: Constants.borderColor(rootWindow.isDarkMode)
                    border.width: 1
                    color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
                }
            }
        }
        Button {
            flat: true
            highlighted: searchField.visible
            opacity: viewSelector.currentIndex === 0 ? 1 : 0
            enabled: viewSelector.currentIndex === 0
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            SearchIcon {
                anchors.centerIn: parent
                z: 1
                expanded: searchField.visible
                iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
            }
            onClicked: {
                if (viewSelector.currentIndex === 0) {
                    if (searchField.visible) {
                        searchField.clear()
                        treeModelProxy.setFilter("")
                        searchField.visible = false
                    } else {
                        searchField.visible = true
                    }
                }
            }
            Layout.preferredWidth: viewToolbar.actionWidth
            Layout.minimumWidth: viewToolbar.actionWidth
            Layout.maximumWidth: viewToolbar.actionWidth
            Layout.preferredHeight: viewToolbar.controlHeight
        }
    }

    ColumnLayout {
        visible: viewSelector.currentIndex === 0
        spacing: 0
        TextField {
            id: searchField
            placeholderText: qsTrId("general.search.placeholder")
            visible: false
            Layout.fillWidth: true
            onAccepted: {
                treeModelProxy.setFilter(searchField.text)
            }
            Keys.onEscapePressed: {
                searchField.clear()
                treeModelProxy.setFilter("")
            }
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 5

        }

        TopicOverview {
            id: topicOverview
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 10
        }
    }

    ParticipantsOverview {
        id: participantOverview
        visible: viewSelector.currentIndex === 1
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 10
    }
}
