/*
 * Copyright(c) 2026 Sven Trittler
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

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"


Rectangle {
    id: iconActionButton

    property string icon: "play"
    property string tooltipText: ""
    property bool destructive: false
    readonly property color iconColor:
        destructive && mouseArea.containsMouse
        ? Constants.errorColor
        : rootWindow.isDarkMode ? "#e0e0e0" : "#404040"
    signal clicked()

    implicitWidth: 28
    implicitHeight: 28
    radius: Constants.controlRadius
    color: mouseArea.containsMouse
           ? destructive
             ? rootWindow.isDarkMode ? "#4b2528" : "#ffe6e8"
             : rootWindow.isDarkMode ? "#383838" : "#e9e9e9"
           : rootWindow.isDarkMode ? "#292929" : "#f5f5f5"
    border.width: 1
    border.color: mouseArea.containsMouse && destructive
                  ? Constants.errorColor
                  : Constants.borderColor(rootWindow.isDarkMode)

    Behavior on color {
        ColorAnimation {
            duration: 100
        }
    }

    Canvas {
        id: iconCanvas
        anchors.centerIn: parent
        width: 14
        height: 14

        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.fillStyle = iconActionButton.iconColor
            context.strokeStyle = iconActionButton.iconColor
            context.lineWidth = 1.5
            context.lineCap = "round"
            context.lineJoin = "round"

            if (iconActionButton.icon === "play") {
                context.beginPath()
                context.moveTo(4, 2.5)
                context.lineTo(11.5, 7)
                context.lineTo(4, 11.5)
                context.closePath()
                context.fill()
            } else if (iconActionButton.icon === "play-all") {
                context.beginPath()
                context.moveTo(2.5, 3.5)
                context.lineTo(8.5, 7)
                context.lineTo(2.5, 10.5)
                context.closePath()
                context.stroke()

                context.beginPath()
                context.moveTo(5.5, 2.5)
                context.lineTo(11.5, 7)
                context.lineTo(5.5, 11.5)
                context.closePath()
                context.fill()
            } else if (iconActionButton.icon === "stop") {
                context.fillRect(3, 3, 8, 8)
            } else if (iconActionButton.icon === "stop-all") {
                context.fillRect(5, 5, 6.5, 6.5)

                context.beginPath()
                context.rect(3.2, 3.2, 6.5, 6.5)
                context.stroke()
            } else if (iconActionButton.icon === "delete") {
                context.beginPath()
                context.moveTo(3.5, 4.5)
                context.lineTo(4.3, 12)
                context.lineTo(9.7, 12)
                context.lineTo(10.5, 4.5)
                context.stroke()

                context.beginPath()
                context.moveTo(2.5, 3.5)
                context.lineTo(11.5, 3.5)
                context.moveTo(5, 2)
                context.lineTo(9, 2)
                context.stroke()

                context.beginPath()
                context.moveTo(6, 6)
                context.lineTo(6, 10)
                context.moveTo(8, 6)
                context.lineTo(8, 10)
                context.stroke()
            } else if (iconActionButton.icon === "delete-all") {
                context.beginPath()
                context.moveTo(1.8, 5)
                context.lineTo(2.3, 10.5)
                context.lineTo(6.3, 10.5)
                context.moveTo(1.2, 4.2)
                context.lineTo(7, 4.2)
                context.moveTo(3.1, 3)
                context.lineTo(5.4, 3)
                context.stroke()

                context.beginPath()
                context.moveTo(5.5, 5)
                context.lineTo(6.2, 12)
                context.lineTo(11.2, 12)
                context.lineTo(11.9, 5)
                context.stroke()

                context.beginPath()
                context.moveTo(4.7, 4)
                context.lineTo(12.7, 4)
                context.moveTo(7, 2.5)
                context.lineTo(10.5, 2.5)
                context.moveTo(7.7, 6.8)
                context.lineTo(7.7, 10.2)
                context.moveTo(9.7, 6.8)
                context.lineTo(9.7, 10.2)
                context.stroke()
            } else if (iconActionButton.icon === "select-all") {
                context.strokeRect(2.5, 2.5, 9, 9)

                context.beginPath()
                context.moveTo(4.5, 7)
                context.lineTo(6.3, 8.8)
                context.lineTo(9.8, 5)
                context.stroke()
            } else if (iconActionButton.icon === "deselect-all") {
                context.strokeRect(2.5, 2.5, 9, 9)

                context.beginPath()
                context.moveTo(4.5, 7)
                context.lineTo(9.5, 7)
                context.stroke()
            } else if (iconActionButton.icon === "edit") {
                context.beginPath()
                context.moveTo(3, 10.5)
                context.lineTo(4, 7.5)
                context.lineTo(9.5, 2)
                context.lineTo(12, 4.5)
                context.lineTo(6.5, 10)
                context.closePath()
                context.stroke()

                context.beginPath()
                context.moveTo(8.5, 3)
                context.lineTo(11, 5.5)
                context.moveTo(3, 10.5)
                context.lineTo(2.5, 12)
                context.lineTo(4, 11.5)
                context.stroke()
            } else if (iconActionButton.icon === "close") {
                context.beginPath()
                context.moveTo(3, 3)
                context.lineTo(11, 11)
                context.moveTo(11, 3)
                context.lineTo(3, 11)
                context.stroke()
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: iconActionButton.clicked()
        onContainsMouseChanged: iconCanvas.requestPaint()
    }

    ToolTip {
        id: actionTooltip
        parent: iconActionButton
        visible: mouseArea.containsMouse
        delay: 300
        text: iconActionButton.tooltipText

        contentItem: Label {
            text: actionTooltip.text
        }

        background: Rectangle {
            color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
            border.width: 1
            border.color: Constants.borderColor(rootWindow.isDarkMode)
        }
    }

    onIconChanged: iconCanvas.requestPaint()
    onDestructiveChanged: iconCanvas.requestPaint()
    onIconColorChanged: iconCanvas.requestPaint()
}
