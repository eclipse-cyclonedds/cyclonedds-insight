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
import "qrc:/src/views"
import "qrc:/src/views/elements"

Rectangle {
    id: settingsViewId
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground
    property string fileContent: ""
    property string lastSavedTime: ""
    property bool configFileAvailable: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 5
        anchors.topMargin: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 10

        Label {
            text: qsTrId("general.configeditor")
            font.bold: true
            font.pointSize: 16
            Layout.alignment: Qt.AlignLeft
        }

        TabBar {
            id: bar
            Layout.fillWidth: true

            InsightTabButton {
                tabText: qsTrId("config.tab.file")
                width: 250
            }
            InsightTabButton {
                tabText: qsTrId("config.tab.configdocumentation")
                width: 250
            }
        }

        StackLayout {
            id: mainLayoutId
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: bar.currentIndex
        

            Item {
                id: createTabItem
                Layout.fillWidth: true
                Layout.fillHeight: true


                ColumnLayout {
                    anchors.fill: parent
                    spacing: 5
                    anchors.topMargin: 10
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.bottomMargin: 10

                    Label {
                        id: uriLabel
                        text: "CYCLONEDDS_URI: " + CYCLONEDDS_URI
                        font.bold: true
                    }


                    ScrollView {
                        id: scrollView
                        visible: configFileAvailable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        TextArea {
                            id: textArea
                            text: fileContent
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            selectByKeyboard: true
                            onTextChanged: {
                                qmlUtils.saveFileContent(CYCLONEDDS_URI, text)
                                lastSavedTime = new Date().toLocaleString()
                            }
                        }
                    }

                    Label {
                        visible: !configFileAvailable 
                        text: "No file found in the env variable CYCLONEDDS_URI."
                    }

                    Button {
                        id: reloadButton
                        text: "Create New Configuration"
                        visible: !configFileAvailable 
                        Layout.alignment: Qt.AlignLeft
                        onClicked: {
                            fileDialog.open()
                        }
                    }

                    RowLayout {
                        visible: configFileAvailable
                        spacing: 0
                        Label {
                            visible: configFileAvailable
                            text: "Changes will take effect after restarting the application."
                        }
                        Item {
                            visible: configFileAvailable
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                        Label {
                            text: "Automatically saved: "
                        }
                        Label {
                            text: lastSavedTime
                        }
                    }

                    TextEdit {
                        id: envHintText
                        visible: false
                        text: ""
                        readOnly: true
                        wrapMode: Text.WordWrap
                        selectByMouse: true
                        color: uriLabel.color
                    }

                    Item {
                        visible: !configFileAvailable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }

                FileDialog {
                    id: fileDialog
                    currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
                    fileMode: FileDialog.SaveFile
                    defaultSuffix: "xml"
                    title: "Create New Configuration File"
                    onAccepted: {
                        qmlUtils.createFileFromQUrl(selectedFile)
                        var localPath = qmlUtils.toLocalFile(selectedFile);
                        envHintText.text = "The new configuration file has been created.\n\nSet the env-variable:\nCYCLONEDDS_URI=file://" + localPath + "\n\nAnd restart the application."
                        envHintText.visible = true
                        var defaultConfig = `<?xml version="1.0" encoding="UTF-8" ?>
<CycloneDDS xmlns="https://cdds.io/config" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="https://cdds.io/config https://raw.githubusercontent.com/eclipse-cyclonedds/cyclonedds/master/etc/cyclonedds.xsd">
    <Domain Id="any">
        <General>
            <Interfaces>
                <NetworkInterface autodetermine="true" priority="default" multicast="default" />
            </Interfaces>
        </General>
    </Domain>
</CycloneDDS>
`;
                        qmlUtils.saveFileContent(localPath, defaultConfig);
                    }
                }

                Component {
                    id: textAreaBackgroundComponent
                    Rectangle {
                        color: rootWindow.isDarkMode ? "black" : "white"
                    }
                }

                Component.onCompleted: {
                    if (Qt.platform.os !== "osx") {
                        textArea.background = textAreaBackgroundComponent.createObject(textArea);
                    }

                    if (qmlUtils.isValidFile(CYCLONEDDS_URI) && CYCLONEDDS_URI !== "<not set>" && CYCLONEDDS_URI !== "") {
                        configFileAvailable = true;
                        fileContent = qmlUtils.loadFileContent(CYCLONEDDS_URI)
                        textArea.text = fileContent
                    } else {
                        configFileAvailable = false;
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                SplitView {
                    id: configBrowSplit
                    anchors.fill: parent

                    TreeView {
                        id: treeView
                        clip: true
                        ScrollBar.vertical: ScrollBar {}
                        SplitView.preferredWidth: 300
                        selectionModel: ItemSelectionModel {
                            id: treeSelection
                            onCurrentIndexChanged: {
                                details.text = modelXsd.detailsAt(currentIndex)
                            }
                        }
                        model: modelXsd

                        delegate: Item {
                            implicitWidth: treeView.width
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

                            // Rotate indicator when expanded by the user
                            // (requires TreeView to have a selectionModel)
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
                                height: parent.height
                                width: parent.width - 10
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
                                width: parent.width - padding - x - 10
                                clip: true
                                text: model.display
                            }
                        }
                    }

                    ScrollView {
                        SplitView.fillWidth: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        TextArea {
                            id: details
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            text: qsTrId("general.nothing.selected")
                            padding: 16
                            width: parent.width
                        }
                    }
                }
            }
        }
    }
}
