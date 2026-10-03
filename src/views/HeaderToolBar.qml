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
import "qrc:/src/views/elements"

ToolBar {
    id: headerToolBar
    topPadding: 10 + ((Qt.platform.os === "android" || Qt.platform.os === "ios") ? SafeArea.margins.top : 0)
    bottomPadding: 10
    leftPadding: 10 + ((Qt.platform.os === "android" || Qt.platform.os === "ios") ? SafeArea.margins.left : 0)
    rightPadding: 10 + ((Qt.platform.os === "android" || Qt.platform.os === "ios") ? SafeArea.margins.right : 0)
    property bool isStartupSpinning: true
    readonly property bool mobileToolbar: (Qt.platform.os === "android" || Qt.platform.os === "ios")
    readonly property int headerControlHeight: mobileToolbar ? 44 : 36
    property int startupSpinLoops: 0
    property bool isActivitySpinning: false
    readonly property bool isHeaderSpinning: isStartupSpinning || isActivitySpinning

    function startLogoSpin() {
        startupSpinLoops = 0
        isStartupSpinning = true
        headerLoadingId.currentFrame = 0
    }

    background: Rectangle {
        anchors.fill: parent
        color: Constants.headerBackgroundColor(rootWindow.isDarkMode)
    }

    Connections {
        target: treeModel
        function onDiscover_domains_running_signal(active) {
            headerToolBar.isActivitySpinning = active
        }
    }

    contentItem: RowLayout {
        spacing: 8

        Item {
            Layout.preferredWidth: 30
            Layout.minimumWidth: 30
            Layout.preferredHeight: 30

            Image {
                id: cycloneLogo
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

                onCurrentFrameChanged: {
                    if (headerToolBar.isStartupSpinning
                            && frameCount > 1
                            && currentFrame === frameCount - 1) {
                        headerToolBar.startupSpinLoops++
                        if (headerToolBar.startupSpinLoops >= 2) {
                            headerToolBar.isStartupSpinning = false
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: headerToolBar.startLogoSpin()
            }
        }

        Label {
            text: rootWindow.title
            font.pixelSize: 18
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: headerToolBar.mobileToolbar
            Layout.minimumWidth: 0
            elide: Text.ElideRight
        }
        Item {
            visible: !headerToolBar.mobileToolbar
            Layout.fillWidth: true
        }

        Rectangle {
            id: problemsButton
            implicitWidth: problemsContent.implicitWidth + 18
            Layout.minimumHeight: headerToolBar.headerControlHeight
            Layout.preferredHeight: headerToolBar.headerControlHeight
            Layout.maximumHeight: headerToolBar.headerControlHeight
            Layout.alignment: Qt.AlignVCenter
            radius: Constants.controlRadius
            color: rootWindow.problemCount > 0
                   ? problemsMouse.containsMouse
                     ? (rootWindow.isDarkMode ? "#463033" : "#fbe9eb")
                     : (rootWindow.isDarkMode ? "#35282a" : "#fff4f5")
                   : problemsMouse.containsMouse
                     ? (rootWindow.isDarkMode ? "#383838" : "#e9e9e9")
                     : (rootWindow.isDarkMode ? "#292929" : "#f5f5f5")
            border.width: 1
            border.color: rootWindow.problemCount > 0
                          ? Constants.errorColor
                          : Constants.designBorderColor(rootWindow.isDarkMode)

            Behavior on color { ColorAnimation { duration: 100 } }

            RowLayout {
                id: problemsContent
                anchors.centerIn: parent
                spacing: 6

                Item {
                    Layout.preferredWidth: 17
                    Layout.preferredHeight: 17

                    WarningTriangle {
                        anchors.fill: parent
                        visible: rootWindow.problemCount > 0
                        warningColor: Constants.errorColor
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: rootWindow.problemCount === 0
                        radius: width / 2
                        color: rootWindow.isDarkMode ? "#3a3a3a" : "#e2e2e2"
                        border.width: 1
                        border.color: Constants.designBorderColor(rootWindow.isDarkMode)

                        Label {
                            anchors.centerIn: parent
                            text: "✓"
                            color: rootWindow.isDarkMode ? "#b8b8b8" : "#5a5a5a"
                            font.bold: true
                            font.pixelSize: 10
                        }
                    }
                }

                Label {
                    text: rootWindow.problemCount > 0
                          ? qsTrId("errors.count").arg(rootWindow.problemCount)
                          : rootWindow.totalProblemCount > 0 ? qsTrId("errors.title") : qsTrId("errors.none")
                    font.bold: rootWindow.problemCount > 0
                }
            }

            MouseArea {
                id: problemsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rootWindow.openProblems()
            }
        }

        ComboBox {
            id: languageCombo
            Layout.minimumHeight: headerToolBar.headerControlHeight
            Layout.preferredHeight: headerToolBar.headerControlHeight
            Layout.maximumHeight: headerToolBar.headerControlHeight
            Layout.alignment: Qt.AlignVCenter
            topInset: 0
            bottomInset: 0
            model: langModel
            textRole: "name"
            currentIndex: langModel.currentLanguageIndex
            Layout.preferredWidth: 145
            focusPolicy: Qt.NoFocus
            onActivated: function(index) {
                langModel.loadLanguageByIndex(index)
            }
        }
        SidebarActionButton {
            id: menuButton
            isDarkMode: rootWindow.isDarkMode
            highlighted: menu.visible
            Layout.minimumHeight: headerToolBar.headerControlHeight
            Layout.preferredHeight: headerToolBar.headerControlHeight
            Layout.maximumHeight: headerToolBar.headerControlHeight
            Layout.minimumWidth: headerToolBar.headerControlHeight
            Layout.preferredWidth: headerToolBar.headerControlHeight
            Layout.maximumWidth: headerToolBar.headerControlHeight
            Layout.alignment: Qt.AlignVCenter
            topInset: 0
            bottomInset: 0
            onClicked: menu.open()
            flat: true

            MenuIcon {
                anchors.centerIn: parent
                width: 18
                height: 18
                z: 1
                iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
            }

            Menu {
                id: menu
                y: menuButton.height

                MenuItem {
                    text: qsTrId("general.home")
                    onClicked: layout.currentIndex = 1
                }
                MenuItem {
                    text: qsTrId("general.shapedemo")
                    onClicked: rootWindow.openShapesDemo()
                }
                MenuItem {
                    text: qsTrId("general.settings")
                    onClicked: layout.currentIndex = 0
                }
                MenuItem {
                    text: qsTrId("general.configeditor")
                    onTriggered: layout.currentIndex = 2
                }
                MenuItem {
                    text: qsTrId("log.show")
                    onTriggered: rootWindow.openLogs()
                }
                MenuItem {
                    text: qsTrId("general.export.ddsentities")
                    onTriggered: exportDdsSystemFileDialog.open()
                }
                MenuItem {
                    text: qsTrId("general.checkupdates")
                    enabled: !IS_MOBILE
                    onTriggered: checkForUpdatesWindow.showAndCheckForUpdates()
                }
                MenuItem {
                    text: qsTrId("general.about")
                    onClicked: rootWindow.openAbout()
                }
            }
        }
    }
}
