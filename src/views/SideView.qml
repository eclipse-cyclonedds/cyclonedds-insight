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
import QtQuick.Dialogs

import org.eclipse.cyclonedds.insight
import "qrc:/src/views/icons"
import "qrc:/src/views/elements"


ColumnLayout {
    id: sideView
    anchors.fill: parent
    spacing: 0

    function requestDomainRemoval() {
        if (viewSelector.currentIndex === 0) {
            if (treeModelProxy.getIsRowDomain(topicOverview.getCurrentIndex())) {
                removeDomainDialog.open()
            } else {
                noDomainSelectedDialog.open()
            }
        } else {
            if (participantModel.getIsRowDomain(participantOverview.getCurrentIndex())) {
                removeDomainDialog.open()
            } else {
                noDomainSelectedDialog.open()
            }
        }
    }

    function removePendingDomain() {
        if (viewSelector.currentIndex === 0)
            treeModelProxy.removeDomainRequest(topicOverview.getCurrentIndex())
        else
            participantModel.removeDomainRequest(participantOverview.getCurrentIndex())

        stackView.clear()
    }

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

            Rectangle {
                id: selectedSegment
                x: 2 + viewSelector.currentIndex * (width + 2)
                y: 2
                width: (viewSelector.width - 6) / 2
                height: viewSelector.height - 4
                radius: 3
                color: rootWindow.isDarkMode ? "#414141" : "#fafafa"
                border.width: 1
                border.color: rootWindow.isDarkMode ? "#535353" : "#d5d5d5"

                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

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
                        color: !selected && optionMouseArea.containsMouse
                               ? rootWindow.isDarkMode ? "#333333" : "#e0e0e0"
                               : "transparent"

                        EntityIcon {
                            id: viewOptionIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            symbol: viewOption.index === 0 ? "topic" : "participant"
                            iconColor: viewOptionLabel.color
                        }

                        Label {
                            id: viewOptionLabel
                            anchors.left: viewOptionIcon.right
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 5
                            anchors.rightMargin: 6
                            text: viewOption.modelData
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            color: rootWindow.isDarkMode
                                   ? Constants.darkMutedForeground : "#262626"
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
                                     && viewOptionLabel.truncated
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

        SidebarActionButton {
            id: addDomainButton
            isDarkMode: rootWindow.isDarkMode
            Accessible.name: qsTrId("domain.add")
            PlusMinusIcon {
                anchors.centerIn: parent
                iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
            }
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
        }

        SidebarActionButton {
            id: removeDomainButton
            isDarkMode: rootWindow.isDarkMode
            Accessible.name: qsTrId("domain.remove.selected")
            PlusMinusIcon {
                anchors.centerIn: parent
                minus: true
                iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
            }
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: viewToolbar.actionWidth
            Layout.minimumWidth: viewToolbar.actionWidth
            Layout.maximumWidth: viewToolbar.actionWidth
            Layout.preferredHeight: viewToolbar.controlHeight
            onClicked: sideView.requestDomainRemoval()
            hoverEnabled: true
        }

        SearchToggleButton {
            isDarkMode: rootWindow.isDarkMode
            expanded: searchField.visible
            opacity: viewSelector.currentIndex === 0 ? 1 : 0
            enabled: viewSelector.currentIndex === 0
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
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

    MessageDialog {
        id: removeDomainDialog
        title: qsTrId("general.alert")
        text: qsTrId("domain.remove.confirm")
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onButtonClicked: function(button, role) {
            if (role === MessageDialog.AcceptRole
                    || role === MessageDialog.YesRole)
                sideView.removePendingDomain()
        }
    }
}
