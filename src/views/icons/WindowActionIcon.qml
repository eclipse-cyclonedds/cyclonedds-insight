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
    property bool dock: false
    implicitWidth: 22
    implicitHeight: 22

    onIconColorChanged: iconCanvas.requestPaint()
    onDockChanged: iconCanvas.requestPaint()

    Canvas {
        id: iconCanvas
        anchors.fill: parent

        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.strokeStyle = root.iconColor
            context.lineWidth = 1.7
            context.lineCap = "round"
            context.lineJoin = "round"
            context.beginPath()
            context.moveTo(width * 0.45, height * 0.23)
            context.lineTo(width * 0.18, height * 0.23)
            context.lineTo(width * 0.18, height * 0.82)
            context.lineTo(width * 0.77, height * 0.82)
            context.lineTo(width * 0.77, height * 0.55)
            context.moveTo(width * 0.45, height * 0.55)
            context.lineTo(width * 0.82, height * 0.18)
            if (root.dock) {
                context.moveTo(width * 0.45, height * 0.30)
                context.lineTo(width * 0.45, height * 0.55)
                context.lineTo(width * 0.70, height * 0.55)
            } else {
                context.moveTo(width * 0.57, height * 0.18)
                context.lineTo(width * 0.82, height * 0.18)
                context.lineTo(width * 0.82, height * 0.43)
            }
            context.stroke()
        }
    }
}
