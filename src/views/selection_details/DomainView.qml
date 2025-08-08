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
import "qrc:/src/views/nodes"


Rectangle {
    id: domainViewId
    anchors.fill: parent
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent

    property int domainId
    property var nodesMap
    property var edges: []
    property var velocities: ({})
    property var hostsMap: ({})   // hostName -> [bubbles]

    Component.onCompleted: {
        nodesMap = {};
        edges = [];
        velocities = {};
        hostsMap = {};
        graphModel.setDomainId(domainId);
    }

    GraphModel { id: graphModel }

    Connections {
        target: graphModel

        function onNewNodeSignal(name, edgeName, hostName) {
            var nodeComponent = Qt.createComponent("qrc:/src/views/nodes/Bubble.qml");
            if (nodeComponent.status !== Component.Ready) {
                console.error("Failed to load Bubble.qml:", nodeComponent.errorString());
                return;
            }

            var randomX = Math.random() * root.width;
            var randomY = Math.random() * root.height;

            var nodeInstance = nodeComponent.createObject(root, {
                x: randomX,
                y: randomY,
                text: name,
                color: "lightblue",
                nodeName: name,
                hostName: hostName
            });

            nodesMap[name] = nodeInstance;
            velocities[name] = { vx: 0, vy: 0 };

            if (!hostsMap[hostName])
                hostsMap[hostName] = [];
            hostsMap[hostName].push(nodeInstance);

            if (edgeName && nodesMap[edgeName]) {
                var edgeComponent = Qt.createComponent("qrc:/src/views/nodes/Edge.qml");
                if (edgeComponent.status !== Component.Ready) {
                    console.error("Failed to load Edge.qml:", edgeComponent.errorString());
                    return;
                }
                var edgeInstance = edgeComponent.createObject(root, {
                    bubble1: nodesMap[edgeName],
                    bubble2: nodeInstance,
                    z: -1
                });
                nodesMap[name + edgeName] = edgeInstance;

                edges.push({
                    source: nodesMap[edgeName],
                    target: nodeInstance
                });
            }
        }

        function onRemoveNodeSignal(name, edgeName) {
            var hostName = nodesMap[name] ? nodesMap[name].hostName : null;

            if (nodesMap[name]) {
                nodesMap[name].destroy();
                delete nodesMap[name];
                delete velocities[name];
            }
            if (edgeName && nodesMap[name + edgeName]) {
                nodesMap[name + edgeName].destroy();
                delete nodesMap[name + edgeName];
            }
            edges = edges.filter(function(e) {
                return e.source.nodeName !== name && e.target.nodeName !== name;
            });

            if (hostName && hostsMap[hostName]) {
                hostsMap[hostName] = hostsMap[hostName].filter(function(n) {
                    return n.nodeName !== name;
                });
                if (hostsMap[hostName].length === 0)
                    delete hostsMap[hostName];
            }
        }
    }

    // Physics Timer
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            var nodeList = Object.values(nodesMap);
            var idealLength = 150;

            for (var i = 0; i < nodeList.length; i++) {
                var b1 = nodeList[i];
                var nodeName = b1.nodeName;
                if (!velocities[nodeName])
                    velocities[nodeName] = { vx: 0, vy: 0 };
                var vel = velocities[nodeName];

                var fx = 0, fy = 0;

                // REPULSION
                for (var j = 0; j < nodeList.length; j++) {
                    if (i === j) continue;
                    var b2 = nodeList[j];
                    var dx = b1.x - b2.x;
                    var dy = b1.y - b2.y;
                    var distSq = dx*dx + dy*dy + 0.01;
                    var dist = Math.sqrt(distSq);
                    if (dist > 0) {
                        var force = 2000 / distSq;
                        fx += (dx / dist) * force;
                        fy += (dy / dist) * force;
                    }
                }

                // EDGE SPRING
                for (var e = 0; e < edges.length; e++) {
                    var edge = edges[e];
                    if (edge.source === b1 || edge.target === b1) {
                        var other = (edge.source === b1) ? edge.target : edge.source;
                        var dx2 = other.x - b1.x;
                        var dy2 = other.y - b1.y;
                        var dist2 = Math.sqrt(dx2 * dx2 + dy2 * dy2) || 0.01;
                        var displacement = dist2 - idealLength;
                        fx += (dx2 / dist2) * displacement * 0.02;
                        fy += (dy2 / dist2) * displacement * 0.02;
                    }
                }

                // HOST GROUP ATTRACTION
                for (var h in hostsMap) {
                    if (b1.hostName === h) {
                        var group = hostsMap[h];
                        for (var g = 0; g < group.length; g++) {
                            var b2g = group[g];
                            if (b2g === b1) continue;
                            var dxh = b2g.x - b1.x;
                            var dyh = b2g.y - b1.y;
                            var distH = Math.sqrt(dxh * dxh + dyh * dyh) || 0.01;
                            var hostIdeal = 100;
                            var displacementH = distH - hostIdeal;
                            fx += (dxh / distH) * displacementH * 0.01;
                            fy += (dyh / distH) * displacementH * 0.01;
                        }
                    }
                }

                // Update velocity & position
                vel.vx += fx * 0.05;
                vel.vy += fy * 0.05;
                vel.vx *= 0.85;
                vel.vy *= 0.85;

                b1.x += vel.vx;
                b1.y += vel.vy;

                b1.x = Math.max(0, Math.min(root.width - b1.width, b1.x));
                b1.y = Math.max(0, Math.min(root.height - b1.height, b1.y));
            }
        }
    }

    // Host background canvas
    Canvas {
        id: hostBackground
        anchors.fill: parent
        z: 0
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            function drawRoundedRect(x, y, w, h, r) {
                ctx.beginPath();
                ctx.moveTo(x + r, y);
                ctx.lineTo(x + w - r, y);
                ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                ctx.lineTo(x + w, y + h - r);
                ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                ctx.lineTo(x + r, y + h);
                ctx.quadraticCurveTo(x, y + h, x, y + h - r);
                ctx.lineTo(x, y + r);
                ctx.quadraticCurveTo(x, y, x + r, y);
                ctx.closePath();
            }

            var hostNames = Object.keys(hostsMap);
            for (var hIndex = 0; hIndex < hostNames.length; hIndex++) {
                var h = hostNames[hIndex];
                var group = hostsMap[h];
                if (group.length === 0) continue;

                var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
                for (var i = 0; i < group.length; i++) {
                    var n = group[i];
                    minX = Math.min(minX, n.x);
                    minY = Math.min(minY, n.y);
                    maxX = Math.max(maxX, n.x + n.width);
                    maxY = Math.max(maxY, n.y + n.height);
                }

                var pad = 20;
                var hue = (hIndex * 77) % 360;
                ctx.fillStyle = "hsl(" + hue + ", 70%, 60%)";
                ctx.globalAlpha = 0.15;
                drawRoundedRect(minX - pad, minY - pad, (maxX - minX) + pad*2, (maxY - minY) + pad*2, 15);
                ctx.fill();

                // Draw hostname text
                ctx.globalAlpha = 1.0;
                ctx.fillStyle = rootWindow.isDarkMode ? "#FFFFFF" : "#000000";
                ctx.font = "bold 14px sans-serif";
                ctx.fillText(h, minX - pad + 5, minY - pad - 5);
            }
        }
    }

    Timer {
        interval: 33
        running: true
        repeat: true
        onTriggered: hostBackground.requestPaint()
    }

    // Root area for bubbles and edges
    Item {
        id: root
        anchors.fill: parent
        z: 1
    }
}
