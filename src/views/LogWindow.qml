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


Window {
    id: logWindowId
    property string endpointText

    title: "Log Window"
    visible: false
    width: 800
    height: 450
    minimumHeight: 100
    minimumWidth: 700
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint

    property bool autoScrollEnabled: true
    property string logCache: ""
    property int maxLength: 10000
    property int removeLength: 2500

    Rectangle {
        anchors.fill: parent
        color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground
        border.color : autoScrollEnabled ? "transparent" : "orange"
        border.width : 2
    }

    Label {
        id: colorLabel
        visible: false
    }

    function logClear() {
        logTextArea.text = ""
        logCache = ""
    }

    Connections {
        target: loggerConfig
        function onLogMessage(out) {
            if (autoScrollEnabled) {
                logTextArea.append(out)
                if (logTextArea.text.length >= logWindowId.maxLength) {
                    logTextArea.remove(0, removeLength)
                    logTextArea.insert(0, "Previous output was removed.\n")
                }
            } else {
                logCache += out + "\n"
            }
        }
        function onLogLevelChanged(logLevel) {
            if (logLevel === "CRITICAL") {
                logLevelCriticalId.checked = true
            } else if (logLevel === "ERROR") {
                logLevelErrorId.checked = true
            } else if (logLevel === "WARNING") {
                logLevelWarningId.checked = true
            } else if (logLevel === "INFO") {
                logLevelInfoId.checked = true
            } else if (logLevel === "DEBUG") {
                logLevelDebugId.checked = true
            } else if (logLevel === "TRACE") {
                logLevelTraceId.checked = true
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.minimumHeight: 40
            Layout.maximumHeight: 40
            spacing: 10

            Item {
                implicitHeight: 1
                implicitWidth: 1
            }
            Button {
                text: "Clear Log"
                onClicked: logClear()
            }
            Button {
                text: logWindowId.autoScrollEnabled ? "Pause Log" : "Resume Log"
                onClicked: {
                    logWindowId.autoScrollEnabled = !logWindowId.autoScrollEnabled
                    if (logWindowId.autoScrollEnabled) {
                        if (logCache.length > 0) {
                            logTextArea.append(logCache.slice(0, -1))
                        }
                        logCache = ""
                        logTextArea.cursorPosition = logTextArea.length
                        scrollView.contentY = logTextArea - scrollView.height
                    } else {
                        logTextArea.cursorPosition = logTextArea.cursorPosition - 1
                    }
                }
            }
            RadioButton {
                id: logLevelCriticalId
                text: "CRITICAL"
                checked: false
                checkable: true
                onClicked: {
                    if (checked) {
                        loggerConfig.setGlobalLogLevel("CRITICAL")
                    }
                }
            }
            RadioButton {
                id: logLevelErrorId
                text: "ERROR"
                checked: false
                checkable: true
                onClicked: {
                    if (checked) {
                        loggerConfig.setGlobalLogLevel("ERROR")
                    }
                }
            }
            RadioButton {
                id: logLevelWarningId
                text: "WARNING"
                checked: false
                checkable: true
                onClicked: {
                    if (checked) {
                        loggerConfig.setGlobalLogLevel("WARNING")
                    }
                }
            }
            RadioButton {
                id: logLevelInfoId
                text: "INFO"
                checked: false
                checkable: true
                onClicked: {
                    if (checked) {
                        loggerConfig.setGlobalLogLevel("INFO")
                    }
                }
            }
            RadioButton {
                id: logLevelDebugId
                text: "DEBUG"
                checked: false
                checkable: true
                onClicked: {
                    if (checked) {
                        loggerConfig.setGlobalLogLevel("DEBUG")
                    }
                }
            }
            RadioButton {
                id: logLevelTraceId
                text: "TRACE"
                checked: false
                checkable: true
                onClicked: {
                    if (checked) {
                        loggerConfig.setGlobalLogLevel("TRACE")
                    }
                }
            }
            Item {
                implicitHeight: 1
                Layout.fillWidth: true
            }
            Item {
                implicitHeight: 1
                implicitWidth: 1
            }
        }

        Rectangle {
            color: rootWindow.isDarkMode ? "black" : "white"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 3

            Flickable {
                id: scrollView
                anchors.fill: parent
                boundsBehavior: Flickable.StopAtBounds
                interactive: true
                ScrollBar.vertical: ScrollBar {}

                TextArea.flickable: TextArea {
                    id: logTextArea
                    readOnly: true
                    tabStopDistance: 40
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    selectByKeyboard: true
                    onContentHeightChanged: {
                        if (logWindowId.autoScrollEnabled) {
                            logTextArea.cursorPosition = logTextArea.length
                            scrollView.contentY = logTextArea.height - scrollView.height
                        }
                    }
                    onPressed: logWindowId.autoScrollEnabled = false
                }
            }
        }
    }

    Component.onCompleted: {
        loggerConfig.requestCurrentLogLevel()
    }
}
