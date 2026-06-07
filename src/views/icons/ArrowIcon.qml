/*
 * Copyright(c) 2024 Sven Trittler
 *
 * SPDX-License-Identifier: EPL-2.0 OR BSD-3-Clause
 */

import QtQuick

Item {
    id: root

    property color iconColor: "grey"
    property real lineWidth: 2.5
    property string direction: "right"

    implicitWidth: 20
    implicitHeight: 20
    rotation: direction === "down" ? 90
              : direction === "left" ? 180
              : direction === "up" ? 270
              : 0

    onIconColorChanged: arrowCanvas.requestPaint()
    onLineWidthChanged: arrowCanvas.requestPaint()

    Canvas {
        id: arrowCanvas
        anchors.fill: parent

        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.strokeStyle = root.iconColor
            context.lineWidth = root.lineWidth
            context.lineCap = "round"
            context.lineJoin = "round"
            context.beginPath()
            context.moveTo(width * 0.14, height * 0.5)
            context.lineTo(width * 0.84, height * 0.5)
            context.moveTo(width * 0.56, height * 0.2)
            context.lineTo(width * 0.86, height * 0.5)
            context.lineTo(width * 0.56, height * 0.8)
            context.stroke()
        }
    }
}
