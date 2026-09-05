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

Window {
    id: errorsDialog

    property var errorModel
    property int activeCount: 0
    property int totalCount: 0
    signal acknowledgeRequested(int index)
    signal removeRequested(int index)
    signal acknowledgeAllRequested()
    signal clearRequested()

    title: qsTrId("errors.window.title")
    visible: false
    width: 760
    height: 480
    minimumWidth: 580
    minimumHeight: 320
    flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
    color: Constants.mainContentColor(rootWindow.isDarkMode)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 10

            WarningTriangle {
                Layout.preferredWidth: 25
                Layout.preferredHeight: 25
            }

            Label {
                text: qsTrId("errors.title")
                font.pixelSize: Constants.pageTitleFontSize
                font.bold: true
            }

            Label {
                text: errorsDialog.activeCount > 0
                      ? qsTrId("errors.active.count").arg(errorsDialog.activeCount)
                      : errorsDialog.totalCount > 0
                        ? qsTrId("errors.all.acknowledged") : qsTrId("errors.none.reported")
                color: errorsDialog.activeCount > 0
                       ? Constants.errorColor
                       : Constants.secondaryTextColor(rootWindow.isDarkMode)
                font.bold: errorsDialog.activeCount > 0
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: acknowledgeAllButton
                implicitWidth: acknowledgeAllContent.implicitWidth + 18
                implicitHeight: 30
                radius: Constants.controlRadius
                enabled: errorsDialog.activeCount > 0
                opacity: enabled ? 1.0 : 0.4
                color: acknowledgeAllMouse.containsMouse && enabled
                       ? (rootWindow.isDarkMode ? "#383838" : "#e9e9e9")
                       : "transparent"
                border.width: 1
                border.color: Constants.designBorderColor(rootWindow.isDarkMode)

                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    id: acknowledgeAllContent
                    anchors.centerIn: parent
                    spacing: 6

                    Label {
                        text: "✓"
                        color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                        font.bold: true
                    }

                    Label {
                        text: qsTrId("errors.acknowledge.all")
                        color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                        font.bold: true
                    }
                }

                MouseArea {
                    id: acknowledgeAllMouse
                    anchors.fill: parent
                    enabled: acknowledgeAllButton.enabled
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: errorsDialog.acknowledgeAllRequested()
                }
            }

            IconActionButton {
                id: clearButton
                icon: "delete-all"
                destructive: true
                enabled: errorsDialog.totalCount > 0
                opacity: enabled ? 1.0 : 0.4
                onClicked: errorsDialog.clearRequested()
            }
        }

        Label {
            visible: errorsDialog.totalCount > 0
            text: errorsDialog.totalCount === 1
                  ? qsTrId("errors.recorded.one")
                  : qsTrId("errors.recorded.count").arg(errorsDialog.totalCount)
            color: Constants.secondaryTextColor(rootWindow.isDarkMode)
            font.pixelSize: Constants.captionFontSize
        }

        ListView {
            id: errorsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: errorsDialog.errorModel
            ScrollBar.vertical: ScrollBar {
                id: errorsScrollBar
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                id: errorDelegate
                required property int index
                required property string message
                required property string timestamp
                required property bool acknowledged
                width: errorsList.width
                       - (errorsScrollBar.visible ? errorsScrollBar.width + 6 : 0)
                implicitHeight: errorContent.implicitHeight + 20
                radius: Constants.cardRadius
                color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
                border.width: 1
                border.color: Constants.designBorderColor(rootWindow.isDarkMode)

                RowLayout {
                    id: errorContent
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Item {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22

                        WarningTriangle {
                            anchors.fill: parent
                            warningColor: Constants.errorColor
                        }

                        Rectangle {
                            width: 12
                            height: 12
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: -2
                            anchors.bottomMargin: -2
                            visible: errorDelegate.acknowledged
                            radius: 6
                            color: Constants.successColor
                            border.width: 1
                            border.color: Constants.cardBackgroundColor(rootWindow.isDarkMode)

                            Label {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "white"
                                font.bold: true
                                font.pixelSize: 8
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Label {
                            Layout.fillWidth: true
                            text: errorDelegate.message
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }

                        Label {
                            text: errorDelegate.timestamp + "  ·  "
                                  + (errorDelegate.acknowledged
                                     ? qsTrId("errors.acknowledged") : qsTrId("errors.active"))
                            font.pixelSize: Constants.captionFontSize
                            color: errorDelegate.acknowledged
                                   ? Constants.secondaryTextColor(rootWindow.isDarkMode)
                                   : Constants.errorColor
                        }
                    }

                    Rectangle {
                        id: acknowledgeButton
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: acknowledgeLabel.implicitWidth + 20
                        implicitHeight: 28
                        radius: Constants.controlRadius
                        color: errorDelegate.acknowledged
                               ? (rootWindow.isDarkMode ? "#254531" : "#def4e7")
                               : acknowledgeMouse.containsMouse
                                 ? (rootWindow.isDarkMode ? "#383838" : "#e9e9e9")
                                 : "transparent"
                        border.width: 1
                        border.color: errorDelegate.acknowledged
                                      ? Constants.successColor
                                      : Constants.designBorderColor(rootWindow.isDarkMode)

                        Label {
                            id: acknowledgeLabel
                            anchors.centerIn: parent
                            text: errorDelegate.acknowledged
                                  ? qsTrId("errors.acknowledged.with-icon") : qsTrId("errors.acknowledge")
                            color: errorDelegate.acknowledged
                                   ? Constants.successColor
                                   : Constants.mutedForegroundColor(rootWindow.isDarkMode)
                            font.bold: errorDelegate.acknowledged
                        }

                        MouseArea {
                            id: acknowledgeMouse
                            anchors.fill: parent
                            enabled: !errorDelegate.acknowledged
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: errorsDialog.acknowledgeRequested(errorDelegate.index)
                        }
                    }

                    IconActionButton {
                        Layout.alignment: Qt.AlignTop
                        icon: "delete"
                        destructive: true
                        onClicked: errorsDialog.removeRequested(errorDelegate.index)
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: errorsDialog.totalCount === 0
                spacing: 8

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 42
                    height: 42
                    radius: 21
                    color: rootWindow.isDarkMode ? "#303030" : "#eeeeee"
                    border.width: 1
                    border.color: Constants.designBorderColor(rootWindow.isDarkMode)

                    Label {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                        font.pixelSize: 19
                        font.bold: true
                    }
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTrId("errors.empty.title")
                    font.bold: true
                    font.pixelSize: Constants.sectionTitleFontSize
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTrId("errors.empty.description")
                    color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                }
            }
        }
    }
}
