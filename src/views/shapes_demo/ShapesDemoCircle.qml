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
import QtQuick.Dialogs

import org.eclipse.cyclonedds.insight


Item {
    id: root
    property real rotation: 0
    property color color: "lightgray"
    property string orientation: ""
    property bool isHatch: false
    property int hatchSpacing: 7
    property int lineWidth: 2
    property real borderWidth: 1
    property color borderColor: rootWindow.isDarkMode ? "darkgray" : "black"

    Canvas {
        id: canvas
        anchors.fill: parent

        transform: Rotation {
            origin.x: canvas.width / 2
            origin.y: canvas.height / 2
            angle: root.rotation
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const centerX = width / 2
            const centerY = height / 2
            const radius = width / 2

            // Clip to circle
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
            ctx.clip()

            // Fill circle background
            ctx.fillStyle = root.color
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
            ctx.fill()

            // Draw vertical hatches inside clipped circle
            if (root.isHatch && root.orientation === "vertical") {
                ctx.strokeStyle = root.borderColor
                ctx.lineWidth = root.lineWidth
                for (let x = 0; x <= width; x += root.hatchSpacing) {
                    ctx.beginPath()
                    ctx.moveTo(x, 0)
                    ctx.lineTo(x, height)
                    ctx.stroke()
                }
            }
            if (root.isHatch && root.orientation === "horizontal") {
                ctx.strokeStyle = root.borderColor
                ctx.lineWidth = root.lineWidth
                for (let y = 0; y <= height; y += root.hatchSpacing) {
                    ctx.beginPath()
                    ctx.moveTo(0, y)
                    ctx.lineTo(width, y)
                    ctx.stroke()
                }
            }


            // Draw border
            ctx.strokeStyle = root.borderColor
            ctx.lineWidth = root.borderWidth
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius - root.borderWidth / 2, 0, 2 * Math.PI)
            ctx.stroke()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
    }
}
