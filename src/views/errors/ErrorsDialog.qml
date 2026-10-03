/*
 * Copyright(c) 2026 Sven Trittler
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

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"
import "qrc:/src/views/icons"
import "qrc:/src/views/elements"

Popup {
    id: errorsDialog

    property int activeCount: 0
    property var errorModel
    property int totalCount: 0

    signal acknowledgeAllRequested
    signal acknowledgeRequested(int index)
    signal clearRequested
    signal removeRequested(int index)

    anchors.centerIn: parent
    height: Math.min(480, Math.max(0, parent ? parent.height - 24 : 0))
    modal: true
    padding: 0
    width: Math.min(760, Math.max(0, parent ? parent.width - 24 : 0))

    background: Rectangle {
        border.color: Constants.designBorderColor(rootWindow.isDarkMode)
        border.width: 1
        color: Constants.mainContentColor(rootWindow.isDarkMode)
        radius: Constants.cardRadius
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 10

            WarningTriangle {
                Layout.preferredHeight: 25
                Layout.preferredWidth: 25
                visible: errorsDialog.totalCount > 0
            }
            Rectangle {
                Layout.preferredHeight: 25
                Layout.preferredWidth: 25
                visible: errorsDialog.totalCount === 0
                border.color: Constants.designBorderColor(rootWindow.isDarkMode)
                border.width: 1
                color: rootWindow.isDarkMode ? "#303030" : "#eeeeee"
                radius: width / 2

                Label {
                    anchors.centerIn: parent
                    color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                    font.bold: true
                    font.pixelSize: 14
                    text: "✓"
                }
            }
            Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                font.bold: true
                font.pixelSize: Constants.pageTitleFontSize
                text: errorsDialog.totalCount > 0 ? qsTrId("errors.title") : qsTrId("errors.none")
                wrapMode: Text.WordWrap
            }
            IconActionButton {
                Accessible.name: qsTrId("general.close")
                icon: "close"

                onClicked: errorsDialog.close()
            }
        }
        Label {
            Layout.fillWidth: true
            color: errorsDialog.activeCount > 0 ? Constants.errorColor : Constants.secondaryTextColor(rootWindow.isDarkMode)
            font.bold: errorsDialog.activeCount > 0
            text: errorsDialog.activeCount > 0 ? qsTrId("errors.active.count").arg(errorsDialog.activeCount) : errorsDialog.totalCount > 0 ? qsTrId("errors.all.acknowledged") : qsTrId("errors.none.reported")
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: acknowledgeAllButton

                border.color: Constants.designBorderColor(rootWindow.isDarkMode)
                border.width: 1
                color: acknowledgeAllMouse.containsMouse && enabled ? (rootWindow.isDarkMode ? "#383838" : "#e9e9e9") : "transparent"
                enabled: errorsDialog.activeCount > 0
                implicitHeight: 30
                implicitWidth: acknowledgeAllContent.implicitWidth + 18
                opacity: enabled ? 1.0 : 0.4
                radius: Constants.controlRadius

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                RowLayout {
                    id: acknowledgeAllContent

                    anchors.centerIn: parent
                    spacing: 6

                    Label {
                        color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                        font.bold: true
                        text: "✓"
                    }
                    Label {
                        color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                        font.bold: true
                        text: qsTrId("errors.acknowledge.all")
                    }
                }
                MouseArea {
                    id: acknowledgeAllMouse

                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: acknowledgeAllButton.enabled
                    hoverEnabled: true

                    onClicked: errorsDialog.acknowledgeAllRequested()
                }
            }
            IconActionButton {
                id: clearButton

                destructive: true
                enabled: errorsDialog.totalCount > 0
                icon: "delete-all"
                opacity: enabled ? 1.0 : 0.4

                onClicked: errorsDialog.clearRequested()
            }
        }
        Label {
            Layout.fillWidth: true
            color: Constants.secondaryTextColor(rootWindow.isDarkMode)
            font.pixelSize: Constants.captionFontSize
            text: errorsDialog.totalCount === 1 ? qsTrId("errors.recorded.one") : qsTrId("errors.recorded.count").arg(errorsDialog.totalCount)
            visible: errorsDialog.totalCount > 0
            wrapMode: Text.WordWrap
        }
        ListView {
            id: errorsList

            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            model: errorsDialog.errorModel
            spacing: 8

            ScrollBar.vertical: ScrollBar {
                id: errorsScrollBar

                policy: ScrollBar.AsNeeded
            }
            delegate: Rectangle {
                id: errorDelegate

                required property bool acknowledged
                required property int index
                required property string message
                required property string timestamp

                border.color: Constants.designBorderColor(rootWindow.isDarkMode)
                border.width: 1
                color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
                implicitHeight: errorContent.implicitHeight + 20
                radius: Constants.cardRadius
                width: errorsList.width - (errorsScrollBar.visible ? errorsScrollBar.width + 6 : 0)

                ColumnLayout {
                    id: errorContent

                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 22

                            WarningTriangle {
                                anchors.fill: parent
                                warningColor: Constants.errorColor
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -2
                                anchors.right: parent.right
                                anchors.rightMargin: -2
                                border.color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
                                border.width: 1
                                color: Constants.successColor
                                height: 12
                                radius: 6
                                visible: errorDelegate.acknowledged
                                width: 12

                                Label {
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 8
                                    text: "✓"
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                Layout.fillWidth: true
                                text: errorDelegate.message
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                            }
                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                color: errorDelegate.acknowledged ? Constants.secondaryTextColor(rootWindow.isDarkMode) : Constants.errorColor
                                font.pixelSize: Constants.captionFontSize
                                text: errorDelegate.timestamp + "  ·  " + (errorDelegate.acknowledged ? qsTrId("errors.acknowledged") : qsTrId("errors.active"))
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        Item {
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            id: acknowledgeButton

                            Layout.alignment: Qt.AlignTop
                            border.color: errorDelegate.acknowledged ? Constants.successColor : Constants.designBorderColor(rootWindow.isDarkMode)
                            border.width: 1
                            color: errorDelegate.acknowledged ? (rootWindow.isDarkMode ? "#254531" : "#def4e7") : acknowledgeMouse.containsMouse ? (rootWindow.isDarkMode ? "#383838" : "#e9e9e9") : "transparent"
                            implicitHeight: 28
                            implicitWidth: acknowledgeLabel.implicitWidth + 20
                            radius: Constants.controlRadius

                            Label {
                                id: acknowledgeLabel

                                anchors.centerIn: parent
                                color: errorDelegate.acknowledged ? Constants.successColor : Constants.mutedForegroundColor(rootWindow.isDarkMode)
                                font.bold: errorDelegate.acknowledged
                                text: errorDelegate.acknowledged ? qsTrId("errors.acknowledged.with-icon") : qsTrId("errors.acknowledge")
                            }
                            MouseArea {
                                id: acknowledgeMouse

                                anchors.fill: parent
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: !errorDelegate.acknowledged
                                hoverEnabled: true

                                onClicked: errorsDialog.acknowledgeRequested(errorDelegate.index)
                            }
                        }
                        IconActionButton {
                            Layout.alignment: Qt.AlignTop
                            destructive: true
                            icon: "delete"

                            onClicked: errorsDialog.removeRequested(errorDelegate.index)
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: errorsDialog.totalCount === 0
                width: parent.width

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    border.color: Constants.designBorderColor(rootWindow.isDarkMode)
                    border.width: 1
                    color: rootWindow.isDarkMode ? "#303030" : "#eeeeee"
                    height: 42
                    radius: 21
                    width: 42

                    Label {
                        anchors.centerIn: parent
                        color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                        font.bold: true
                        font.pixelSize: 19
                        text: "✓"
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.bold: true
                    font.pixelSize: Constants.sectionTitleFontSize
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTrId("errors.empty.title")
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTrId("errors.empty.description")
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
