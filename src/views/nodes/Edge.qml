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
    id: edgeShape
    // External properties to specify the two items (nodes)
    property Item node1
    property Item node2

    // Optional: color and width customization
    property color edgeColor: rootWindow.isDarkMode ? "white": "black"
    property real edgeWidth: 1

    property real bytesPerSecCalc: 1.0
    property real kbPerSecCalc: 1024
    property real mbPerSecCalc: 1024 * 1024
    property real gbPerSecCalc: 1024 * 1024 * 1024
    property real tbPerSecCalc: 1024 * 1024 * 1024 * 1024
    property real pbPerSecCalc: 1024 * 1024 * 1024 * 1024 * 1024

    property real currentCalc: 1.0

    property real uploadSpeedBytes: 0.0
    property real downloadSpeedBytes: 0.0

    // Fill entire space of parent (you can also position manually if needed)
    anchors.fill: parent
    property string uploadText: ""
    property string downloadText: ""
    property string currentUnit: "B/s"

    property bool speedEnabled: false

    property bool isVertical: Math.abs(dx) < Math.abs(dy)

    property real labelOffset: 8 // distance above/below line

    property real startXPos: node1 ? node1.x + node1.width / 2 : 0
    property real startYPos: node1 ? node1.y + node1.height / 2 : 0
    property real endXPos: node2 ? node2.x + node2.width / 2 : 0
    property real endYPos: node2 ? node2.y + node2.height / 2 : 0

    // Length of the line (to normalize perpendicular offset)
    property real dx: endXPos - startXPos
    property real dy: endYPos - startYPos
    property real len: Math.sqrt(dx*dx + dy*dy) || 1
    property real nx: -dy / len // perpendicular unit vector x
    property real ny: dx / len  // perpendicular unit vector y

    Component.onCompleted: {
        setCurrentUnit(currentUnit);
    }

    ShapePath {
        strokeWidth: edgeWidth
        strokeColor: edgeColor

        // Dynamically bind the center of node1
        startX: node1 ? node1.x + node1.width / 2 : 0
        startY: node1 ? node1.y + node1.height / 2 : 0

        PathLine {
            // Dynamically bind the center of node2
            x: node2 ? node2.x + node2.width / 2 : 0
            y: node2 ? node2.y + node2.height / 2 : 0
        }
    }

    // Upload label ABOVE line
    Label {
        id: uploadLabel
        text: "↑" + (edgeShape.uploadSpeedBytes / edgeShape.currentCalc).toFixed(2) + " " + edgeShape.currentUnit
        font.bold: true
        color: "#419287"
        visible: node1 && node2 && edgeShape.uploadSpeedBytes > 0.00 && edgeShape.speedEnabled

        // midpoint + perpendicular offset up
        x: {
            if (edgeShape.isVertical) {
                return (edgeShape.startXPos + edgeShape.endXPos) / 2 - width / 2
            } else {
                return (edgeShape.startXPos + edgeShape.endXPos) / 2 + edgeShape.nx * edgeShape.labelOffset - width / 2
            }
        }
        y: {
            if (edgeShape.isVertical) {
                return (edgeShape.startYPos + edgeShape.endYPos) / 2 - edgeShape.labelOffset - height / 2
            } else {
                return (edgeShape.startYPos + edgeShape.endYPos) / 2 + edgeShape.ny * edgeShape.labelOffset - height / 2
            }
        }
        rotation: 0 // keep horizontal

        /*Rectangle {
            anchors.fill: parent
            color: rootWindow.isDarkMode ? "#333333cc" : "#f0f0f0cc"
            radius: 4
            z: -1
        }*/
    }

    // Download label BELOW line
    Label {
        id: downloadLabel
        text:  "↓"  + (edgeShape.downloadSpeedBytes / edgeShape.currentCalc).toFixed(2) + " " + edgeShape.currentUnit
        font.bold: true
        color: "#2f62b9"
        visible: node1 && node2 && edgeShape.downloadSpeedBytes > 0.00 && edgeShape.speedEnabled

        // midpoint - perpendicular offset down
        x: {
            if (edgeShape.isVertical) {
                return (edgeShape.startXPos + edgeShape.endXPos) / 2 - width / 2
            } else {
                return (edgeShape.startXPos + edgeShape.endXPos) / 2 - edgeShape.nx * edgeShape.labelOffset - width / 2
            }
        }
        y: {
            if (edgeShape.isVertical) {
                return (edgeShape.startYPos + edgeShape.endYPos) / 2 + edgeShape.labelOffset - height / 2
            } else {
                return (edgeShape.startYPos + edgeShape.endYPos) / 2 - edgeShape.ny * edgeShape.labelOffset - height / 2
            }
        }
        rotation: 0 // keep horizontal

        /*Rectangle {
            anchors.fill: parent
            color: rootWindow.isDarkMode ? "#333333cc" : "#f0f0f0cc"
            radius: 4
            z: -1
        }*/
    }

    function updateDownBps(bps) {
        edgeShape.downloadSpeedBytes = bps;
    }

    function updateUpBps(bps) {
        edgeShape.uploadSpeedBytes = bps;
    }

    function setCurrentUnit(unit) {
        console.log("Setting current unit to: " + unit);
        if (unit === "B/s") {
            edgeShape.currentCalc = edgeShape.bytesPerSecCalc;
        } else if (unit === "KB/s") {
            edgeShape.currentCalc = edgeShape.kbPerSecCalc;
        } else if (unit === "MB/s") {
            edgeShape.currentCalc = edgeShape.mbPerSecCalc;
        } else if (unit === "GB/s") {
            edgeShape.currentCalc = edgeShape.gbPerSecCalc;
        } else if (unit === "TB/s") {
            edgeShape.currentCalc = edgeShape.tbPerSecCalc;
        } else if (unit === "PB/s") {
            edgeShape.currentCalc = edgeShape.pbPerSecCalc;
        } else {
            console.warn("Unknown unit: " + unit);
            return;
        }
        edgeShape.currentUnit = unit;
    }

    function enableSpeeds(enabled) {
        edgeShape.speedEnabled = enabled;
    }
}


