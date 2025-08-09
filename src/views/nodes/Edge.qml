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
import QtQuick.Shapes

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"

Shape {
    // External properties to specify the two items (bubbles)
    property Item bubble1
    property Item bubble2

    // Optional: color and width customization
    property color edgeColor: rootWindow.isDarkMode ? "white": "black"
    property real edgeWidth: 1

    // Fill entire space of parent (you can also position manually if needed)
    anchors.fill: parent

    ShapePath {
        strokeWidth: edgeWidth
        strokeColor: edgeColor

        // Dynamically bind the center of bubble1
        startX: bubble1 ? bubble1.x + bubble1.width / 2 : 0
        startY: bubble1 ? bubble1.y + bubble1.height / 2 : 0

        PathLine {
            // Dynamically bind the center of bubble2
            x: bubble2 ? bubble2.x + bubble2.width / 2 : 0
            y: bubble2 ? bubble2.y + bubble2.height / 2 : 0
        }
    }
}


