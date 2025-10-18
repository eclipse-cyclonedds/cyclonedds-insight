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

import "qrc:/src/views"


Window {
    id: updaterRootWindow
    width: 300
    height: 350
    visible: true
    title: "CycloneDDS Insight Updater"
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground
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
        console.log("Starting update process...");
        updaterView.visible = true
        updaterModel.downloadFile(organization, project, newBuildId, isExternUpdater)
    }

    Connections {
        target: updaterModel
        function onUpdateStepCompleted(msg) {
            statusText.text = msg;
        }
        function onCompleted() {
            progressBar.value += 1
        }
        function onError(error) {
            updaterRootWindow.isError = true
            statusText.text = error;
        }
        function onProxyAuthRequiredUpdater() {
            console.info("Proxy auth needed, show auth window ...")
            updaterRootWindow.visible = false
            proxyAuthWindowUpdater.visible = true
        }
    }

    function showAndCheckForUpdates() {
        updaterRootWindow.visible = true
        updaterRootWindow.startUpdate(updaterRootWindow.organization, updaterRootWindow.project, updaterRootWindow.newBuildId, updaterRootWindow.isExternUpdater)
    }

    function showWithoutUpdate() {
        updaterRootWindow.visible = true
    }

    Item {
        anchors.fill: parent

        AnimatedImage {
            id: animatedLoadingId
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 40
            source: "qrc:/res/images/spinning.gif"
            sourceSize.height: 100
            sourceSize.width: 100
            height: 100
            width: 100
            paused: isError
        }

        ColumnLayout {
            anchors.topMargin: 50
            anchors.top: animatedLoadingId.bottom
            anchors.horizontalCenter: animatedLoadingId.horizontalCenter
            
            Label {
                text: isError ? "Error" : "Zap! Pow! Update!"
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                id: statusText
                text: "Init ..."
                Layout.alignment: Qt.AlignHCenter
            }
            ProgressBar {
                id: progressBar
                Layout.alignment: Qt.AlignHCenter
                from: 0
                to: 4
                value: 0
            }
            Button {
                text: isError ? "Exit" : "Cancel"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    updaterModel.cancel()
                    Qt.quit()
                }
            }
        }
    }
}
