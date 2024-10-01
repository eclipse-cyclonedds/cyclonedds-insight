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


Window {
    id: aboutWindow

    property int aboutWidth: 550
    property int aboutHeight: 200

    width: aboutWidth
    height: aboutHeight
    minimumWidth: aboutWidth
    minimumHeight: aboutHeight
    maximumWidth: aboutWidth
    maximumHeight: aboutHeight

    title: "About CycloneDDS Insight"
    visible: false
    flags: Qt.Dialog
    modality: Qt.ApplicationModal

    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

    RowLayout {
        anchors.fill: parent

        Rectangle {
            Layout.preferredWidth: parent.width * 0.33
            Layout.fillHeight: true
            color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

            Image {
                source: "qrc:/res/images/cyclonedds.png"
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                width: parent.width * 0.8
                height: parent.height * 0.8
            }
        }

        Rectangle {
            Layout.preferredWidth: parent.width * 0.67
            Layout.fillHeight: true
            color: rootWindow.isDarkMode ? Constants.darkHeaderBackground : Constants.lightHeaderBackground

            Column {
                anchors.centerIn: parent
                spacing: 10

                Label {
                    text: "Eclipse Cyclone DDS™"
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    text: "CycloneDDS Insight"
                    font.pixelSize: 25
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    text: "Version: " + CYCLONEDDS_INSIGHT_VERSION + " (" + CYCLONEDDS_INSIGHT_GIT_HASH_SHORT + "-" +  CYCLONEDDS_INSIGHT_GIT_BRANCH + ")"
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    text: "Thanks to all contributors of the Eclipse Cyclone DDS project ❤️"
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
