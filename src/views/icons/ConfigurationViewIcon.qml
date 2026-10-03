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

    property int mode: 0
    property color iconColor: "grey"
    property real lineWidth: 1.5

    implicitWidth: 18
    implicitHeight: 18
    onModeChanged: requestPaint()
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

        if (root.mode === 0) {
            // XML brackets identify the editor.
            ctx.moveTo(5.5, 4.5)
            ctx.lineTo(1.5, 9)
            ctx.lineTo(5.5, 13.5)
            ctx.moveTo(12.5, 4.5)
            ctx.lineTo(16.5, 9)
            ctx.lineTo(12.5, 13.5)
            ctx.moveTo(10.5, 3.5)
            ctx.lineTo(7.5, 14.5)
        } else if (root.mode === 1) {
            // Two panes identify the side-by-side view.
            ctx.rect(2, 3, 14, 12)
            ctx.moveTo(9, 3)
            ctx.lineTo(9, 15)
        } else {
            // A page with text identifies the documentation.
            ctx.rect(4, 2, 10, 14)
            ctx.moveTo(6.5, 6)
            ctx.lineTo(11.5, 6)
            ctx.moveTo(6.5, 9)
            ctx.lineTo(11.5, 9)
            ctx.moveTo(6.5, 12)
            ctx.lineTo(10, 12)
        }
        ctx.stroke()
    }
}
