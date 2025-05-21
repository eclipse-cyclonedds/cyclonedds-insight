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
    id: rectangleItem
    width: 50
    height: 50

    property color color: "blue"
    property color centerColor: "black"
    property bool isHatch: false
    property string orientation: ""
    property int spacing: 7
    property color borderColor: rootWindow.isDarkMode ? "darkgray" : "black"
    property bool isCircle: false
    property bool isForeground: true

    z: isForeground ? 1 : 0

    Canvas {
        id: rectangleCanvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            const radius = rectangleItem.isCircle ? width / 2 : 0;

            // Draw shape (rectangle or circle)
            ctx.beginPath();
            if (rectangleItem.isCircle) {
                ctx.arc(width / 2, height / 2, radius, 0, 2 * Math.PI);
            } else {
                ctx.rect(0, 0, width, height);
            }

            ctx.fillStyle = rectangleItem.color;
            ctx.fill();

            // Border
            ctx.lineWidth = 1;
            ctx.strokeStyle = rectangleItem.borderColor;
            ctx.stroke();

            // Hatches
            if (rectangleItem.isHatch) {
                ctx.save();
                ctx.clip(); // Restrict hatches to the shape

                ctx.beginPath();
                ctx.lineWidth = 1;
                ctx.strokeStyle = rectangleItem.borderColor;

                if (rectangleItem.orientation === "horizontal") {
                    for (let y = rectangleItem.spacing / 2; y < height; y += rectangleItem.spacing) {
                        ctx.moveTo(0, y);
                        ctx.lineTo(width, y);
                    }
                } else if (rectangleItem.orientation === "vertical") {
                    for (let x = rectangleItem.spacing / 2; x < width; x += rectangleItem.spacing) {
                        ctx.moveTo(x, 0);
                        ctx.lineTo(x, height);
                    }
                }

                ctx.stroke();
                ctx.restore();
            }

            // Draw inner rectangle (half size)
            const innerWidth = width / 3;
            const innerHeight = height / 3;
            const innerX = (width - innerWidth) / 2;
            const innerY = (height - innerHeight) / 2;

            ctx.beginPath();
            ctx.rect(innerX, innerY, innerWidth, innerHeight);
            ctx.fillStyle = rectangleItem.centerColor;  // reusing this property
            ctx.fill();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()
    }
}
