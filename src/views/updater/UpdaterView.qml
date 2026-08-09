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

import "qrc:/src/views"
import "qrc:/src/views/selection_details"


Window {
    id: updaterRootWindow

    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    readonly property color borderColor: Constants.designBorderColor(rootWindow.isDarkMode)
    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)

    width: 420
    height: 350
    visible: true
    title: "CycloneDDS Insight Updater"
    color: Constants.mainContentColor(rootWindow.isDarkMode)
    flags: Qt.Window | Qt.WindowTitleHint | Qt.CustomizeWindowHint
    modality: Qt.ApplicationModal
    maximumWidth: width
    maximumHeight: height
    minimumWidth: width
    minimumHeight: height

    property bool isError: false
    property string organization: ""
    property string project: ""
    property string newBuildId: "0"
    property bool isExternUpdater: false

    function startUpdate(organization, project, newBuildId, isExternUpdater) {
        updaterRootWindow.organization = organization
        updaterRootWindow.project = project
        updaterRootWindow.newBuildId = newBuildId
        updaterRootWindow.isExternUpdater = isExternUpdater
        updaterRootWindow.isError = false
        progressBar.value = 0
        statusText.text = qsTrId("update.preparing")
        updaterView.visible = true
        updaterModel.downloadFile(
            organization, project, newBuildId, isExternUpdater)
    }

    Connections {
        target: updaterModel
        function onUpdateStepCompleted(msg) {
            statusText.text = msg
        }
        function onCompleted() {
            progressBar.value += 1
        }
        function onError(error) {
            updaterRootWindow.isError = true
            statusText.text = error
        }
        function onProxyAuthRequiredUpdater() {
            updaterRootWindow.visible = false
            proxyAuthWindowUpdater.visible = true
        }
    }

    function showAndCheckForUpdates() {
        updaterRootWindow.visible = true
        updaterRootWindow.startUpdate(
            updaterRootWindow.organization,
            updaterRootWindow.project,
            updaterRootWindow.newBuildId,
            updaterRootWindow.isExternUpdater)
    }

    function showWithoutUpdate() {
        updaterRootWindow.visible = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            DetailBadge {
                kind: "update"
            }

            Label {
                text: updaterRootWindow.isError
                      ? qsTrId("general.error")
                      : qsTrId("update.ready.title")
                font.pixelSize: Constants.pageTitleFontSize
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 9
            color: updaterRootWindow.surfaceColor
            border.width: 1
            border.color: updaterRootWindow.isError
                          ? Constants.errorColor : updaterRootWindow.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Constants.pageMargin
                spacing: 13

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82

                    AnimatedImage {
                        anchors.centerIn: parent
                        source: "qrc:/res/images/spinning.gif"
                        sourceSize.width: 72
                        sourceSize.height: 72
                        width: 72
                        height: 72
                        paused: updaterRootWindow.isError
                        opacity: updaterRootWindow.isError ? 0.35 : 1
                    }

                    Rectangle {
                        visible: updaterRootWindow.isError
                        anchors.centerIn: parent
                        width: 38
                        height: 38
                        radius: 19
                        color: rootWindow.isDarkMode ? "#4b2528" : "#ffe6e8"
                        border.width: 1
                        border.color: Constants.errorColor

                        Label {
                            anchors.centerIn: parent
                            text: "!"
                            font.pixelSize: 20
                            font.bold: true
                            color: Constants.errorColor
                        }
                    }
                }

                Label {
                    id: statusText
                    Layout.fillWidth: true
                    text: qsTrId("update.preparing")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.bold: true
                }

                ProgressBar {
                    id: progressBar
                    Layout.fillWidth: true
                    from: 0
                    to: 4
                    value: 0
                    indeterminate: value === 0
                                   && !updaterRootWindow.isError
                }

                Label {
                    Layout.fillWidth: true
                    text: updaterRootWindow.isError
                          ? qsTrId("update.failed.description")
                          : qsTrId("update.keep.open")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: updaterRootWindow.secondaryTextColor
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: updaterRootWindow.isError
                      ? qsTrId("general.exit")
                      : qsTrId("general.cancel")
                onClicked: {
                    updaterModel.cancel()
                    Qt.quit()
                }
            }
        }
    }
}
