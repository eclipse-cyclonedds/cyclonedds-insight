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

    property int aboutWidth: 570
    property int aboutHeight: 230

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
            Layout.preferredWidth: parent.width * 0.30
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
            Layout.preferredWidth: parent.width * 0.70
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

                Row {
                    Label {
                        text: "Version " + CYCLONEDDS_INSIGHT_VERSION + " ("
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: CYCLONEDDS_INSIGHT_GIT_HASH_SHORT
                        font.underline: true
                        font.bold: false
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("https://github.com/eclipse-cyclonedds/cyclonedds-insight/commit/" + CYCLONEDDS_INSIGHT_GIT_HASH)
                        }
                    }
                    Label {
                        text: ")"
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Row {
                    Label {
                        text: "Based on CycloneDDS-Python: "
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: CYCLONEDDS_PYTHON_GIT_HASH_SHORT
                        font.underline: true
                        font.bold: false
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("https://github.com/eclipse-cyclonedds/cyclonedds-python/commit/" + CYCLONEDDS_PYTHON_GIT_HASH)
                        }
                    }
                }
                Row {
                    Label {
                        text: "Based on CycloneDDS: " 
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: CYCLONEDDS_GIT_HASH_SHORT
                        font.underline: true
                        font.bold: false
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("https://github.com/eclipse-cyclonedds/cyclonedds/commit/" + CYCLONEDDS_GIT_HASH)
                        }
                    }
                }
                Label {
                    text: "Thanks to all contributors of the Eclipse Cyclone DDS project ❤️"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
