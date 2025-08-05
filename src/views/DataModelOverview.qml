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
    id: dataModelOverviewId
    implicitHeight: parent.height
    implicitWidth: parent.width
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

    Component.onCompleted: {
        datamodelRepoModel.loadModules()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            color: rootWindow.isDarkMode ? Constants.darkHeaderBackground : Constants.lightHeaderBackground
            Layout.fillWidth: true
            Layout.preferredHeight: importBtnId.height

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Label {
                    text: "Data Model"
                    Layout.leftMargin: 10
                }
                Item {
                    Layout.fillWidth: true
                }

                Button {
                    id: importBtnId
                    text: "Import"
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    onClicked: {
                        console.log("Import idl files clicked")
                        idlDropAreaId.isEntered = true
                    }
                }
                Button {
                    text: "Clear"
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    onClicked: clearDialog.open()
                }
                Button {
                    text: "\u{1F50D}"
                    flat: true
                    highlighted: searchField.visible
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    onClicked: {
                        if (searchField.visible) {
                            searchField.visible = false
                            searchField.text = ""
                        } else {
                            searchField.visible = true
                        }
                    }
                    Layout.preferredWidth: Qt.platform.os === "osx" ? 50 : 30
                    Layout.preferredHeight: Qt.platform.os === "osx" ? 30 : 24
                }
            }
        }

        TextField {
            id: searchField
            placeholderText: "Search Data Model ..."
            visible: false
            Layout.fillWidth: true
            onTextChanged: {
                datamodelRepoModelProxy.setFilter(searchField.text)
            }
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.bottomMargin: 5

        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 10
            clip: true
            ScrollBar.vertical: ScrollBar {}
            model: datamodelRepoModelProxy
            delegate: Item {
                implicitWidth: dataModelOverviewId.width
                implicitHeight: nameLabel.implicitHeight * 1.5

                Rectangle {
                    anchors.fill: parent
                    color: (dataModelItemMouseArea.hovered || contextMenu.visible)? rootWindow.isDarkMode ? Constants.darkSelectionBackground : Constants.lightSelectionBackground : "transparent"
                    opacity: 0.3
                }

                Label {
                    id: nameLabel
                    text: name
                }

                MouseArea {
                    id: dataModelItemMouseArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    property bool hovered: false
                    onClicked: {
                        contextMenu.popup()
                    }
                    onEntered: {
                        hovered = true
                    }
                    onExited: {
                        hovered = false
                    }

                    Menu {
                        id: contextMenu
                        MenuItem {
                            text: "Create Reader (Listener)"
                            onTriggered: {
                                readerTesterDialogId.setType(name, 3)
                                readerTesterDialogId.open()
                            }
                        }
                        MenuItem {
                            text: "Create Writer (Tester)"
                            onTriggered: {
                                readerTesterDialogId.setType(name, 4)
                                readerTesterDialogId.open()
                            }
                        }
                    }
                }
            }
        }
    }

    MessageDialog {
        id: clearDialog
        title: qsTr("Alert");
        text: qsTr("Sure to delete the datamodel?");
        buttons: MessageDialog.Ok | MessageDialog.Cancel;
        onButtonClicked: function (button, role) {
            if (role === MessageDialog.AcceptRole || role === MessageDialog.YesRole) {
                datamodelRepoModel.clear()
            }
        }
    }
}
