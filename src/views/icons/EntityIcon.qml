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

Canvas {
    id: root

    // Supported symbols: layers, participant, topic.
    property string symbol: "layers"
    property color iconColor: "grey"
    property real lineWidth: 1.6

    implicitWidth: 18
    implicitHeight: 18
    onSymbolChanged: requestPaint()
    onIconColorChanged: requestPaint()
    onLineWidthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        ctx.scale(width / 18, height / 18)
        ctx.strokeStyle = root.iconColor
        ctx.lineWidth = root.lineWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()

        if (root.symbol === "participant") {
            ctx.arc(9, 5, 2.7, 0, Math.PI * 2)
            ctx.moveTo(3, 15.5)
            ctx.bezierCurveTo(3, 8.4, 15, 8.4, 15, 15.5)
            ctx.closePath()
        } else if (root.symbol === "topic") {
            ctx.moveTo(5, 5)
            ctx.lineTo(9, 9)
            ctx.lineTo(13, 5)
            ctx.moveTo(9, 9)
            ctx.lineTo(9, 13)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(3.5, 3.5, 2, 0, Math.PI * 2)
            ctx.moveTo(16.5, 3.5)
            ctx.arc(14.5, 3.5, 2, 0, Math.PI * 2)
            ctx.moveTo(11, 15)
            ctx.arc(9, 15, 2, 0, Math.PI * 2)
        } else {
            ctx.moveTo(2, 5)
            ctx.lineTo(9, 1.8)
            ctx.lineTo(16, 5)
            ctx.lineTo(9, 8.2)
            ctx.closePath()
            ctx.moveTo(2, 9)
            ctx.lineTo(9, 12.2)
            ctx.lineTo(16, 9)
            ctx.moveTo(2, 13)
            ctx.lineTo(9, 16.2)
            ctx.lineTo(16, 13)
        }
        ctx.stroke()
    }
}
