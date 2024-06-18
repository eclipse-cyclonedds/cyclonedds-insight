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


Rectangle {
    id: listenerTabId
    anchors.fill: parent
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

    property bool autoScrollEnabled: true
    property string logCache: ""

    function logClear() {
        listenerTextArea.text = ""
        logCache = ""
    }

    Connections {
        target: datamodelRepoModel
        function onNewDataArrived(out) {
            if (autoScrollEnabled) {
                listenerTextArea.append(out)
                if (listenerTextArea.text.length >= 5000) {
                    listenerTextArea.remove(0, 2500)
                    listenerTextArea.insert(0, "Previous output was removed.\n")
                }
            } else {
                logCache += out + "\n"
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
                text: "Clear Messages"
                onClicked: logClear()
            }
            Button {
                text: listenerTabId.autoScrollEnabled ? "Stop Scroll" : "Start Scroll"
                onClicked: {
                    listenerTabId.autoScrollEnabled = !listenerTabId.autoScrollEnabled
                    if (listenerTabId.autoScrollEnabled) {
                        if (logCache.length > 0) {
                            listenerTextArea.append(logCache.slice(0, -1))
                        }
                        logCache = ""
                        listenerTextArea.cursorPosition = listenerTextArea.length
                        scrollView.contentY = listenerTextArea - scrollView.height
                    } else {
                        listenerTextArea.cursorPosition = listenerTextArea.cursorPosition - 1
                    }
                }
            }
            Item {
                implicitHeight: 1
                Layout.fillWidth: true
            }
            Button {
                text: "Delete All Readers"
                onClicked: datamodelRepoModel.deleteAllReaders()
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

            Flickable {
                id: scrollView
                anchors.fill: parent
                boundsBehavior: Flickable.StopAtBounds
                interactive: true
                ScrollBar.vertical: ScrollBar {}

                TextArea.flickable: TextArea {
                    id: listenerTextArea
                    readOnly: true
                    tabStopDistance: 40
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    selectByKeyboard: true
                    onContentHeightChanged: {
                        if (listenerTabId.autoScrollEnabled) {
                            listenerTextArea.cursorPosition = listenerTextArea.length
                            scrollView.contentY = listenerTextArea.height - scrollView.height
                        }
                    }
                    onPressed: listenerTabId.autoScrollEnabled = false
                }
            }
        }
    }
}
