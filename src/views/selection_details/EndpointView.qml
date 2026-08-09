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
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"


Rectangle {
    id: endpointViewId
    color: Constants.mainContentColor(rootWindow.isDarkMode)

    property int domainId
    property string endpointKey

    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                DetailBadge {
                    kind: "endpoint"
                }

                Label {
                    text: qsTrId("entity.endpoint")
                    font.pixelSize: Constants.pageTitleFontSize
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                spacing: 8

                Label {
                    text: qsTrId("entity.domain.id.label")
                    color: endpointViewId.secondaryTextColor
                }

                Label {
                    text: endpointViewId.domainId
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                spacing: 8

                Label {
                    text: qsTrId("entity.endpoint.key.label")
                    color: endpointViewId.secondaryTextColor
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 17
                    text: endpointViewId.endpointKey
                    color: rootWindow.isDarkMode ? "#e0e0e0" : "#303030"
                    minimumPixelSize: 8
                    fontSizeMode: Text.HorizontalFit
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
