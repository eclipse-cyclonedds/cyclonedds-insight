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
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent

    property int domainId

    ColumnLayout  {
        anchors.fill: parent
        anchors.margins: 10

        Label {
            text: qsTr("Domain")
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignLeft
            Layout.alignment: Qt.AlignLeft
        }
        Label {
            text: qsTr("Domain ID: ") + domainViewId.domainId
        }

        Rectangle {
            id: root
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeWidth: 2
                    strokeColor: "black"
                    startX: bubble1.x + bubble1.width / 2
                    startY: bubble1.y + bubble1.height / 2

                    PathLine {
                        x: bubble2.x + bubble2.width / 2
                        y: bubble2.y + bubble2.height / 2
                    }
                }
            }

            Bubble {
                id: bubble1
                x: 100
                y: 100
                color: "lightblue"
                text: "Bubble 1"

                border.color: "gray"
                border.width: 1
            }

            Bubble {
                id: bubble2
                x: 400
                y: 200
                text: "Bubble 2"
                color: "lightgreen"
            }

        }

        /*Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }*/
    }
}
