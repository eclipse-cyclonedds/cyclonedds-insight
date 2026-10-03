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
import QtQuick.Controls.Basic as Basic
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

    component DetailValue: TextEdit {
        readOnly: true
        selectByMouse: true
        wrapMode: Text.Wrap
        padding: 0
        color: Constants.secondaryTextColor(rootWindow.isDarkMode)
        Layout.fillWidth: true
        onActiveFocusChanged: {
            if (activeFocus) {
                listenerTabId.autoScrollEnabled = false;
            }
        }
    }

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
            spacing: 8

            Rectangle {
                id: viewModeSelector
                Layout.preferredWidth: Math.min(160, listenerTabId.width * 0.34)
                Layout.preferredHeight: 32
                radius: 5
                color: rootWindow.isDarkMode ? "#292929" : "#e9e9e9"
                border.width: 1
                border.color: rootWindow.isDarkMode ? "#484848" : "#d0d0d0"

                Row {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Repeater {
                        model: [qsTrId("listener.view.log.short"),
                                qsTrId("listener.view.instances.short")]

                        Basic.ToolButton {
                            id: modeOption
                            required property int index
                            required property string modelData
                            readonly property bool selected: receiverModel.instanceView === (index === 1)
                            width: (parent.width - parent.spacing) / 2
                            height: parent.height
                            padding: 4
                            hoverEnabled: true
                            Accessible.name: index === 0 ? qsTrId("listener.view.log")
                                                       : qsTrId("listener.view.instances")
                            Accessible.checkable: true
                            Accessible.checked: selected
                            onClicked: receiverModel.instanceView = index === 1

                            contentItem: Label {
                                text: modeOption.modelData
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                            }
                            background: Rectangle {
                                radius: 3
                                color: modeOption.selected
                                       ? (rootWindow.isDarkMode ? "#484848" : "#ffffff")
                                       : modeOption.hovered
                                         ? (rootWindow.isDarkMode ? "#363636" : Constants.lightDesignBorder)
                                         : "transparent"
                                border.width: modeOption.selected || modeOption.visualFocus ? 1 : 0
                                border.color: modeOption.visualFocus ? Constants.accentColor
                                              : rootWindow.isDarkMode ? "#747474" : "#c6c6c6"
                            }
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            TextField {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                placeholderText: qsTrId("general.search.placeholder")
                onAccepted: receiverProxyModel.searchText = text
            }

            ExpandButton {
                id: actionsButton
                text: qsTrId("listener.actions")
                onClicked: actionsMenu.open()

                Menu {
                    id: actionsMenu
                    x: actionsButton.width - width
                    y: actionsButton.height + 4
                    width: Math.min(implicitWidth, listenerTabId.width - 2 * Constants.pageMargin)

                    MenuItem {
                        text: qsTrId("listener.manage.readers")
                        checkable: true
                        checked: listenerTabId.manageReadersVisible
                        onTriggered: {
                            listenerTabId.manageReadersVisible = !listenerTabId.manageReadersVisible
                            if (!listenerTabId.manageReadersVisible)
                                listenerProxyModel.searchText = ""
                        }
                    }

                    MenuSeparator {}

                    MenuItem {
                        text: qsTrId("listener.preset.import")
                        onTriggered: importListenerPresetDialog.open()
                    }
                    MenuItem {
                        text: qsTrId("listener.preset.export")
                        onTriggered: exportListenerPresetDialog.open()
                    }
                    MenuItem {
                        text: qsTrId("listener.sample.export")
                        onTriggered: exportSampleLogFileDialog.open()
                    }

                    MenuSeparator {}

                    MenuItem {
                        text: qsTrId("general.clear")
                        onTriggered: receiverModel.clear()
                    }
                }
            }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal
            handle: ResizeHandle {}

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
                        id: sampleDelegate
                        width: ListView.view.width - listenerScrollBar.width
                        property bool sampleInfoVisible: false

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

                        RowLayout {
                            width: parent.width
                            spacing: 6

                            Item {
                                implicitHeight: receivedMessageText.implicitHeight
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop

                                property int timestampSpacing:
                                    Math.ceil((receivedTimestampText.contentWidth + 6)
                                              / Math.max(receivedTextSpace.advanceWidth, 1))

                                TextMetrics {
                                    id: receivedTextSpace
                                    font: receivedMessageText.font
                                    text: "\u00a0"
                                }

                                TextEdit {
                                    id: receivedMessageText
                                    width: parent.width
                                    text: "\u00a0".repeat(parent.timestampSpacing)
                                          + "•  " + model.receivedMsg
                                    readOnly: true
                                    color: rootWindow.isDarkMode ? "white" : "black"
                                    wrapMode: Text.Wrap
                                    selectByMouse: true
                                    padding: 2
                                    onActiveFocusChanged: {
                                        if (activeFocus) {
                                            listenerTabId.autoScrollEnabled = false;
                                        }
                                    }
                                }

                                TextEdit {
                                    id: receivedTimestampText
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    y: receivedMessageText.padding
                                       + Math.max(0, (receivedTextSpace.height - height) / 2)
                                    width: contentWidth
                                    height: contentHeight
                                    text: model.receivedTimestamp
                                    readOnly: true
                                    selectByMouse: true
                                    padding: 0
                                    color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                                    font.pixelSize: Constants.captionFontSize
                                    onActiveFocusChanged: {
                                        if (activeFocus) {
                                            listenerTabId.autoScrollEnabled = false;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: !model.validData
                                implicitWidth: invalidSampleLabel.implicitWidth + 12
                                implicitHeight: 24
                                radius: Constants.badgeRadius
                                color: Constants.errorColor
                                Layout.alignment: Qt.AlignTop

                                Label {
                                    id: invalidSampleLabel
                                    anchors.centerIn: parent
                                    text: qsTrId("listener.sample.invalid")
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: Constants.captionFontSize
                                }
                            }

                            IconActionButton {
                                icon: "info"
                                active: sampleDelegate.sampleInfoVisible
                                Layout.alignment: Qt.AlignTop
                                onClicked: sampleDelegate.sampleInfoVisible =
                                           !sampleDelegate.sampleInfoVisible
                            }

                        }

                        Rectangle {
                            visible: sampleDelegate.sampleInfoVisible
                            width: parent.width
                            height: sampleInfoLayout.implicitHeight + 12
                            radius: Constants.controlRadius
                            color: rootWindow.isDarkMode
                                   ? Constants.mainContentBackgroundColor(true)
                                   : "#eeeeee"
                            border.width: 1
                            border.color: listenerTabId.borderColor

                            ColumnLayout {
                                id: sampleInfoLayout
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: originLayout.implicitHeight + 12
                                    radius: Constants.controlRadius
                                    color: rootWindow.isDarkMode ? "#292929" : "#fafafa"

                                    ColumnLayout {
                                        id: originLayout
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 3

                                        Label {
                                            text: qsTrId("listener.sample.group.path")
                                            color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                                            font.bold: true
                                            font.pixelSize: Constants.captionFontSize
                                        }
                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 2
                                            columnSpacing: 12
                                            rowSpacing: 2

                                            Label { text: qsTrId("listener.sample.sent.from"); font.bold: true }
                                            DetailValue {
                                                text: model.writerApplication + ":"
                                                      + model.writerProcessId + "@"
                                                      + model.writerHostname
                                            }
                                            Label { text: qsTrId("listener.sample.writer.addresses"); font.bold: true }
                                            DetailValue {
                                                text: model.writerAddresses
                                            }
                                            Label { text: qsTrId("listener.sample.writer.id"); font.bold: true }
                                            DetailValue {
                                                text: model.writerId
                                            }
                                            Label { text: qsTrId("listener.sample.reader.id"); font.bold: true }
                                            DetailValue {
                                                text: model.ddsReaderId
                                            }
                                            Label { text: qsTrId("listener.sample.topic.name"); font.bold: true }
                                            DetailValue {
                                                text: model.topicName
                                            }
                                            Label { text: qsTrId("listener.sample.topic.type"); font.bold: true }
                                            DetailValue {
                                                text: model.topicType
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: timingLayout.implicitHeight + 12
                                    radius: Constants.controlRadius
                                    color: rootWindow.isDarkMode ? "#292929" : "#fafafa"

                                    ColumnLayout {
                                        id: timingLayout
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 3

                                        Label {
                                            text: qsTrId("listener.sample.group.timing")
                                            color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                                            font.bold: true
                                            font.pixelSize: Constants.captionFontSize
                                        }
                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 2
                                            columnSpacing: 12
                                            rowSpacing: 2

                                            Label { text: qsTrId("listener.sample.source.timestamp"); font.bold: true }
                                            DetailValue {
                                                text: model.sourceTimestamp
                                            }
                                            Label { text: qsTrId("listener.sample.received.timestamp"); font.bold: true }
                                            DetailValue {
                                                text: model.receivedTimestamp
                                            }
                                            Label { text: qsTrId("listener.sample.transmission.time"); font.bold: true }
                                            DetailValue {
                                                text: model.transmissionTime
                                            }
                                        }
                                        Label {
                                            text: qsTrId("listener.sample.transmission.hint")
                                            color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                                            font.pixelSize: Constants.captionFontSize
                                            font.italic: true
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: rawInfoLayout.implicitHeight + 12
                                    radius: Constants.controlRadius
                                    color: rootWindow.isDarkMode ? "#292929" : "#fafafa"

                                    ColumnLayout {
                                        id: rawInfoLayout
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 3

                                        Label {
                                            text: qsTrId("listener.sample.group.raw")
                                            color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                                            font.bold: true
                                            font.pixelSize: Constants.captionFontSize
                                        }
                                        DetailValue {
                                            text: model.sampleInfo
                                        }
                                    }
                                }
                            }
                        }
                    }
                    onMovementStarted: {
                        listenerTabId.autoScrollEnabled = false;
                    }
                    ScrollBar.vertical: ScrollBar {
                        id: listenerScrollBar
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
