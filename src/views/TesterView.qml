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
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent
    property var component
    property var dataTreeModel: null
    property var sequenceModel: null
    property bool isSequenceEditorVisible: false
    property int testerRev: 0

    Connections {
        target: testerModel
        function onDataChanged() { testerRev++ }
        function onModelReset()  { testerRev++ }
        function onRowsInserted(){ testerRev++ }
        function onRowsRemoved() { testerRev++ }
        function onCountChanged() { testerRev++ }
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
                text: "Create Sequence"
                onClicked: {
                    testerModel.addSequence()
                    librariesCombobox.currentIndex = librariesCombobox.count - 1
                }
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
                            testerModel.deleteWriter(librariesCombobox.currentIndex)
                            librariesCombobox.currentIndex = librariesCombobox.currentIndex - 1
                        }
                    }
                    MenuItem {
                        text: "Delete All"
                        onClicked: {
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
                        sequenceModel = testerModel.getSequenceModel(currentIndex)
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
            visible: testerModel.count > 0

            Item {
                implicitHeight: 1
                implicitWidth: 1
            }

            Label {
                text: "Name:"
            }

            TextField {
                id: presetNameField
                text: testerModel.count > 0 ? testerModel.getPresetName(librariesCombobox.currentIndex) : ""
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
                    testerModel.printTree()
                }
            } */
            Item {
                implicitHeight: 1
                implicitWidth: 1
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 10
            visible: testerModel.count > 0

            Label {
                text: testerModel.getDescriptionName(librariesCombobox.currentIndex)
                leftPadding: 10
                topPadding: 5
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
            }

            Button {
                text: (testerRev, testerModel.getIsStarted(librariesCombobox.currentIndex)) ? "Stop" : "Start"
                onClicked: {
                    if (testerModel.getIsStarted(librariesCombobox.currentIndex)) {
                        testerModel.stopItem(librariesCombobox.currentIndex)
                    } else {
                        testerModel.startItem(librariesCombobox.currentIndex)
                    }
                }
            }
        }

        Item {
            visible: testerModel.count > 0
            implicitHeight: 10
            implicitWidth: 1
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 10

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: rootWindow.isDarkMode ? Constants.darkSeparator : Constants.lightSeparator
            }
        }

       Rectangle {
            id: contentRec
            color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 3

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                visible: dataTreeModel === null && sequenceModel !== null

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Button {
                        text: isSequenceEditorVisible ? "Stop Modify Sequence" : "Modify Sequence"
                        onClicked: {
                            isSequenceEditorVisible = !isSequenceEditorVisible
                        }
                    }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    id: sequenceEditor
                    property int availableIndex: -1
                    property int sequenceIndex: -1

                    GroupBox {
                        title: "Available"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: isSequenceEditorVisible

                        ListView {
                            id: availableList
                            anchors.fill: parent
                            clip: true
                            model: testerModel
                            currentIndex: sequenceEditor.availableIndex
                            onCurrentIndexChanged: sequenceEditor.availableIndex = currentIndex

                            delegate: ItemDelegate {
                                enabled: model.isWriter
                                width: ListView.view.width
                                text: model.name
                                highlighted: index === availableList.currentIndex
                                onClicked: availableList.currentIndex = index
                            }

                            ScrollBar.vertical: ScrollBar { }
                        }
                    }

                    ColumnLayout {
                        visible: isSequenceEditorVisible
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8

                        Button {
                            text: "Add →"
                            enabled: availableList.currentIndex >= 0
                            onClicked: {
                                if (testerModel && sequenceModel) {
                                    sequenceModel.addSequenceItem(testerModel.getItemId(availableList.currentIndex))
                                    testerRev++
                                }
                            }
                        }

                        Button {
                            text: "← Remove"
                            enabled: sequenceList.currentIndex >= 0
                            onClicked: {
                                if (sequenceModel) {
                                    sequenceModel.removeSequenceItem(sequenceList.currentIndex)
                                    testerRev++
                                }
                            }
                        }
                    }

                    // RIGHT: Sequence
                    GroupBox {
                        title: "Sequence"
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: sequenceList
                            anchors.fill: parent
                            clip: true
                            model: sequenceModel
                            currentIndex: sequenceEditor.sequenceIndex

                            delegate: ItemDelegate {
                                width: ListView.view.width
                                text: testerModel.getNameById(name)
                                highlighted: index === sequenceList.currentIndex
                                onClicked: sequenceList.currentIndex = index
                            }

                            ScrollBar.vertical: ScrollBar { }
                        }
                    }
                }
                }
            }

            TreeView {
                id: treeView
                model: dataTreeModel
                anchors.fill: parent
                visible: dataTreeModel !== null && sequenceModel === null
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
                        radius: 5
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
                        currentIndex: dataTreeModel !== null ? dataTreeModel.getEnumValue(treeView.index(row, column)) : -1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label.right
                        anchors.leftMargin: 5
                        implicitContentWidthPolicy: ComboBox.WidestText
                        onActivated: function(index) {
                            var modelIndex = treeView.index(row, column)
                            if (dataTreeModel && dataTreeModel.getIsEnum(modelIndex)) {
                                dataTreeModel.setData(modelIndex, index)
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: rootWindow.isDarkMode ? Constants.darkSeparator : Constants.lightSeparator
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            visible: testerModel.count > 0
            enabled: (testerRev, testerModel.getIsStarted(librariesCombobox.currentIndex))

            Button {
                text: "Write"
                visible: testerModel.count > 0
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
                visible: testerModel.count > 0
                onClicked: {
                    console.log("Dispose Button clicked")
                    testerModel.disposeData(librariesCombobox.currentIndex)
                }
            }
            Button {
                text: "Unregister"
                visible: testerModel.count > 0
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
                testerModel.importJson(localPath);
            }
        }
    }
}
