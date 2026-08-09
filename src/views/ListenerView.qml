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
import "qrc:/src/views/selection_details"
import "qrc:/src/views/elements"

Rectangle {
    id: listenerTabId
    anchors.fill: parent
    color: Constants.mainContentColor(rootWindow.isDarkMode)
    property bool started: true
    property bool autoScrollEnabled: true
    property bool manageReadersVisible: false
    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    readonly property color borderColor: Constants.designBorderColor(rootWindow.isDarkMode)

    Connections {
        target: receiverProxyModel
        function onRowsInserted(parent, first, last) {
            // auto scroll
            if (listenerTabId.autoScrollEnabled) {
                Qt.callLater(function () {
                    listView.positionViewAtEnd();
                });
            }
            if (!listenerTabId.started) {
                listenerTabId.started = true;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 9

            DetailBadge {
                kind: "listener"
            }

            Label {
                text: qsTrId("tab.listener")
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
                color: listenerTabId.started ? Constants.successColor : Constants.errorColor
            }

            Label {
                text: listenerTabId.started ? qsTrId("statistic.status.running") : qsTrId("statistic.status.stopped")
                font.bold: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.preferredHeight: 36
            spacing: 8

            Button {
                text: qsTrId("general.clear")
                onClicked: receiverModel.clear()
            }

            Item {
                implicitHeight: 1
                Layout.fillWidth: true
            }

            Button {
                id: comboButton
                text: qsTrId("listener.manage.readers")
                checkable: true
                checked: listenerTabId.manageReadersVisible
                onClicked: {
                    listenerTabId.manageReadersVisible = checked;
                    if (!checked) {
                        listenerProxyModel.searchText = "";
                    }
                }
            }

            Button {
                id: importButton
                text: qsTrId("general.import")
                onClicked: importMenu.open()
                Menu {
                    id: importMenu
                    x: importButton.width - width
                    y: importButton.height + 4

                    MenuItem {
                        text: qsTrId("listener.preset.import")
                        onClicked: importListenerPresetDialog.open()
                    }
                }
            }
            Button {
                id: exportButton
                text: qsTrId("general.export")
                onClicked: exportMenu.open()

                Menu {
                    id: exportMenu
                    x: exportButton.width - width
                    y: exportButton.height + 4

                    MenuItem {
                        text: qsTrId("listener.preset.export")
                        onClicked: exportListenerPresetDialog.open()
                    }
                    MenuItem {
                        text: qsTrId("listener.sample.export")
                        onClicked: exportSampleLogFileDialog.open()
                    }
                }
            }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal
            handle: Rectangle {
                implicitWidth: 10
                color: listenerTabId.color
            }

            Rectangle {
                color: listenerTabId.surfaceColor
                radius: Constants.cardRadius
                border.width: 1
                border.color: listenerTabId.borderColor
                SplitView.fillWidth: true
                SplitView.minimumWidth: 200

                ListView {
                    id: listView
                    anchors.fill: parent
                    model: receiverProxyModel
                    anchors.margins: 10
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
                            color: Constants.separatorColor(rootWindow.isDarkMode)
                        }
                        Item {
                            height: index > 0 ? 4 : 0
                            width: parent.width
                        }

                        TextEdit {
                            text: model.receivedMsg
                            readOnly: true
                            color: rootWindow.isDarkMode ? "white" : "black"
                            wrapMode: Text.Wrap
                            selectByMouse: true
                            padding: 2
                            width: parent.width
                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    listenerTabId.autoScrollEnabled = false;
                                }
                            }
                        }
                    }
                    onMovementStarted: {
                        listenerTabId.autoScrollEnabled = false;
                    }
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }

                Button {
                    text: qsTrId("listener.auto.scroll")
                    visible: !listenerTabId.autoScrollEnabled
                    onClicked: {
                        listenerTabId.autoScrollEnabled = true;
                        listView.positionViewAtEnd();
                    }
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                }
            }

            Loader {
                id: manageReadersPanelLoader
                visible: listenerTabId.manageReadersVisible
                active: visible
                sourceComponent: manageReadersPanelComponent
                SplitView.preferredWidth: 480
                SplitView.minimumWidth: 320
                SplitView.maximumWidth: Math.max(320, listenerTabId.width - 200)
            }
        }
    }

    FileDialog {
        id: importListenerPresetDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: FileDialog.OpenFiles
        title: qsTrId("listener.presets.import")
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            for (var i = 0; i < selectedFiles.length; i++) {
                var selectedFile = selectedFiles[i];
                console.debug("Selected file: " + selectedFile);
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
        title: qsTrId("listener.preset.export")
        nameFilters: ["JSON files (*.json)"]
        selectedFile: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] + "/listener.json"
        property bool exportAll: false
        onAccepted: {
            qmlUtils.createFileFromQUrl(selectedFile);
            var localPath = qmlUtils.toLocalFile(selectedFile);
            datamodelRepoModel.exportListenerPresets(localPath);
        }
    }

    FileDialog {
        id: exportSampleLogFileDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] + "/samples.log"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "log"
        title: qsTrId("listener.sample.export")
        onAccepted: {
            qmlUtils.createFileFromQUrl(selectedFile);
            var localPath = qmlUtils.toLocalFile(selectedFile);
            receiverModel.exportToFile(localPath);
        }
    }

    Component {
        id: manageReadersPanelComponent

        Rectangle {
            radius: Constants.cardRadius
            border.width: 1
            border.color: listenerTabId.borderColor
            color: listenerTabId.surfaceColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        text: qsTrId("listener.manage.readers")
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    IconActionButton {
                        icon: "close"
                        tooltipText: qsTrId("listener.manage.close")
                        onClicked: {
                            listenerTabId.manageReadersVisible = false;
                            listenerProxyModel.searchText = "";
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: qsTrId("general.search.placeholder")
                        onAccepted: listenerProxyModel.searchText = text
                    }

                    IconActionButton {
                        icon: listenerModel.allChecked ? "deselect-all" : "select-all"
                        tooltipText: listenerModel.allChecked
                                     ? qsTrId("listener.readers.deselect.all")
                                     : qsTrId("listener.readers.select.all")
                        onClicked: {
                            if (listenerModel.allChecked) {
                                receiverProxyModel.showReaderIds(listenerModel.readerIds(), false);
                                listenerModel.setAllChecked(false);
                            } else {
                                listenerModel.setAllChecked(true);
                                receiverProxyModel.clearHiddenReaderIds();
                            }
                        }
                    }

                    IconActionButton {
                        icon: listenerTabId.started ? "stop-all" : "play-all"
                        tooltipText: listenerTabId.started
                                     ? qsTrId("listener.readers.stop.all")
                                     : qsTrId("listener.readers.start.all")
                        onClicked: {
                            listenerTabId.started = !listenerTabId.started;
                            if (listenerTabId.started) {
                                listenerModel.startAllReaders();
                            } else {
                                listenerModel.stopAllReaders();
                            }
                        }
                    }

                    IconActionButton {
                        icon: "delete-all"
                        tooltipText: qsTrId("listener.readers.delete.all")
                        destructive: true
                        onClicked: listenerModel.deleteAllReaders()
                    }
                }

                ListView {
                    id: listViewSelectReaders
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: listenerProxyModel

                    property var receiverProxy: receiverProxyModel

                    delegate: Item {
                        id: delegateRoot
                        width: listViewSelectReaders.width
                        height: 44

                        required property int index
                        required property var model

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            CheckBox {
                                checked: model.isChecked
                                onCheckedChanged: {
                                    var readerId = model.readerId;
                                    if (checked !== model.isChecked) {
                                        listenerModel.setChecked(readerId, checked);
                                        delegateRoot.ListView.view.receiverProxy.showReaderId(readerId, checked);
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Label {
                                    text: model.topicName
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Label {
                                    text: model.topicType
                                    color: "#666"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            IconActionButton {
                                icon: model.stoppedReader ? "play" : "stop"
                                tooltipText: model.stoppedReader
                                             ? qsTrId("listener.reader.start")
                                             : qsTrId("listener.reader.stop")
                                onClicked: {
                                    if (model.stoppedReader) {
                                        listenerModel.startReader(model.readerId);
                                    } else {
                                        listenerModel.stopReader(model.readerId);
                                    }
                                }
                            }

                            IconActionButton {
                                icon: "delete"
                                tooltipText: qsTrId("listener.reader.delete")
                                destructive: true
                                onClicked: {
                                    listenerModel.deleteReader(model.readerId);
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {}
                }
            }
        }
    }
}
