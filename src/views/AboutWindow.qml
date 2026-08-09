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
import "qrc:/src/views/selection_details"


Window {
    id: aboutWindow

    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)


    property int aboutWidth: 570
    property int aboutHeight: 260

    width: aboutWidth
    height: aboutHeight
    minimumWidth: aboutWidth
    minimumHeight: aboutHeight
    maximumWidth: aboutWidth
    maximumHeight: aboutHeight

    title: qsTrId("about.window.title")
    visible: false
    flags: Qt.Dialog
    modality: Qt.ApplicationModal
    color: Constants.mainContentColor(rootWindow.isDarkMode)

    component VersionRow: RowLayout {
        id: versionRow

        property string label: ""
        property string value: ""
        property string url: ""

        Layout.fillWidth: true
        implicitHeight: 20
        spacing: 6

        Label {
            text: versionRow.label
            color: aboutWindow.secondaryTextColor
        }

        Label {
            text: versionRow.value
            font.underline: versionRow.url.length > 0
            color: aboutWindow.secondaryTextColor

            MouseArea {
                anchors.fill: parent
                enabled: versionRow.url.length > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: Qt.openUrlExternally(versionRow.url)
            }
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
                kind: "about"
            }

            Label {
                text: qsTrId("general.about.short")
                font.pixelSize: Constants.pageTitleFontSize
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 28

            Item {
                Layout.preferredWidth: 175
                Layout.fillHeight: true

                Image {
                    anchors.centerIn: parent
                    width: 138
                    height: 138
                    source: "qrc:/res/images/cyclonedds.png"
                    fillMode: Image.PreserveAspectFit
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 5

                Label {
                    text: "Eclipse Cyclone DDS™"
                    color: aboutWindow.secondaryTextColor
                }

                Label {
                    text: "CycloneDDS Insight"
                    font.pixelSize: Constants.pageTitleFontSize
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Label {
                        text: qsTrId("about.version").arg(CYCLONEDDS_INSIGHT_VERSION)
                        font.pixelSize: 15
                        color: aboutWindow.secondaryTextColor
                    }

                    Label {
                        text: "(" + CYCLONEDDS_INSIGHT_GIT_HASH_SHORT + ")"
                        font.pixelSize: 15
                        font.underline: true
                        color: aboutWindow.secondaryTextColor

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(
                                "https://github.com/eclipse-cyclonedds/cyclonedds-insight/commit/"
                                + CYCLONEDDS_INSIGHT_GIT_HASH)
                        }
                    }
                }

                Item {
                    Layout.preferredHeight: 8
                }

                VersionRow {
                    label: "Based on CycloneDDS Python:"
                    value: CYCLONEDDS_PYTHON_GIT_HASH_SHORT
                    url: "https://github.com/eclipse-cyclonedds/cyclonedds-python/commit/"
                         + CYCLONEDDS_PYTHON_GIT_HASH
                }
                VersionRow {
                    label: "Based on Cyclone DDS:"
                    value: CYCLONEDDS_GIT_HASH_SHORT
                    url: "https://github.com/eclipse-cyclonedds/cyclonedds/commit/"
                         + CYCLONEDDS_GIT_HASH
                }
                VersionRow {
                    label: "Qt runtime:"
                    value: QT_VERSION
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: qsTrId("about.contributors")
                wrapMode: Text.Wrap
                color: aboutWindow.secondaryTextColor
            }

            Button {
                text: qsTrId("general.close")
                onClicked: aboutWindow.close()
            }
        }
    }
}
