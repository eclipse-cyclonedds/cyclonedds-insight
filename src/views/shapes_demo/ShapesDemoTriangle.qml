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
    id: triangleItem
    property color color: "blue"
    property string orientation: ""
    property bool isHatch: false
    property color centerColor: "black"
    property real rotation: 0
    property real borderWidth: 1
    property color borderColor: rootWindow.isDarkMode ? "darkgray" : "black"

    onRotationChanged: triangleCanvas.requestPaint()

    Canvas {
        id: triangleCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            ctx.save()

            ctx.translate(width / 2, height / 2)
            ctx.rotate(triangleItem.rotation * Math.PI / 180)

            let triangleWidth = width * shapeDemoViewId.triangleScale
            let triangleHeight = height * shapeDemoViewId.triangleScale

            // Define triangle path
            ctx.beginPath()
            ctx.moveTo(0, -triangleHeight / 2)
            ctx.lineTo(-triangleWidth / 2, triangleHeight / 2)
            ctx.lineTo(triangleWidth / 2, triangleHeight / 2)
            ctx.closePath()

            // Fill the triangle
            ctx.fillStyle = triangleItem.color
            ctx.fill()

            // Draw border
            if (triangleItem.borderWidth > 0) {
                ctx.lineWidth = triangleItem.borderWidth
                ctx.strokeStyle = triangleItem.borderColor
                ctx.stroke()
            }

            if (triangleItem.isHatch) {
                ctx.save()
                ctx.clip()

                const hatchSpacing = 6
                ctx.lineWidth = 1
                ctx.strokeStyle = triangleItem.borderColor

                if (triangleItem.orientation === "horizontal") {
                    for (let y = -triangleHeight / 2 + hatchSpacing / 2; y < triangleHeight / 2; y += hatchSpacing) {
                        ctx.beginPath()
                        ctx.moveTo(-triangleWidth / 2, y)
                        ctx.lineTo(triangleWidth / 2, y)
                        ctx.stroke()
                    }
                } else if (triangleItem.orientation === "vertical") {
                    for (let x = -triangleWidth / 2 + hatchSpacing / 2; x < triangleWidth / 2; x += hatchSpacing) {
                        ctx.beginPath()
                        ctx.moveTo(x, -triangleHeight / 2)
                        ctx.lineTo(x, triangleHeight / 2)
                        ctx.stroke()
                    }
                }

                ctx.restore()
            }

            // Dot in the center
            const radius = triangleHeight / (3 * Math.sqrt(3));
            const centroidY = triangleHeight / 6;
            ctx.beginPath();
            ctx.arc(0, centroidY, radius, 0, 2 * Math.PI);
            ctx.fillStyle = triangleItem.centerColor;
            ctx.fill();

            ctx.restore()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
    }
}
