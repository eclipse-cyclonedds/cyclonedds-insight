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
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"
import "qrc:/src/views/icons"
import "qrc:/src/views/selection_details"

Rectangle {
    id: configEditorView

    color: Constants.mainContentColor(rootWindow.isDarkMode)

    property string fileContent: ""
    property string lastSavedTime: ""
    property bool configFileAvailable: false
    property bool completionInsertionInProgress: false
    property int viewMode: 0
    readonly property bool editorVisible: viewMode !== 2
    readonly property bool documentationVisible: viewMode !== 0

    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    readonly property color borderColor: Constants.designBorderColor(rootWindow.isDarkMode)
    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)

    function updateCompletions() {
        if (completionInsertionInProgress || !configTextArea.activeFocus) {
            completionPopup.close()
            return
        }

        const suggestions = xmlCompletionModel.suggestions(
            configTextArea.text, configTextArea.cursorPosition)
        completionPopup.suggestions = suggestions
        completionPopup.currentIndex = 0
        if (suggestions.length > 0) {
            if (!completionPopup.opened)
                completionPopup.open()
        } else {
            completionPopup.close()
        }
    }

    function acceptCompletion() {
        if (!completionPopup.opened
                || completionPopup.suggestions.length === 0)
            return

        const completion = completionPopup.suggestions[
            completionPopup.currentIndex]
        completionInsertionInProgress = true
        configTextArea.remove(completion.replaceStart,
                              completion.replaceEnd)
        configTextArea.insert(completion.replaceStart,
                              completion.insertion)
        configTextArea.cursorPosition = completion.replaceStart
                                        + completion.cursorOffset
        completionInsertionInProgress = false
        completionPopup.close()
    }

    function showDocumentation(schemaPath) {
        if (!documentationVisible)
            viewMode = 1
        Qt.callLater(function() {
            const elementIndex = modelXsd.indexForPath(schemaPath)
            if (!elementIndex.valid)
                return

            treeView.expandToIndex(elementIndex)
            treeView.selectionModel.setCurrentIndex(
                elementIndex, ItemSelectionModel.ClearAndSelect)
            Qt.callLater(function() {
                treeView.positionViewAtIndex(elementIndex,
                                             TableView.AlignVCenter)
            })
        })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 14
            spacing: 9

            DetailBadge {
                kind: "configuration"
            }

            Label {
                text: qsTrId("general.configeditor")
                font.pixelSize: Constants.pageTitleFontSize
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                id: configurationViewSelector
                Layout.preferredWidth: Math.min(390,
                                                configEditorView.width * 0.45)
                Layout.preferredHeight: Qt.platform.os === "osx" ? 30 : 26
                radius: 5
                color: rootWindow.isDarkMode ? "#292929" : "#e9e9e9"
                border.width: 1
                border.color: rootWindow.isDarkMode ? "#484848" : "#d0d0d0"

                Row {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Repeater {
                        model: [
                            qsTrId("config.view.editor"),
                            qsTrId("config.view.side-by-side"),
                            qsTrId("config.view.documentation")
                        ]

                        Rectangle {
                            id: configurationViewOption
                            required property int index
                            required property string modelData
                            readonly property bool selected:
                                configEditorView.viewMode === index

                            width: (parent.width - 4) / 3
                            height: parent.height
                            radius: 3
                            color: selected
                                   ? rootWindow.isDarkMode
                                     ? "#484848" : "#ffffff"
                                   : configurationViewMouseArea.containsMouse
                                     ? rootWindow.isDarkMode
                                       ? "#363636"
                                       : Constants.lightDesignBorder
                                     : rootWindow.isDarkMode
                                       ? "#242424" : "transparent"
                            border.width: 1
                            border.color: selected
                                          ? rootWindow.isDarkMode
                                            ? "#747474" : "#c6c6c6"
                                          : "transparent"

                            Rectangle {
                                visible: configurationViewOption.selected
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 5
                                width: 2
                                height: parent.height - 8
                                radius: 1
                                color: Constants.accentColor
                            }

                            Label {
                                anchors.fill: parent
                                anchors.leftMargin: 11
                                anchors.rightMargin: 6
                                text: configurationViewOption.modelData
                                font.bold: configurationViewOption.selected
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                color: rootWindow.isDarkMode
                                       ? configurationViewOption.selected
                                         ? "#ffffff" : "#b8b8b8"
                                       : "#262626"
                            }

                            MouseArea {
                                id: configurationViewMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked:
                                    configEditorView.viewMode =
                                        configurationViewOption.index
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Constants.cardRadius
            color: configEditorView.surfaceColor
            border.width: 1
            border.color: configEditorView.borderColor
            clip: true
            z: 1

            SplitView {
                id: configEditorSplit
                anchors.fill: parent
                anchors.margins: 12
                orientation: Qt.Horizontal
                handle: Rectangle {
                    implicitWidth: 14
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: parent.height - 12
                        color: parent.SplitHandle.hovered
                               || parent.SplitHandle.pressed
                               ? Constants.accentColor
                               : configEditorView.borderColor
                    }
                }

                Item {
                    visible: configEditorView.editorVisible
                    SplitView.fillWidth: true
                    SplitView.minimumWidth: 480

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 2
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Label {
                                    text: "CYCLONEDDS_URI"
                                    color: configEditorView.secondaryTextColor
                                }

                                TextField {
                                    id: uriField
                                    Layout.fillWidth: true
                                    text: CYCLONEDDS_URI
                                    readOnly: true
                                    selectByMouse: true
                                }
                            }

                            Button {
                                visible: configEditorView.configFileAvailable
                                text: "Reload"
                                flat: true
                                onClicked: {
                                    configEditorView.fileContent =
                                            qmlUtils.loadFileContent(CYCLONEDDS_URI)
                                    configTextArea.text =
                                        configEditorView.fileContent
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 2
                            visible: configEditorView.configFileAvailable

                            Label {
                                text: "Changes take effect after restarting the application."
                                color: configEditorView.secondaryTextColor
                                font.pixelSize: Constants.captionFontSize
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Label {
                                text: configEditorView.lastSavedTime.length > 0
                                      ? "Automatically saved: "
                                        + configEditorView.lastSavedTime
                                      : "Automatically saved"
                                color: configEditorView.secondaryTextColor
                                font.pixelSize: Constants.captionFontSize
                            }
                        }

                        Rectangle {
                            id: configEditorFrame
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Constants.controlRadius
                            color: rootWindow.isDarkMode ? "#191919" : "#ffffff"
                            border.width: 1
                            border.color: configEditorView.borderColor
                            clip: true

                            FontMetrics {
                                id: configEditorFontMetrics
                                font: configTextArea.font
                            }

                            Rectangle {
                                id: lineNumberGutter
                                readonly property int digitCount:
                                    Math.max(2, String(Math.max(
                                        1, configTextArea.lineCount)).length)

                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: digitCount
                                       * configEditorFontMetrics.averageCharacterWidth
                                       + 16
                                visible: configEditorView.configFileAvailable
                                color: rootWindow.isDarkMode
                                       ? "#242424" : "#f0f0f0"

                                Rectangle {
                                    anchors.right: parent.right
                                    width: 1
                                    height: parent.height
                                    color: configEditorView.borderColor
                                }

                                Flickable {
                                    anchors.fill: parent
                                    clip: true
                                    interactive: false
                                    contentWidth: width
                                    contentHeight: lineNumbers.height
                                    contentY: configEditorScrollView.ScrollBar.vertical.position
                                              * contentHeight

                                    Column {
                                        id: lineNumbers
                                        y: configTextArea.topPadding
                                        width: lineNumberGutter.width - 8

                                        Repeater {
                                            model: configTextArea.lineCount

                                            Label {
                                                required property int index
                                                width: lineNumbers.width
                                                height: configEditorFontMetrics.lineSpacing
                                                text: index + 1
                                                font: configTextArea.font
                                                color: configEditorView.secondaryTextColor
                                                horizontalAlignment: Text.AlignRight
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }
                            }

                            ScrollView {
                                id: configEditorScrollView
                                anchors.left: lineNumberGutter.right
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                visible: configEditorView.configFileAvailable
                                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                                // Reserve a stable vertical scrollbar width. With
                                // both bars set to AsNeeded, the macOS style can
                                // repeatedly change the viewport dimensions while
                                // deciding whether each scrollbar is visible.
                                ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                                TextArea {
                                    id: configTextArea
                                    width: Math.max(configEditorScrollView.availableWidth,
                                                    contentWidth + leftPadding
                                                    + rightPadding)
                                    text: configEditorView.fileContent
                                    wrapMode: TextEdit.NoWrap
                                    selectByMouse: true
                                    selectByKeyboard: true
                                    background: null
                                    padding: 10

                                    onTextChanged: {
                                        qmlUtils.saveFileContent(
                                            CYCLONEDDS_URI, text)
                                        configEditorView.lastSavedTime =
                                            new Date().toLocaleString()
                                        configEditorView.updateCompletions()
                                    }
                                    onCursorPositionChanged:
                                        configEditorView.updateCompletions()
                                    onActiveFocusChanged: {
                                        if (!activeFocus)
                                            completionPopup.close()
                                    }

                                    Keys.priority: Keys.BeforeItem
                                    Keys.onPressed: function(event) {
                                        if (!completionPopup.opened)
                                            return

                                        if (event.key === Qt.Key_Down) {
                                            completionPopup.currentIndex =
                                                Math.min(
                                                    completionPopup.suggestions.length - 1,
                                                    completionPopup.currentIndex + 1)
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Up) {
                                            completionPopup.currentIndex =
                                                Math.max(0,
                                                    completionPopup.currentIndex - 1)
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Return
                                                   || event.key === Qt.Key_Enter
                                                   || event.key === Qt.Key_Tab) {
                                            configEditorView.acceptCompletion()
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Escape) {
                                            completionPopup.close()
                                            event.accepted = true
                                        }
                                    }

                                    XmlSyntaxHighlighter {
                                        textDocument: configTextArea.textDocument
                                        darkMode: rootWindow.isDarkMode
                                    }
                                }
                            }

                            Popup {
                                id: completionPopup
                                property var suggestions: []
                                property int currentIndex: 0
                                readonly property point cursorAnchor:
                                    configTextArea.mapToItem(
                                        configEditorFrame,
                                        configTextArea.cursorRectangle.x,
                                        configTextArea.cursorRectangle.y
                                        + configTextArea.cursorRectangle.height)

                                parent: configEditorFrame
                                x: Math.max(4, Math.min(cursorAnchor.x,
                                    parent.width - width - 4))
                                y: cursorAnchor.y + height + 4 <= parent.height
                                   ? cursorAnchor.y + 2
                                   : Math.max(4, cursorAnchor.y
                                              - height
                                              - configTextArea.cursorRectangle.height)
                                width: Math.min(420, parent.width - 8)
                                height: Math.min(240,
                                                 suggestions.length * 44)
                                padding: 0
                                modal: false
                                focus: false
                                closePolicy: Popup.NoAutoClose

                                background: Rectangle {
                                    radius: Constants.controlRadius
                                    color: configEditorView.surfaceColor
                                    border.width: 1
                                    border.color: configEditorView.borderColor
                                }

                                contentItem: ListView {
                                    id: completionList
                                    clip: true
                                    model: completionPopup.suggestions
                                    currentIndex: completionPopup.currentIndex
                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AsNeeded
                                    }

                                    delegate: Rectangle {
                                        id: completionDelegate
                                        required property int index
                                        required property var modelData
                                        readonly property bool selected:
                                            index === completionPopup.currentIndex
                                        width: completionList.width
                                        height: 44
                                        color: selected
                                               ? Constants.accentColor
                                               : "transparent"

                                        Column {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 70
                                            spacing: 1

                                            Label {
                                                width: parent.width
                                                text: modelData.label
                                                font.family: configTextArea.font.family
                                                font.bold: true
                                                color: completionDelegate.selected
                                                       ? "white"
                                                       : rootWindow.isDarkMode
                                                         ? "white" : "black"
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                width: parent.width
                                                visible: text.length > 0
                                                text: modelData.detail
                                                color: completionDelegate.selected
                                                       ? "#e8ecff"
                                                       : configEditorView.secondaryTextColor
                                                font.pixelSize: Constants.captionFontSize
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Rectangle {
                                            id: completionDocumentationButton
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 58
                                            height: 26
                                            radius: Constants.controlRadius
                                            scale: completionDocumentationMouseArea.pressed
                                                   ? 0.96 : 1
                                            color: completionDocumentationMouseArea.containsMouse
                                                   ? completionDelegate.selected
                                                     ? "#e8ecff"
                                                     : rootWindow.isDarkMode
                                                       ? "#505050" : "#d7e0ff"
                                                   : completionDelegate.selected
                                                     ? "#ffffff"
                                                   : rootWindow.isDarkMode
                                                     ? "#404040" : "#e1e1e1"
                                            border.width: 1
                                            border.color:
                                                completionDocumentationMouseArea.containsMouse
                                                ? Constants.accentColor
                                                : completionDelegate.selected
                                                  ? "#d5dcff"
                                                  : configEditorView.borderColor

                                            Behavior on scale {
                                                NumberAnimation { duration: 80 }
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: qsTrId(
                                                    "config.documentation.short")
                                                font.bold: true
                                                font.pixelSize:
                                                    Constants.captionFontSize
                                                color: completionDelegate.selected
                                                       ? Constants.accentColor
                                                       : rootWindow.isDarkMode
                                                         ? "white" : "#303030"
                                            }

                                            MouseArea {
                                                id: completionDocumentationMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered:
                                                    completionPopup.currentIndex = index
                                                onClicked: {
                                                    configEditorView.showDocumentation(
                                                        modelData.path)
                                                    completionPopup.close()
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.left: parent.left
                                            anchors.right:
                                                completionDocumentationButton.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered:
                                                completionPopup.currentIndex = index
                                            onClicked: {
                                                completionPopup.currentIndex = index
                                                configEditorView.acceptCompletion()
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: Math.min(parent.width - 40, 440)
                                spacing: 12
                                visible: !configEditorView.configFileAvailable

                                Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "No configuration file was found in CYCLONEDDS_URI."
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                }

                                Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "Create a new XML file and configure the environment variable to use it."
                                    color: configEditorView.secondaryTextColor
                                    wrapMode: Text.Wrap
                                }

                                Button {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Create New Configuration"
                                    highlighted: true
                                    onClicked: fileDialog.open()
                                }

                                TextEdit {
                                    id: envHintText
                                    width: parent.width
                                    visible: text.length > 0
                                    readOnly: true
                                    wrapMode: Text.WordWrap
                                    selectByMouse: true
                                    horizontalAlignment: Text.AlignHCenter
                                    color: rootWindow.isDarkMode
                                           ? "#e0e0e0"
                                           : "#303030"
                                }
                            }
                        }

                    }

                    FileDialog {
                        id: fileDialog
                        currentFolder: StandardPaths.standardLocations(
                                           StandardPaths.HomeLocation)[0]
                        fileMode: FileDialog.SaveFile
                        defaultSuffix: "xml"
                        title: "Create New Configuration File"

                        onAccepted: {
                            qmlUtils.createFileFromQUrl(selectedFile)
                            const localPath =
                                qmlUtils.toLocalFile(selectedFile)
                            envHintText.text =
                                "The new configuration file has been created.\n\n"
                                + "Set the environment variable:\n"
                                + "CYCLONEDDS_URI=file://" + localPath
                                + "\n\nThen restart the application."
                            const defaultConfig =
`<?xml version="1.0" encoding="UTF-8" ?>
<CycloneDDS xmlns="https://cdds.io/config" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="https://cdds.io/config https://raw.githubusercontent.com/eclipse-cyclonedds/cyclonedds/master/etc/cyclonedds.xsd">
    <Domain Id="any">
        <General>
            <Interfaces>
                <NetworkInterface autodetermine="true" priority="default" multicast="default" />
            </Interfaces>
        </General>
    </Domain>
</CycloneDDS>
`
                            qmlUtils.saveFileContent(localPath, defaultConfig)
                        }
                    }

                    Component.onCompleted: {
                        if (qmlUtils.isValidFile(CYCLONEDDS_URI)
                                && CYCLONEDDS_URI !== "<not set>"
                                && CYCLONEDDS_URI !== "") {
                            configEditorView.configFileAvailable = true
                            configEditorView.fileContent =
                                qmlUtils.loadFileContent(CYCLONEDDS_URI)
                            configTextArea.text =
                                configEditorView.fileContent
                        } else {
                            configEditorView.configFileAvailable = false
                        }
                    }
                }

                ColumnLayout {
                    visible: configEditorView.documentationVisible
                    SplitView.fillWidth: !configEditorView.editorVisible
                    SplitView.preferredWidth: 420
                    SplitView.minimumWidth: 320
                    SplitView.maximumWidth: configEditorView.editorVisible
                                            ? 620 : 16777215
                    spacing: 8

                    Label {
                        text: qsTrId("config.tab.configdocumentation")
                        font.pixelSize: Constants.sectionTitleFontSize
                        font.bold: true
                    }

                    SplitView {
                        id: configBrowserSplit
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        orientation: configEditorView.editorVisible
                                     ? Qt.Vertical : Qt.Horizontal
                        handle: Rectangle {
                            implicitWidth: 10
                            implicitHeight: 10
                            color: "transparent"

                            Rectangle {
                                anchors.centerIn: parent
                                width: configBrowserSplit.orientation
                                       === Qt.Horizontal
                                       ? 1 : parent.width - 12
                                height: configBrowserSplit.orientation
                                        === Qt.Horizontal
                                        ? parent.height - 12 : 1
                                color: parent.SplitHandle.hovered
                                       || parent.SplitHandle.pressed
                                       ? Constants.accentColor
                                       : configEditorView.borderColor
                            }
                        }

                        Rectangle {
                            SplitView.preferredWidth: 300
                            SplitView.minimumWidth: 180
                            SplitView.preferredHeight: 260
                            SplitView.minimumHeight: 120
                            color: rootWindow.isDarkMode ? "#191919" : "#ffffff"
                            border.width: 1
                            border.color: configEditorView.borderColor
                            radius: Constants.controlRadius
                            clip: true

                            TreeView {
                                id: treeView
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true
                                flickableDirection: Flickable.VerticalFlick
                                ScrollBar.horizontal: ScrollBar {
                                    policy: ScrollBar.AlwaysOff
                                }
                                ScrollBar.vertical: ScrollBar {}
                                selectionModel: ItemSelectionModel {
                                    onCurrentIndexChanged: {
                                        details.text =
                                            modelXsd.detailsAt(currentIndex)
                                    }
                                }
                                model: modelXsd

                                delegate: Item {
                                    implicitWidth: treeView.width
                                    implicitHeight: label.implicitHeight * 1.6

                                    readonly property real indentation: 20
                                    readonly property real padding: 5

                                    required property TreeView treeView
                                    required property bool isTreeNode
                                    required property bool expanded
                                    required property int hasChildren
                                    required property int depth
                                    required property int row
                                    required property int column
                                    required property bool current
                                    required property string display

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: row === treeView.currentRow
                                        color: Constants.selectionBackgroundColor(rootWindow.isDarkMode)
                                        opacity: 0.3
                                        radius: 5
                                    }

                                    ChevronIcon {
                                        width: 14
                                        height: 14
                                        x: padding + depth * indentation
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: isTreeNode && hasChildren
                                        iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                                        direction: expanded ? "down" : "right"

                                        TapHandler {
                                            onSingleTapped: {
                                                const itemIndex =
                                                    treeView.index(row, column)
                                                treeView.selectionModel
                                                    .setCurrentIndex(
                                                        itemIndex,
                                                        ItemSelectionModel.NoUpdate)
                                                treeView.toggleExpanded(row)
                                            }
                                        }
                                    }

                                    Label {
                                        id: label
                                        x: padding + (isTreeNode
                                                      ? (depth + 1)
                                                        * indentation
                                                      : 0)
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - padding - x - 10
                                        clip: true
                                        text: display
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: documentationDetailsPane
                            SplitView.fillWidth: true
                            SplitView.minimumWidth: 240
                            SplitView.fillHeight: true
                            SplitView.minimumHeight: 120
                            color: rootWindow.isDarkMode ? "#191919" : "#ffffff"
                            border.width: 1
                            border.color: configEditorView.borderColor
                            radius: Constants.controlRadius
                            clip: true

                            ScrollView {
                                anchors.fill: parent
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                                TextArea {
                                    id: details
                                    implicitWidth: documentationDetailsPane.width
                                    readOnly: true
                                    wrapMode: TextEdit.Wrap
                                    text: qsTrId("general.nothing.selected")
                                    padding: 16
                                    background: null
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
