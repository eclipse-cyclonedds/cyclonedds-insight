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

import QtCore
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
    property bool started: true
    property bool autoScrollEnabled: true
    border.color : !started ? "red" : autoScrollEnabled ? "transparent" : "orange"
    border.width : 2

    ListModel {
        id: receivedDataModel
    }

    Connections {
        target: datamodelRepoModel
        function onNewDataArrived(out) {
            receivedDataModel.append({ text: out })
            if (autoScrollEnabled) {
                listView.positionViewAtEnd()
            }
            if (started === false) {
                started = true
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
                text: "Clear"
                onClicked: receivedDataModel.clear()
            }
            Button {
                text: started ? "Stop" : "Start"
                onClicked: {
                    started = !started
                    if (started) {
                        datamodelRepoModel.startListener()
                    } else {
                        datamodelRepoModel.stopListener()
                    }
                }
            }
            Item {
                implicitHeight: 1
                Layout.fillWidth: true
            }
            Button {
                text: "Import"
                onClicked: importMenu.open()
                Menu {
                    id: importMenu
                    MenuItem {
                        text: "Import Listener Preset"
                        onClicked: importListenerPresetDialog.open()
                    }
                }
            }
            Button {
                text: "Export"
                onClicked: exportMenu.open()

                Menu {
                    id: exportMenu
                    MenuItem {
                        text: "Export Listener Preset"
                        onClicked: exportListenerPresetDialog.open()
                    }
                    MenuItem {
                        text: "Export Sample Log"
                        onClicked: exportSampleLogFileDialog.open()
                    }
                }
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
            Layout.margins: 3

            ListView {
                id: listView
                anchors.fill: parent
                model: receivedDataModel
                anchors.margins: 5
                clip: true

                delegate: Column {
                    width: ListView.view.width

                    Item {
                        height: index > 0 ? 4 : 0
                        width: parent.width
                    }
                    Rectangle {
                        visible: index > 0
                        width: parent.width
                        height: 1
                        color: rootWindow.isDarkMode ? "#555555" : "#cccccc"
                    }
                    Item {
                        height: index > 0 ? 4 : 0
                        width: parent.width
                    }

                    TextEdit {
                        text: model.text
                        readOnly: true
                        color: rootWindow.isDarkMode ? "white" : "black"
                        wrapMode: Text.Wrap
                        selectByMouse: true
                        padding: 2
                        width: parent.width
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                listenerTabId.autoScrollEnabled = false
                            }
                        }
                    }
                }
                onMovementStarted: {
                    listenerTabId.autoScrollEnabled = false
                }
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }

            Button {
                text: "Auto Scroll"
                visible: !listenerTabId.autoScrollEnabled
                onClicked: {
                    listenerTabId.autoScrollEnabled = true
                    listView.positionViewAtEnd()
                }
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
            }
        }
    }

    FileDialog {
        id: importListenerPresetDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: FileDialog.OpenFiles
        title: "Import Listener Presets"
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            for (var i = 0; i < selectedFiles.length; i++) {
                var selectedFile = selectedFiles[i];
                console.debug("Selected file: " + selectedFile)
                var localPath = qmlUtils.toLocalFile(selectedFile);
                datamodelRepoModel.setQosSelectionFromFile(localPath, 3);
            }
        }
    }

    FileDialog {
        id: exportListenerPresetDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        title: "Export Listener Preset"
        nameFilters: ["JSON files (*.json)"]
        selectedFile: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] + "/listener.json"
        property bool exportAll: false
        onAccepted: {
            qmlUtils.createFileFromQUrl(selectedFile)
            var localPath = qmlUtils.toLocalFile(selectedFile);
            datamodelRepoModel.exportListenerPresets(localPath);
        }
    }

    FileDialog {
        id: exportSampleLogFileDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] + "/samples.log"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "log"
        title: "Export Sample Log"
        onAccepted: {
            qmlUtils.createFileFromQUrl(selectedFile)
            var localPath = qmlUtils.toLocalFile(selectedFile);
            var content = ""
            var count = receivedDataModel.count
            for (var i = 0; i < count; i++) {
                content += receivedDataModel.get(i).text + "\n"
            }
            qmlUtils.saveFileContent(localPath, content)
        }
    }
}
