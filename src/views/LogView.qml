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
import "qrc:/src/views/elements"

Rectangle {
    id: logView

    property bool autoScrollEnabled: true
    readonly property color borderColor: Constants.designBorderColor(rootWindow.isDarkMode)
    property string logCache: ""
    readonly property var logLevels: ["CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG", "TRACE"]
    property int maxLength: 10000
    property int removeLength: 2500
    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)
    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    property var viewHost: null

    function logClear() {
        logTextArea.text = "";
        logCache = "";
    }
    function scrollToEnd() {
        logTextArea.cursorPosition = logTextArea.length;
        logScrollView.contentItem.contentY = Math.max(0, logTextArea.contentHeight - logScrollView.availableHeight);
    }
    function setAutoScroll(enabled) {
        autoScrollEnabled = enabled;
        if (enabled) {
            if (logCache.length > 0) {
                logTextArea.append(logCache.slice(0, -1));
            }
            logCache = "";
            Qt.callLater(scrollToEnd);
        }
    }

    color: Constants.mainContentColor(rootWindow.isDarkMode)

    Component.onCompleted: loggerConfig.requestCurrentLogLevel()

    Connections {
        function onLogLevelChanged(logLevel) {
            const index = logView.logLevels.indexOf(logLevel);
            if (index >= 0) {
                logLevelCombo.currentIndex = index;
            }
        }
        function onLogMessage(out) {
            if (logView.autoScrollEnabled) {
                logTextArea.append(out);
                if (logTextArea.text.length >= logView.maxLength) {
                    logTextArea.remove(0, logView.removeLength);
                    logTextArea.insert(0, "Previous output was removed.\n");
                }
            } else {
                logView.logCache += out + "\n";
            }
        }

        target: loggerConfig
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
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: Constants.pageTitleFontSize
                text: qsTrId("log.application")
            }
            Item {
                Layout.fillWidth: true
            }
            Rectangle {
                Layout.preferredHeight: 8
                Layout.preferredWidth: 8
                color: logView.autoScrollEnabled ? Constants.successColor : Constants.warningColor
                radius: 4
            }
            Label {
                font.bold: true
                text: logView.autoScrollEnabled ? qsTrId("status.live") : qsTrId("status.paused")
            }
            DetachViewButton {
                viewHost: logView.viewHost
                visible: viewHost !== null
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: 8
            columns: logView.width < 480 ? 1 : 2
            rowSpacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    text: logView.autoScrollEnabled ? qsTrId("general.pause") : qsTrId("general.resume")

                    onClicked: logView.setAutoScroll(!logView.autoScrollEnabled)
                }
                Button {
                    text: qsTrId("general.clear")

                    onClicked: logView.logClear()
                }
                Item {
                    Layout.fillWidth: true
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    color: logView.secondaryTextColor
                    text: qsTrId("log.level")
                }
                ComboBox {
                    id: logLevelCombo

                    Layout.fillWidth: true
                    Layout.preferredWidth: 125
                    model: logView.logLevels

                    onActivated: loggerConfig.setGlobalLogLevel(currentText)
                }
            }
        }
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            border.color: logView.autoScrollEnabled ? logView.borderColor : Constants.warningColor
            border.width: 1
            clip: true
            color: logView.surfaceColor
            radius: Constants.cardRadius

            ScrollView {
                id: logScrollView

                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: availableWidth

                TextEdit {
                    id: logTextArea

                    color: rootWindow.isDarkMode ? "#e4e4e4" : "#262626"
                    objectName: "logTextArea"
                    padding: 4
                    readOnly: true
                    selectByKeyboard: true
                    selectByMouse: true
                    selectedTextColor: "#ffffff"
                    selectionColor: Constants.accentColor
                    tabStopDistance: 40
                    width: logScrollView.availableWidth
                    wrapMode: TextEdit.Wrap

                    onContentHeightChanged: {
                        if (logView.autoScrollEnabled) {
                            Qt.callLater(logView.scrollToEnd);
                        }
                    }

                    TapHandler {
                        onTapped: logView.setAutoScroll(false)
                    }
                }
            }
        }
    }
}
