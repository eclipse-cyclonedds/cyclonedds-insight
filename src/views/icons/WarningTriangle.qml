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

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"

Item {
    id: warning_triangle
    width: 15
    height: 15
    property bool showTooltip: false
    property bool enableTooltip: false
    property string tooltipText: ""

    Canvas {
        id: triangle
        width: parent.width
        height: parent.height
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // Draw the border
            ctx.beginPath();
            ctx.moveTo(width / 2, 0);
            ctx.lineTo(0, height);
            ctx.lineTo(width, height);
            ctx.closePath();
            ctx.lineWidth = 1;
            ctx.strokeStyle = "black";
            ctx.stroke();

            // Draw the filled triangle
            ctx.beginPath();
            ctx.moveTo(width / 2, 1);
            ctx.lineTo(1, height - 1);
            ctx.lineTo(width - 1, height - 1);
            ctx.closePath();
            ctx.fillStyle = "#f4b83f";
            ctx.fill();
        }
    }

    Text {
        text: "!"
        anchors.centerIn: parent
        font.bold: true
        font.pixelSize: warning_triangle.height * 0.8
        color: "black"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        anchors.horizontalCenterOffset: -0.5
        anchors.verticalCenterOffset: 1
    }


    MouseArea {
        id: mouseAreaWarningTriangle
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            warning_triangle.showTooltip = true
        }
        onExited: {
            warning_triangle.showTooltip = false
        }
    }
    ToolTip {
        id: warningTriangleTooltip
        parent: warning_triangle
        visible: warning_triangle.showTooltip && warning_triangle.enableTooltip
        delay: 200
        contentItem: Label {
            text: warning_triangle.tooltipText
        }
        background: Rectangle {
            border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
            border.width: 1
            color: rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor
        }
    }

}