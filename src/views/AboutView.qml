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
import "qrc:/src/views/elements"

Rectangle {
    id: aboutView

    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)
    property var viewHost: null

    color: Constants.mainContentColor(rootWindow.isDarkMode)

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
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                font.bold: true
                font.pixelSize: Constants.pageTitleFontSize
                text: qsTrId("general.about.short")
                wrapMode: Text.WordWrap
            }
            DetachViewButton {
                viewHost: aboutView.viewHost
                visible: viewHost !== null
            }
        }
        ScrollView {
            id: aboutScroll

            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumHeight: 0
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            clip: true
            contentWidth: availableWidth
            objectName: "aboutScroll"

            ColumnLayout {
                spacing: 20
                width: aboutScroll.availableWidth

                GridLayout {
                    id: aboutDetails

                    Layout.fillWidth: true
                    columnSpacing: 28
                    columns: aboutScroll.availableWidth >= 540 ? 2 : 1
                    rowSpacing: 16

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: aboutDetails.columns === 2 ? 150 : 100
                        Layout.preferredWidth: aboutDetails.columns === 2 ? 175 : 100

                        Image {
                            anchors.centerIn: parent
                            fillMode: Image.PreserveAspectFit
                            height: width
                            source: "qrc:/res/images/cyclonedds.png"
                            width: aboutDetails.columns === 2 ? 138 : 90
                        }
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        spacing: 5

                        Label {
                            color: aboutView.secondaryTextColor
                            text: "Eclipse Cyclone DDS™"
                        }
                        Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            font.bold: true
                            font.pixelSize: Constants.pageTitleFontSize
                            text: "CycloneDDS Insight"
                            wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                color: aboutView.secondaryTextColor
                                font.pixelSize: 15
                                text: qsTrId("about.version").arg(CYCLONEDDS_INSIGHT_VERSION)
                                wrapMode: Text.WrapAnywhere
                            }
                            Label {
                                color: aboutView.secondaryTextColor
                                font.pixelSize: 15
                                font.underline: true
                                text: "(" + CYCLONEDDS_INSIGHT_GIT_HASH_SHORT + ")"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: Qt.openUrlExternally("https://github.com/eclipse-cyclonedds/cyclonedds-insight/commit/" + CYCLONEDDS_INSIGHT_GIT_HASH)
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            border.color: Constants.designBorderColor(rootWindow.isDarkMode)
                            border.width: 1
                            color: rootWindow.isDarkMode ? "#292929" : "#f3f3f3"
                            implicitHeight: branchLayout.implicitHeight + 8
                            radius: Constants.controlRadius

                            RowLayout {
                                id: branchLayout

                                anchors.left: parent.left
                                anchors.margins: 4
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: 5

                                Label {
                                    color: aboutView.secondaryTextColor
                                    font.pixelSize: Constants.captionFontSize
                                    text: "Branch"
                                }
                                Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    color: aboutView.secondaryTextColor
                                    font.bold: true
                                    font.pixelSize: Constants.captionFontSize
                                    text: CYCLONEDDS_INSIGHT_GIT_BRANCH.replace("refs/heads/", "")
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                        Item {
                            Layout.preferredHeight: 8
                        }
                        VersionRow {
                            label: "Based on CycloneDDS Python:"
                            url: "https://github.com/eclipse-cyclonedds/cyclonedds-python/commit/" + CYCLONEDDS_PYTHON_GIT_HASH
                            value: CYCLONEDDS_PYTHON_GIT_HASH_SHORT
                        }
                        VersionRow {
                            label: "Based on Cyclone DDS:"
                            url: "https://github.com/eclipse-cyclonedds/cyclonedds/commit/" + CYCLONEDDS_GIT_HASH
                            value: CYCLONEDDS_GIT_HASH_SHORT
                        }
                        VersionRow {
                            label: "Qt runtime:"
                            value: QT_VERSION
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    color: aboutView.secondaryTextColor
                    text: qsTrId("about.contributors")
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    component VersionRow: RowLayout {
        id: versionRow

        property string label: ""
        property string url: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 6

        Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            color: aboutView.secondaryTextColor
            text: versionRow.label
            wrapMode: Text.WordWrap
        }
        Label {
            color: aboutView.secondaryTextColor
            font.underline: versionRow.url.length > 0
            text: versionRow.value

            MouseArea {
                anchors.fill: parent
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: versionRow.url.length > 0

                onClicked: Qt.openUrlExternally(versionRow.url)
            }
        }
    }
}
