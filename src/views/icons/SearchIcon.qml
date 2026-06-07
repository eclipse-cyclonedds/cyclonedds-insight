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

Item {
    id: root

    property color iconColor: "grey"
    property real lineWidth: 1.8
    property bool expanded: false

    implicitWidth: 24
    implicitHeight: 18

    onIconColorChanged: searchCanvas.requestPaint()
    onLineWidthChanged: searchCanvas.requestPaint()

    Canvas {
        id: searchCanvas
        width: 17
        height: 17
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        onPaint: {
            const context = getContext("2d")
            const size = Math.min(width, height)
            const radius = size * 0.25
            const centerX = width * 0.4
            const centerY = height * 0.4
            const handleStart = radius * 0.74

            context.clearRect(0, 0, width, height)
            context.strokeStyle = root.iconColor
            context.lineWidth = root.lineWidth
            context.lineCap = "round"
            context.lineJoin = "round"
            context.beginPath()
            context.arc(centerX, centerY, radius, 0, Math.PI * 2)
            context.moveTo(centerX + handleStart, centerY + handleStart)
            context.lineTo(width * 0.79, height * 0.79)
            context.stroke()
        }
    }

    ChevronIcon {
        width: 9
        height: 9
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconColor: root.iconColor
        lineWidth: 1.7
        rotation: root.expanded ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }
}
