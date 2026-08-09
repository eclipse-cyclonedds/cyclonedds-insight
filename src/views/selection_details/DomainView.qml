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
import QtQuick.Shapes

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"
import "qrc:/src/views/nodes"


Rectangle {
    id: domainViewId
    color: Constants.mainContentColor(rootWindow.isDarkMode)

    property int domainId

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
                    kind: "domain"
                }

                Label {
                    text: qsTrId("entity.domain")
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
                    color: domainViewId.secondaryTextColor
                }

                Label {
                    text: domainViewId.domainId
                    font.bold: true
                }
            }
        }

        NodeView {
            id: nodeViewId
            domainId: domainViewId.domainId
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    function aboutToClose() {
        console.log("DomainView: about to close.")
        nodeViewId.aboutToClose()
    }
}
