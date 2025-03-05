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


ColumnLayout {
    anchors.fill: parent
    spacing: 0

    RowLayout {
        spacing: 0

        ComboBox {
            id: viewSelector
            model: ["Topic View", "Participant View"]
            Layout.fillWidth: true
        }

        Button {
            id: addDomainButton
            text: "+"
            onClicked: menu.open()
            hoverEnabled: true
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

            Menu {
                id: menu
                y: addDomainButton.height

                MenuItem {
                    text: qsTr("Add domain")
                    onClicked: addDomainView.open()
                }
                MenuItem {
                    text: qsTr("Automatically discover domains")
                    onClicked: treeModel.scanDomains()
                }
            }
            ToolTip {
                id: addDomainTooltip
                parent: addDomainButton
                visible: addDomainButton.hovered
                delay: 200
                text: qsTr("Add domain manually or discover automatically")
                contentItem: Label {
                    text: addDomainTooltip.text
                }
                background: Rectangle {
                    border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
                    border.width: 1
                    color: rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor
                }
            }
        }

        Button {
            id: removeDomainButton
            text: "-"
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            onClicked: {
                if (viewSelector.currentIndex === 0) {
                    if (treeModel.getIsRowDomain(topicOverview.getCurrentIndex())) {
                        treeModel.removeDomainRequest(topicOverview.getCurrentIndex())
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
                text: qsTr("Remove the selected domain")
                contentItem: Label {
                    text: removeDomainTooltip.text
                }
                background: Rectangle {
                    border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
                    border.width: 1
                    color: rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor
                }
            }
        }
    }

    TopicOverview {
        id: topicOverview
        visible: viewSelector.currentIndex === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 10
    }

    ParticipantsOverview {
        id: participantOverview
        visible: viewSelector.currentIndex === 1
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 10
    }
}
