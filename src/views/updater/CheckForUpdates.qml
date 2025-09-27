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


Window {
    id: checkForUpdatesWindow

    title: "Check for Updates"
    visible: false
    flags: Qt.Dialog
    modality: Qt.ApplicationModal
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

    property int updateCheckWidth: 400
    property int updateCheckHeight: 130

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

    onVisibleChanged: {
        if (visible) {
            getLatestBuildArtifacts()
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        Label {
            text: updateCheckRunning ? "Checking for updates..." : updateError ? "Failed to check for updates, try again later." : "Last checked: " + lastUpdateTime
        }

        Row {
            spacing: 10

            Label {
                text: updateAvailable ? "Update available" : "You're up to date!"
                visible: checkedForUpdate && !updateCheckRunning && !updateError
            }

            Label {
                text: "click here to download"
                font.underline: true
                font.bold: true
                visible: updateAvailable && !updateCheckRunning && !updateError

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://dev.azure.com/" + organization + "/" + project + "/_build/results?buildId=" + newBuildId + "&view=artifacts&type=publishedArtifacts")
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10

            Button {
                id: updaterButton
                visible: updateAvailable && !updateCheckRunning && !updateError && IS_FROZEN
                text: "Update Now"
                onClicked: {
                    updaterView.startUpdate(organization, project, newBuildId)
                }
            }

            Button {
                text: "Check for Updates"
                visible: checkedForUpdate
                onClicked: getLatestBuildArtifacts()
            }

            Button {
                text: "OK"
                onClicked: checkForUpdatesWindow.visible = false
            }
        }
    }

    function getLatestBuildArtifacts() {

        updateError = false
        checkedForUpdate = true
        updateCheckRunning = true

        var buildsUrl = encodeURI("https://dev.azure.com/" + organization + "/" + project +
                        "/_apis/build/builds?definitions=" + CYCLONEDDS_INSIGHT_BUILD_PIPELINE_ID +
                        "&branchName=" + branch + "&statusFilter=succeeded&$top=1&api-version=7.0")

        console.log("Check for updates: ", buildsUrl)

        var xhr = new XMLHttpRequest()
        xhr.open("GET", buildsUrl)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText)
                    console.debug("Fetched builds: " + JSON.stringify(response))
                    if (response.value.length > 0) {
                        var latestBuild = response.value[0]
                        if (parseInt(latestBuild.id) > parseInt(CYCLONEDDS_INSIGHT_BUILD_ID) || CYCLONEDDS_INSIGHT_GIT_BRANCH !== branch) {
                            newBuildId = String(latestBuild.id)
                            console.log("New update available, build id:", latestBuild.id)
                            updateAvailable = true
                        }
                    }
                } else {
                    console.log("Error fetching builds: " + xhr.status)
                    updateError = true
                }
            }
            var currentDate = new Date()
            lastUpdateTime = currentDate.toLocaleString()
            updateCheckRunning = false
        }
        xhr.send()
    }
}
