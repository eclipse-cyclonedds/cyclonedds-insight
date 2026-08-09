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
import QtQuick.Controls
import QtQuick.Layouts

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"
import "qrc:/src/views/selection_details"


Window {
    id: checkForUpdatesWindow

    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    readonly property color borderColor: Constants.designBorderColor(rootWindow.isDarkMode)
    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)
    readonly property color statusColor: updateError
                                         ? Constants.errorColor
                                         : updateAvailable
                                           ? Constants.warningColor
                                           : Constants.successColor

    title: qsTrId("update.check.title")
    visible: false
    flags: Qt.Dialog
    modality: Qt.ApplicationModal
    color: Constants.mainContentColor(rootWindow.isDarkMode)


    property int updateCheckWidth: 500
    property int updateCheckHeight: 200

    width: updateCheckWidth
    height: updateCheckHeight
    minimumWidth: updateCheckWidth
    minimumHeight: updateCheckHeight
    maximumWidth: updateCheckWidth
    maximumHeight: updateCheckHeight

    property string organization: "eclipse-cyclonedds"
    property string project: "cyclonedds-insight"
    property string branch: "refs/heads/master" // only master branch for now!
    property bool checkedForUpdate: false
    property bool updateCheckRunning: false
    property string lastUpdateTime: ""
    property bool updateAvailable: false
    property bool updateError: false
    property string newBuildId: "0"

    function proxyAuthRequired() {
        checkForUpdatesWindow.close()
        proxyAuthWindow.visible = true
    }

    function showAndCheckForUpdates() {
        checkForUpdatesWindow.visible = true
        getLatestBuildArtifacts()
    }

    function showWithoutUpdate() {
        checkForUpdatesWindow.visible = true
    }

    Connections {
        target: updaterModel
        function onProxyAuthRequired() {
            proxyAuthRequired()
        }
        function onNewBuildFound(newBuildIdFromModel) {
            updateCheckRunning = false
            checkedForUpdate = true
            updateAvailable = newBuildIdFromModel !== ""
            newBuildId = updateAvailable ? newBuildIdFromModel : "0"
            updateError = false
            lastUpdateTime = new Date().toLocaleString()
        }
        function onNewBuildError(newBuildIdFromModel) {
            updateCheckRunning = false
            checkedForUpdate = true
            updateAvailable = false
            updateError = true
        }
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
                text: qsTrId("update.software")
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
            color: checkForUpdatesWindow.surfaceColor
            border.width: 1
            border.color: checkForUpdatesWindow.borderColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 13

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: rootWindow.isDarkMode ? "#292929" : "#eeeeee"
                    border.width: 2
                    border.color: checkForUpdatesWindow.statusColor

                    BusyIndicator {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        running: checkForUpdatesWindow.updateCheckRunning
                        visible: running
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: !checkForUpdatesWindow.updateCheckRunning
                        text: checkForUpdatesWindow.updateError
                              ? "!" : checkForUpdatesWindow.updateAvailable
                                ? "\u2191" : "\u2713"
                        font.pixelSize: 18
                        font.bold: true
                        color: checkForUpdatesWindow.statusColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        Layout.fillWidth: true
                        text: updateCheckRunning
                              ? qsTrId("update.checking")
                              : updateError
                                ? qsTrId("update.check.failed")
                                : updateAvailable
                                  ? qsTrId("update.available")
                                  : checkedForUpdate
                                    ? qsTrId("update.current")
                                    : qsTrId("update.check.ready")
                        font.pixelSize: 14
                        font.bold: true
                        wrapMode: Text.Wrap
                    }

                    Label {
                        Layout.fillWidth: true
                        text: updateError
                              ? qsTrId("update.try.again")
                              : lastUpdateTime.length > 0
                                ? qsTrId("update.last.checked").arg(lastUpdateTime)
                                : qsTrId("update.channel.description")
                        color: checkForUpdatesWindow.secondaryTextColor
                        wrapMode: Text.Wrap
                    }

                    Label {
                        visible: updateAvailable && !updateCheckRunning
                                 && !updateError
                        text: qsTrId("update.artifacts.open")
                        font.bold: true
                        color: Constants.accentColor

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(
                                "https://dev.azure.com/" + organization + "/"
                                + project + "/_build/results?buildId="
                                + newBuildId
                                + "&view=artifacts&type=publishedArtifacts")
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                id: updaterButton
                visible: updateAvailable && !updateCheckRunning
                         && !updateError && IS_FROZEN
                text: qsTrId("update.now")
                highlighted: true
                onClicked: {
                    checkForUpdatesWindow.visible = false
                    updaterView.startUpdate(
                        organization, project, newBuildId, "")
                }
            }

            Button {
                text: checkedForUpdate
                      ? qsTrId("update.check.again")
                      : qsTrId("update.check.title")
                enabled: !updateCheckRunning
                onClicked: getLatestBuildArtifacts()
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: qsTrId("general.close")
                onClicked: checkForUpdatesWindow.visible = false
            }
        }
    }

    function getLatestBuildArtifacts() {
        updateError = false
        checkedForUpdate = true
        updateCheckRunning = true
        updaterModel.checkForUpdate()
    }
}
