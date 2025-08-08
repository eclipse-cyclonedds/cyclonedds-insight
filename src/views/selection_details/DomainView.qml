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
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent

    property int domainId
    property var nodesMap
    property var edges: []              // store edges for attraction
    property var velocities: ({})       // store velocity per node { name: { vx, vy } }

    Component.onCompleted: {
        nodesMap = {};
        edges = [];
        velocities = {};
        graphModel.setDomainId(domainId);
    }

    GraphModel { id: graphModel }

    Connections {
        target: graphModel

        function onNewNodeSignal(name, edgeName) {
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
                nodeName: name // store name for physics mapping
            });

            nodesMap[name] = nodeInstance;
            velocities[name] = { vx: 0, vy: 0 }; // init velocity

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

                // Add to physics edge list
                edges.push({
                    source: nodesMap[edgeName],
                    target: nodeInstance
                });
            }
        }

        function onRemoveNodeSignal(name, edgeName) {
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
        }
    }

    // =========================
    // Physics Simulation (Velocity-based + ideal spring length)
    // =========================
    Timer {
        interval: 16 // ~60fps
        running: true
        repeat: true
        onTriggered: {
            var nodeList = Object.values(nodesMap);
            var idealLength = 25; // desired distance between connected nodes

            for (var i = 0; i < nodeList.length; i++) {
                var b1 = nodeList[i];
                var nodeName = b1.nodeName;

                // Make sure velocity exists
                if (!velocities[nodeName]) {
                    velocities[nodeName] = { vx: 0, vy: 0 };
                }
                var vel = velocities[nodeName];

                var fx = 0, fy = 0;

                // REPULSION between all nodes
                for (var j = 0; j < nodeList.length; j++) {
                    if (i === j) continue;
                    var b2 = nodeList[j];
                    var dx = b1.x - b2.x;
                    var dy = b1.y - b2.y;
                    var distSq = dx*dx + dy*dy + 0.01;
                    var dist = Math.sqrt(distSq);
                    if (dist > 0) {
                        var force = 2000 / distSq; // tweak for spacing
                        fx += (dx / dist) * force;
                        fy += (dy / dist) * force;
                    }
                }

                // ATTRACTION for edges (spring with ideal length)
                for (var e = 0; e < edges.length; e++) {
                    var edge = edges[e];
                    if (edge.source === b1 || edge.target === b1) {
                        var other = (edge.source === b1) ? edge.target : edge.source;
                        var dx2 = other.x - b1.x;
                        var dy2 = other.y - b1.y;
                        var dist2 = Math.sqrt(dx2 * dx2 + dy2 * dy2) || 0.01;

                        var displacement = dist2 - idealLength;
                        fx += (dx2 / dist2) * displacement * 0.02; // 0.02 = spring stiffness
                        fy += (dy2 / dist2) * displacement * 0.02;
                    }
                }

                // === Velocity update ===
                vel.vx += fx * 0.05;  // acceleration factor
                vel.vy += fy * 0.05;

                // Damping for smooth stop
                vel.vx *= 0.85;
                vel.vy *= 0.85;

                // Apply velocity
                b1.x += vel.vx;
                b1.y += vel.vy;

                // Keep inside bounds
                b1.x = Math.max(0, Math.min(root.width, b1.x));
                b1.y = Math.max(0, Math.min(root.height, b1.y));
            }
        }
    }

    ColumnLayout  {
        anchors.fill: parent
        anchors.margins: 10

        Label {
            text: qsTr("Domain")
            font.pixelSize: 18
            font.bold: true
        }
        Label {
            text: qsTr("Domain ID: ") + domainViewId.domainId
        }

        Rectangle {
            id: root
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
        }
    }
}

