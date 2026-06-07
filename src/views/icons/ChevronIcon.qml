/*
 * Copyright(c) 2024 Sven Trittler
 *
 * SPDX-License-Identifier: EPL-2.0 OR BSD-3-Clause
 */

import QtQuick

Item {
    id: root

    property color iconColor: "grey"
    property real lineWidth: 1.5

    implicitWidth: 16
    implicitHeight: 16

    onIconColorChanged: chevronCanvas.requestPaint()
    onLineWidthChanged: chevronCanvas.requestPaint()

    Canvas {
        id: chevronCanvas
        anchors.fill: parent

        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.beginPath()
            context.moveTo(width * 0.22, height * 0.38)
            context.lineTo(width * 0.5, height * 0.66)
            context.lineTo(width * 0.78, height * 0.38)
            context.lineWidth = root.lineWidth
            context.lineCap = "round"
            context.lineJoin = "round"
            context.strokeStyle = root.iconColor
            context.stroke()
        }
    }
}
