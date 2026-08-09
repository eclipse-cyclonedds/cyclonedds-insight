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
import "qrc:/src/views/selection_details"


Window {
    id: logWindowId

    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    readonly property color borderColor: Constants.designBorderColor(rootWindow.isDarkMode)
    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)
    readonly property var logLevels: [
        "CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG", "TRACE"
    ]

    title: qsTrId("log.application")
    visible: false
    width: 860
    height: 520
    minimumHeight: 300
    minimumWidth: 620
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint | Qt.WindowTitleHint
           | Qt.WindowCloseButtonHint
    color: Constants.mainContentColor(rootWindow.isDarkMode)

    property bool autoScrollEnabled: true
    property string logCache: ""
    property int maxLength: 10000
    property int removeLength: 2500

    function logClear() {
        logTextArea.text = ""
        logCache = ""
    }

    function scrollToEnd() {
        logTextArea.cursorPosition = logTextArea.length
        logScrollView.contentItem.contentY = Math.max(
            0, logTextArea.contentHeight - logScrollView.availableHeight)
    }

    function setAutoScroll(enabled) {
        autoScrollEnabled = enabled
        if (enabled) {
            if (logCache.length > 0) {
                logTextArea.append(logCache.slice(0, -1))
            }
            logCache = ""
            Qt.callLater(scrollToEnd)
        }
    }

    Connections {
        target: loggerConfig

        function onLogMessage(out) {
            if (logWindowId.autoScrollEnabled) {
                logTextArea.append(out)
                if (logTextArea.text.length >= logWindowId.maxLength) {
                    logTextArea.remove(0, logWindowId.removeLength)
                    logTextArea.insert(0, "Previous output was removed.\n")
                }
            } else {
                logWindowId.logCache += out + "\n"
            }
        }

        function onLogLevelChanged(logLevel) {
            const index = logWindowId.logLevels.indexOf(logLevel)
            if (index >= 0) {
                logLevelCombo.currentIndex = index
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 9

            DetailBadge {
                kind: "log"
            }

            Label {
                text: qsTrId("log.application")
                font.pixelSize: Constants.pageTitleFontSize
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: logWindowId.autoScrollEnabled
                       ? Constants.successColor : Constants.warningColor
            }

            Label {
                text: logWindowId.autoScrollEnabled
                      ? qsTrId("status.live")
                      : qsTrId("status.paused")
                font.bold: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: logWindowId.autoScrollEnabled
                      ? qsTrId("general.pause")
                      : qsTrId("general.resume")
                onClicked: logWindowId.setAutoScroll(
                               !logWindowId.autoScrollEnabled)
            }

            Button {
                text: qsTrId("general.clear")
                onClicked: logWindowId.logClear()
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                text: qsTrId("log.level")
                color: logWindowId.secondaryTextColor
            }

            ComboBox {
                id: logLevelCombo
                Layout.preferredWidth: 125
                model: logWindowId.logLevels
                onActivated: loggerConfig.setGlobalLogLevel(currentText)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Constants.cardRadius
            clip: true
            color: logWindowId.surfaceColor
            border.width: 1
            border.color: logWindowId.autoScrollEnabled
                          ? logWindowId.borderColor : Constants.warningColor

            ScrollView {
                id: logScrollView
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextEdit {
                    id: logTextArea
                    width: logScrollView.availableWidth
                    readOnly: true
                    tabStopDistance: 40
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    selectByKeyboard: true
                    color: rootWindow.isDarkMode ? "#e4e4e4" : "#262626"
                    selectionColor: Constants.accentColor
                    selectedTextColor: "#ffffff"
                    padding: 4

                    onContentHeightChanged: {
                        if (logWindowId.autoScrollEnabled) {
                            Qt.callLater(logWindowId.scrollToEnd)
                        }
                    }

                    TapHandler {
                        onTapped: logWindowId.setAutoScroll(false)
                    }
                }
            }
        }
    }

    Component.onCompleted: loggerConfig.requestCurrentLogLevel()
}
