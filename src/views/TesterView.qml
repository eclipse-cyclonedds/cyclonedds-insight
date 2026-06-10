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
import "qrc:/src/views/icons"


Rectangle {
    id: listenerTabId
    anchors.fill: parent
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent
    property var component
    property var dataTreeModel: null
    property var sequenceModel: null
    property bool isSequenceEditorVisible: false
    property bool isDescriptionExpanded: false
    property int currentDataIndex: 0
    property int testerRev: 0

    function refreshCurrentModels() {
        if (!testerModel || librariesCombobox.currentIndex < 0) {
            dataTreeModel = null
            sequenceModel = null
            currentDataIndex = 0
            return
        }

        const dataItemCount = testerModel.getDataItemCount(librariesCombobox.currentIndex)
        currentDataIndex = dataItemCount > 0
                ? Math.min(currentDataIndex, dataItemCount - 1)
                : 0
        dataTreeModel = testerModel.getTreeModel(librariesCombobox.currentIndex, currentDataIndex)
        sequenceModel = testerModel.getSequenceModel(librariesCombobox.currentIndex)
    }

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
                text:  qsTrId("tester.duplicate")
                enabled: librariesCombobox.count > 0
                onClicked: {
                    testerModel.duplicatePreset(librariesCombobox.currentIndex)
                    librariesCombobox.currentIndex = librariesCombobox.count - 1
                }
            }

            Button {
                text: qsTrId("tester.create-sequence")
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
                            const idx = librariesCombobox.currentIndex
                            testerModel.deleteWriter(idx)
                            if (librariesCombobox.count > 0) {
                                librariesCombobox.currentIndex = Math.max(0, idx - 1)
                            } else {
                                librariesCombobox.currentIndex = -1
                            }
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
                readonly property bool isMac: Qt.platform.os === "osx"
                readonly property int popupOverlap: isMac ? 8 : 0
                readonly property int popupInset: isMac ? 8 : 0
                model: testerModel
                Layout.fillWidth: true
                textRole: "name"
                enabled: librariesCombobox.count > 0

                property string searchText: ""

                popup: Popup {
                    y: librariesCombobox.height  - librariesCombobox.popupOverlap
                    x: librariesCombobox.popupInset
                    width: librariesCombobox.width - (2 * librariesCombobox.popupInset)
                    height: listenerTabId.height * 0.6
                    padding: 4
                    clip: true

                    contentItem: ColumnLayout {
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: qsTrId("general.search.placeholder")
                            text: librariesCombobox.searchText

                            onAccepted: librariesCombobox.searchText = text

                            Keys.onEscapePressed: librariesCombobox.popup.close()
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: testerModel
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: ItemDelegate {
                                width: ListView.view.width
                                text: model.name
                                visible: text.toLowerCase().includes(
                                    librariesCombobox.searchText.toLowerCase()
                                )
                                height: visible ? implicitHeight : 0

                                onClicked: {
                                    librariesCombobox.currentIndex = index
                                    librariesCombobox.popup.close()
                                }
                            }
                        }
                    }

                    onOpened: {
                        searchField.forceActiveFocus()
                        searchField.selectAll()
                    }

                    onClosed: {
                        librariesCombobox.searchText = ""
                    }
                }

                onCurrentIndexChanged: {
                    if (testerModel && currentIndex >= 0) {
                        currentDataIndex = 0
                        refreshCurrentModels()
                        descriptionField.text = testerModel.getDescription(currentIndex)
                    }
                }

                onCountChanged: {
                    if (count > 0 && currentIndex === -1)
                        currentIndex = 0
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

        ColumnLayout {
            Layout.fillWidth: true
            visible: testerModel.count > 0
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Label {
                    Layout.leftMargin: 10
                    Layout.fillWidth: true
                    text: testerModel.getDescriptionName(librariesCombobox.currentIndex)
                    wrapMode: Text.Wrap
                }

                Button {
                    Layout.rightMargin: 1
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

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 8

                Label {
                    text: qsTrId("tester.description")
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 26

                    Label {
                        id: descriptionPreview
                        anchors.left: parent.left
                        anchors.right: descriptionExpandIndicator.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const description = (testerRev, testerModel.getDescription(librariesCombobox.currentIndex))
                            return description.length > 0 ? description : qsTrId("tester.description.placeholder")
                        }
                        opacity: (testerRev, testerModel.getDescription(librariesCombobox.currentIndex).length > 0) ? 1 : 0.55
                        font.italic: (testerRev, testerModel.getDescription(librariesCombobox.currentIndex).length === 0)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    ChevronIcon {
                        id: descriptionExpandIndicator
                        width: 16
                        height: 16
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        iconColor: rootWindow.isDarkMode ? "#b0b0b0" : "#606060"
                        rotation: isDescriptionExpanded ? 180 : 0
                        opacity: 0.7

                        Behavior on rotation {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: rootWindow.isDarkMode ? Constants.darkSeparator : Constants.lightSeparator
                        opacity: descriptionMouseArea.containsMouse ? 1 : 0.6
                    }

                    MouseArea {
                        id: descriptionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            isDescriptionExpanded = !isDescriptionExpanded
                            if (isDescriptionExpanded) {
                                descriptionField.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            ScrollView {
                id: descriptionScrollView
                visible: isDescriptionExpanded
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.preferredHeight: 80
                Layout.minimumHeight: 80
                Layout.maximumHeight: 120
                clip: true

                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    id: descriptionField
                    placeholderText: qsTrId("tester.description.placeholder")
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    persistentSelection: true

                    onTextChanged: {
                        if (visible && testerModel && librariesCombobox.currentIndex >= 0) {
                            testerModel.setDescription(librariesCombobox.currentIndex, text)
                        }
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

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 3
            Layout.rightMargin: 3
            visible: dataTreeModel !== null && sequenceModel === null
            spacing: 3

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 29
                color: "transparent"

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: rootWindow.isDarkMode ? Constants.darkSeparator : Constants.lightSeparator
                }

                ListView {
                    id: dataItemTabList
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 2
                    clip: true
                    model: (testerRev, testerModel.getDataItemCount(librariesCombobox.currentIndex))
                    currentIndex: currentDataIndex

                    delegate: Rectangle {
                        id: dataItemTab
                        required property int index
                        property bool selected: index === currentDataIndex
                        width: Math.max(76, tabNameLabel.implicitWidth + 24)
                        height: selected ? 29 : 26
                        y: selected ? 0 : 3
                        radius: 5
                        color: selected
                               ? (rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent)
                               : (rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor)
                        border.width: 1
                        border.color: rootWindow.isDarkMode ? Constants.darkSeparator : Constants.lightSeparator
                        opacity: selected || dataItemTabMouseArea.containsMouse ? 1 : 0.75

                        Rectangle {
                            visible: selected
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 1
                            anchors.rightMargin: 1
                            height: 2
                            color: parent.color
                        }

                        Label {
                            id: tabNameLabel
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !tabNameEditor.visible
                            text: (testerRev, testerModel.getDataItemName(librariesCombobox.currentIndex, index))
                            font.bold: selected
                        }

                        TextField {
                            id: tabNameEditor
                            anchors.fill: parent
                            visible: false
                            text: tabNameLabel.text
                            selectByMouse: true
                            leftPadding: 6
                            rightPadding: 6

                            function finishEditing() {
                                testerModel.setDataItemName(librariesCombobox.currentIndex, index, text)
                                visible = false
                                testerRev++
                            }

                            onAccepted: finishEditing()
                            onActiveFocusChanged: {
                                if (!activeFocus && visible) {
                                    finishEditing()
                                }
                            }
                            Keys.onEscapePressed: {
                                text = tabNameLabel.text
                                visible = false
                            }
                        }

                        MouseArea {
                            id: dataItemTabMouseArea
                            anchors.fill: parent
                            enabled: !tabNameEditor.visible
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                currentDataIndex = index
                                refreshCurrentModels()
                            }
                            onDoubleClicked: {
                                currentDataIndex = index
                                tabNameEditor.text = tabNameLabel.text
                                tabNameEditor.visible = true
                                tabNameEditor.forceActiveFocus()
                                tabNameEditor.selectAll()
                            }
                        }

                        ToolTip {
                            id: dataItemTabTooltip
                            parent: dataItemTab
                            visible: dataItemTabMouseArea.containsMouse && !tabNameEditor.visible
                            delay: 500
                            text: "Double-click to rename"
                            contentItem: Label {
                                text: dataItemTabTooltip.text
                            }
                            background: Rectangle {
                                border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
                                border.width: 1
                                color: rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor
                            }
                        }
                    }
                }
            }

            ToolButton {
                id: addDataItemButton
                implicitWidth: 26
                implicitHeight: 26
                onClicked: {
                    const newIndex = testerModel.addDataItem(librariesCombobox.currentIndex)
                    if (newIndex >= 0) {
                        currentDataIndex = newIndex
                        testerRev++
                        refreshCurrentModels()
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    z: 1

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 2
                        radius: 1
                        color: rootWindow.isDarkMode ? "#d0d0d0" : "#505050"
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 2
                        height: parent.height
                        radius: 1
                        color: rootWindow.isDarkMode ? "#d0d0d0" : "#505050"
                    }
                }
            }

            ToolButton {
                implicitWidth: 26
                implicitHeight: 26
                enabled: (testerRev, testerModel.getDataItemCount(librariesCombobox.currentIndex) > 1)
                onClicked: {
                    currentDataIndex = testerModel.removeDataItem(
                                librariesCombobox.currentIndex, currentDataIndex)
                    testerRev++
                    refreshCurrentModels()
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 2
                    radius: 1
                    z: 1
                    color: parent.enabled
                           ? (rootWindow.isDarkMode ? "#d0d0d0" : "#505050")
                           : (rootWindow.isDarkMode ? "#606060" : "#a0a0a0")
                }
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
                            model: (testerRev, testerModel.getAvailableDataItemCount())
                            currentIndex: sequenceEditor.availableIndex
                            onCurrentIndexChanged: sequenceEditor.availableIndex = currentIndex

                            delegate: ItemDelegate {
                                required property int index
                                width: ListView.view.width
                                text: (testerRev, testerModel.getAvailableDataItemName(index))
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
                            id: addSequenceItemButton
                            enabled: availableList.currentIndex >= 0
                            implicitWidth: addSequenceItemContent.implicitWidth + leftPadding + rightPadding

                            Row {
                                id: addSequenceItemContent
                                anchors.centerIn: parent
                                z: 1
                                spacing: 5

                                Label {
                                    text: "Add"
                                    color: addSequenceItemButton.enabled ? addSequenceItemButton.palette.buttonText : addSequenceItemButton.palette.mid
                                }

                                ArrowIcon {
                                    width: 18
                                    height: 18
                                    y: (parent.height - height) / 2
                                    iconColor: addSequenceItemButton.enabled ? addSequenceItemButton.palette.buttonText : addSequenceItemButton.palette.mid
                                }
                            }
                            onClicked: {
                                if (testerModel && sequenceModel) {
                                    sequenceModel.addSequenceItem(
                                                testerModel.getAvailableDataItemId(availableList.currentIndex))
                                    testerRev++
                                }
                            }
                        }

                        Button {
                            id: removeSequenceItemButton
                            enabled: sequenceList.currentIndex >= 0
                            implicitWidth: removeSequenceItemContent.implicitWidth + leftPadding + rightPadding

                            Row {
                                id: removeSequenceItemContent
                                anchors.centerIn: parent
                                z: 1
                                spacing: 5

                                ArrowIcon {
                                    width: 18
                                    height: 18
                                    y: (parent.height - height) / 2
                                    direction: "left"
                                    iconColor: removeSequenceItemButton.enabled ? removeSequenceItemButton.palette.buttonText : removeSequenceItemButton.palette.mid
                                }

                                Label {
                                    text: "Remove"
                                    color: removeSequenceItemButton.enabled ? removeSequenceItemButton.palette.buttonText : removeSequenceItemButton.palette.mid
                                }
                            }
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
                                required property int index
                                required property string dataItemId
                                width: ListView.view.width
                                text: (testerRev, testerModel.getDataItemDisplayName(dataItemId))
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
                visible: dataTreeModel !== null && sequenceModel === null && librariesCombobox.count > 0
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

                    Rectangle {
                        id: background
                        anchors.fill: parent
                        visible: row === treeView.currentRow
                        color: rootWindow.isDarkMode ? Constants.darkSelectionBackground : Constants.lightSelectionBackground
                        opacity: 0.3
                        radius: 5
                    }

                    ChevronIcon {
                        id: indicator
                        width: 14
                        height: 14
                        x: padding + (depth * indentation)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: isTreeNode && hasChildren
                        iconColor: rootWindow.isDarkMode ? "#d0d0d0" : "#505050"
                        direction: expanded ? "down" : "right"

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
                            testerModel.addArrayItem(librariesCombobox.currentIndex,
                                                     currentDataIndex,
                                                     treeView.index(row, column))
                        }
                    }
                    Button {
                        visible: model.is_sequence_element || model.is_optional_element
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: model.is_expandable ? plusButtonId.right : label.right
                        anchors.leftMargin: 5
                        text: "-"
                        onClicked: {
                            testerModel.removeArrayItem(librariesCombobox.currentIndex,
                                                        currentDataIndex,
                                                        treeView.index(row, column))
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
                    testerModel.writeData(librariesCombobox.currentIndex, currentDataIndex)
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
                    testerModel.disposeData(librariesCombobox.currentIndex, currentDataIndex)
                }
            }
            Button {
                text: "Unregister"
                visible: testerModel.count > 0
                onClicked: {
                    console.log("Unregister Button clicked")
                    testerModel.unregisterData(librariesCombobox.currentIndex, currentDataIndex)
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
