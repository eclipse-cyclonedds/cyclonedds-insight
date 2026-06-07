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
    property real lineWidth: 1.5

    implicitWidth: 16
    implicitHeight: 16

    onIconColorChanged: menuCanvas.requestPaint()
    onLineWidthChanged: menuCanvas.requestPaint()

    Canvas {
        id: menuCanvas
        anchors.fill: parent

        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.strokeStyle = root.iconColor
            context.lineWidth = root.lineWidth
            context.lineCap = "round"

            for (let row = 0; row < 3; ++row) {
                const y = height * (0.3 + row * 0.2)
                context.beginPath()
                context.moveTo(width * 0.2, y)
                context.lineTo(width * 0.8, y)
                context.stroke()
            }
        }
    }
}
