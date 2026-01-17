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
    property var component
    property var dataTreeModel: null

    Connections {
        target: testerModel
        function onShowQml(id, qmlCode) {
            if (component) {
                component.destroy()
            }
            component = Qt.createQmlObject(qmlCode, contentRec);
            component.mId = id
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {

            Label {
                text: "Tester"
                leftPadding: 10
                font.bold: true
            }

            Item {
                implicitHeight: 1
                Layout.fillWidth: true
            }

            Button {
                text: "Import"
                onClicked: importPresetDialog.open()
            }

            Button {
                id: exportButton
                text: "Export"
                onClicked: exportMenu.open()
                enabled: librariesCombobox.count > 0

                Menu {
                    id: exportMenu

                    MenuItem {
                        text: "Export Current"
                        onClicked: {
                            exportPresetDialog.exportAll = false;
                            exportPresetDialog.open()
                        }
                    }
                    MenuItem {
                        text: "Export All"
                        onClicked: {
                            exportPresetDialog.exportAll = true;
                            exportPresetDialog.open()
                        }
                    }
                }
            }

            Button {
                text: "Delete"
                onClicked: deleteMenu.open()
                enabled: librariesCombobox.count > 0

                Menu {
                    id: deleteMenu

                    MenuItem {
                        text: "Delete Current"
                        onClicked: {
                            if (component) {
                                component.destroy()
                            }
                            testerModel.deleteWriter(librariesCombobox.currentIndex)
                        }
                    }
                    MenuItem {
                        text: "Delete All"
                        onClicked: {
                            if (component) {
                                component.destroy()
                            }
                            testerModel.deleteAllWriters()
                        }
                    }
                }

            }
        }

        RowLayout {
            Layout.minimumHeight: 40
            Layout.maximumHeight: 40
            spacing: 10

            Item {
                implicitHeight: 1
                implicitWidth: 1
            }

            Label {
                text: "Selected:"
            }

            ComboBox {
                id: librariesCombobox
                model: testerModel
                Layout.fillWidth: true
                textRole: "name"
                onCurrentIndexChanged: {
                    if (testerModel) {
                        dataTreeModel = testerModel.getTreeModel(currentIndex)
                    }
                }
                onCountChanged: {
                    if (librariesCombobox.count > 0 && librariesCombobox.currentIndex === -1) {
                        librariesCombobox.currentIndex = 0;
                    }
                }
            }

            Item {
                implicitHeight: 1
                implicitWidth: 1
            }
        }

        RowLayout {
            spacing: 10
            visible: dataTreeModel !== null

            Item {
                implicitHeight: 1
                implicitWidth: 1
            }

            Label {
                text: "Name:"
            }

            TextField {
                id: presetNameField
                text: dataTreeModel !== null ? testerModel.getPresetName(librariesCombobox.currentIndex) : ""
                placeholderText: "Enter Preset-Name"
                Layout.fillWidth: true
                onTextChanged: {
                    if (testerModel) {
                        testerModel.setPresetName(librariesCombobox.currentIndex, presetNameField.text)
                    }
                }
            }
            /* Button {
                text: "Print tree"
                onClicked: {
                    dataTreeModel.printTree()
                }
            } */
            Item {
                implicitHeight: 1
                implicitWidth: 1
            }
        }

        Item {
            visible: dataTreeModel !== null
            implicitHeight: 10
            implicitWidth: 1
        }

       Rectangle {
            id: contentRec
            color: rootWindow.isDarkMode ? "black" : "white"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 3

            TreeView {
                id: treeView
                model: dataTreeModel
                anchors.fill: parent
                clip: true
                ScrollBar.vertical: ScrollBar {}
                selectionModel: ItemSelectionModel {
                    id: treeSelectionParticipant
                    onCurrentIndexChanged: {
                        // console.log("Selection changed to:", currentIndex)
                    }
                }
                delegate: Item {
                    implicitWidth: contentRec.width
                    implicitHeight: label.implicitHeight * 1.5

                    readonly property real indentation: 20
                    readonly property real padding: 5

                    // Assigned to by TreeView:
                    required property TreeView treeView
                    required property bool isTreeNode
                    required property bool expanded
                    required property int hasChildren
                    required property int depth
                    required property int row
                    required property int column
                    required property bool current

                    property Animation indicatorAnimation: NumberAnimation {
                        target: indicator
                        property: "rotation"
                        from: expanded ? 0 : 90
                        to: expanded ? 90 : 0
                        duration: 100
                        easing.type: Easing.OutQuart
                    }
                    TableView.onPooled: indicatorAnimation.complete()
                    TableView.onReused: if (current) indicatorAnimation.start()
                    onExpandedChanged: {
                        indicator.rotation = expanded ? 90 : 0
                    }

                    Rectangle {
                        id: background
                        anchors.fill: parent
                        visible: row === treeView.currentRow
                        color: rootWindow.isDarkMode ? Constants.darkSelectionBackground : Constants.lightSelectionBackground
                        opacity: 0.3
                    }

                    Label {
                        id: indicator
                        x: padding + (depth * indentation)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: isTreeNode && hasChildren
                        text: "▶"

                        TapHandler {
                            onSingleTapped: {
                                let index = treeView.index(row, column)
                                treeView.selectionModel.setCurrentIndex(index, ItemSelectionModel.NoUpdate)
                                treeView.toggleExpanded(row)
                            }
                        }
                    }
                    Label {
                        id: label
                        x: padding + (isTreeNode ? (depth + 1) * indentation : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        width: implicitWidth
                        clip: true
                        text: model.display + display_hint
                    }
                    TextField {
                        id: inputFieldStr
                        visible: model.is_str
                        enabled: model.is_str
                        text: dataTreeModel !== null ? dataTreeModel.getStrValue(treeView.index(row, column)) : ""
                        placeholderText: "Enter text"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label.right
                        anchors.leftMargin: 5
                        readOnly: false
                        onTextChanged: {
                            if (dataTreeModel) {
                                if (model.is_str) {
                                    dataTreeModel.setData(treeView.index(row, column), inputFieldStr.text)
                                }
                            }
                        }
                    }
                    TextField {
                        id: inputFieldInt
                        visible: model.is_int
                        enabled: model.is_int
                        text: model.value !== undefined ? model.value : "0"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label.right
                        anchors.leftMargin: 5
                        readOnly: false
                        validator: RegularExpressionValidator {
                            regularExpression: /^[+-]?\d+$/
                        }
                        onTextChanged: {

                            if (dataTreeModel) {
                                if (model.is_int) {
                                    dataTreeModel.setData(treeView.index(row, column), parseInt(inputFieldInt.text))
                                }
                            }
                        }
                    }
                    TextField {
                        id: inputFieldFloat
                        visible: model.is_float
                        enabled: model.is_float
                        text: model.value !== undefined ? model.value : "0.0"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label.right
                        anchors.leftMargin: 5
                        readOnly: false
                        validator: RegularExpressionValidator {
                            regularExpression: /^[+-]?(\d+(\.\d*)?|\.\d+)$/
                        }
                        onTextChanged: {
                            if (dataTreeModel) {
                                if (model.is_float) {
                                    dataTreeModel.setData(treeView.index(row, column), parseFloat(inputFieldFloat.text))
                                }
                            }
                        }
                    }
                    Switch {
                        id: toggleSwitch
                        visible: model.is_bool
                        enabled: model.is_bool
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label.right
                        anchors.leftMargin: 5
                        checked: model.value !== undefined ? (model.value === "true" || model.value === "True") : false
                        onCheckedChanged: {
                            if (dataTreeModel) {
                                if (model.is_bool) {
                                    dataTreeModel.setData(treeView.index(row, column), toggleSwitch.checked)
                                }
                            }
                        }
                    }

                    ComboBox {
                        id: enumCombo
                        visible: dataTreeModel !== null ? dataTreeModel.getIsEnum(treeView.index(row, column)) : false
                        enabled: dataTreeModel !== null ? dataTreeModel.getIsEnum(treeView.index(row, column)) : false
                        model: dataTreeModel !== null ? dataTreeModel.getEnumModel(treeView.index(row, column)) : []
                        currentIndex: dataTreeModel !== null ? dataTreeModel.getEnumValue(treeView.index(row, column)) : 0
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label.right
                        anchors.leftMargin: 5
                        onCurrentIndexChanged: {
                            if (dataTreeModel) {
                                if (dataTreeModel.getIsEnum(treeView.index(row, column))) {
                                    dataTreeModel.setData(treeView.index(row, column), enumCombo.currentIndex)
                                }
                            }
                        }
                    }

                    Button {
                        id: plusButtonId
                        visible: model.is_expandable
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label.right
                        anchors.leftMargin: 5
                        text: "+"
                        onClicked: {
                            testerModel.addArrayItem(librariesCombobox.currentIndex, treeView.index(row, column))
                        }
                    }
                    Button {
                        visible: model.is_sequence_element || model.is_optional_element
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: model.is_expandable ? plusButtonId.right : label.right
                        anchors.leftMargin: 5
                        text: "-"
                        onClicked: {
                            testerModel.removeArrayItem(librariesCombobox.currentIndex, treeView.index(row, column))
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            visible: dataTreeModel !== null

            Button {
                text: "Write"
                visible: dataTreeModel !== null
                onClicked: {
                    console.log("Write Button clicked")
                    testerModel.writeData(librariesCombobox.currentIndex)
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                text: "Dispose"
                visible: dataTreeModel !== null
                onClicked: {
                    console.log("Dispose Button clicked")
                    testerModel.disposeData(librariesCombobox.currentIndex)
                }
            }
            Button {
                text: "Unregister"
                visible: dataTreeModel !== null
                onClicked: {
                    console.log("Unregister Button clicked")
                    testerModel.unregisterData(librariesCombobox.currentIndex)
                }
            }
        }
    }

    FileDialog {
        id: exportPresetDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        title: "Export Tester Preset"
        nameFilters: ["JSON files (*.json)"]
        selectedFile: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] + "/" + (presetNameField.text !== "" ? presetNameField.text : "preset") + ".json"
        property bool exportAll: false
        onAccepted: {
            qmlUtils.createFileFromQUrl(selectedFile)
            var localPath = qmlUtils.toLocalFile(selectedFile);
            if (exportPresetDialog.exportAll) {
                testerModel.exportJsonAll(localPath);
            } else {
                testerModel.exportJson(localPath, librariesCombobox.currentIndex);
            }
        }
    }

    FileDialog {
        id: importPresetDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: FileDialog.OpenFiles
        title: "Import Tester Presets"
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            for (var i = 0; i < selectedFiles.length; i++) {
                var selectedFile = selectedFiles[i];
                console.debug("Selected file: " + selectedFile)
                var localPath = qmlUtils.toLocalFile(selectedFile);
                datamodelRepoModel.setQosSelectionFromFile(localPath, 4);
            }
        }
    }
}
