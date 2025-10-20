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

ToolBar {
    topPadding: 10
    bottomPadding: 10
    leftPadding: 10
    rightPadding: 10
    property bool isHeaderSpinning: false

    background: Rectangle {
        anchors.fill: parent
        color: rootWindow.isDarkMode ? Constants.darkHeaderBackground : Constants.lightHeaderBackground
    }

    Connections {
        target: treeModel
        function onDiscover_domains_running_signal(active) {
            isHeaderSpinning = active;
        }
    }

    RowLayout {
        anchors.fill: parent

        Item {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30

            Image {
                visible: !isHeaderSpinning
                source: "qrc:/res/images/cyclonedds.png"
                sourceSize.width: 30
                sourceSize.height: 30
            }
            AnimatedImage {
                id: headerLoadingId
                source: "qrc:/res/images/spinning.gif"
                visible: isHeaderSpinning
                playing: isHeaderSpinning
                paused: !isHeaderSpinning
                sourceSize.height: 30
                sourceSize.width: 30
                height: 30
                width: 30
            }
        }

        Label {
            text: rootWindow.title
        }
        Item {
            Layout.fillWidth: true
        }
        ToolButton {
            id: menuButton
            text: "\u2630"
            onClicked: menu.open()
            flat: true
            font.pixelSize: 15

            Menu {
                id: menu
                y: menuButton.height

                MenuItem {
                    text: "Home"
                    onClicked: layout.currentIndex = 1
                }
                MenuItem {
                    text: "Shapes Demo"
                    onClicked: shapeDemoViewId.visible = true
                }
                MenuItem {
                    text: "Settings"
                    onClicked: layout.currentIndex = 0
                }
                MenuItem {
                    text: "Configuration Editor"
                    onTriggered: layout.currentIndex = 2
                }
                MenuItem {
                    text: "Show Log Window"
                    onTriggered: logViewId.visible = true
                }
                MenuItem {
                    text: "Export DDS Entities (JSON)"
                    onTriggered: exportDdsSystemFileDialog.open()
                }
                MenuItem {
                    text: "Check for Updates"
                    onTriggered: checkForUpdatesWindow.showAndCheckForUpdates()
                }
                MenuItem {
                    text: "About"
                    onClicked: aboutWindow.visible = true
                }
            }
        }
    }
}
