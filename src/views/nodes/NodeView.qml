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
    id: nodeViewId
    anchors.fill: parent
    color: "transparent"

    property int domainId
    property var nodesMap
    property var edges: []            // array of { source: Item, target: Item }
    property var edgesMap: ({})       // map edgeId -> edgeItem (for quick duplicate-check + removal)
    property var velocities: ({})
    property var hostsMap: ({})       // hostName -> [bubbles]
    property int idealLength: 110
    property var hostColors: ({}) 

    Component.onCompleted: {
        nodesMap = {};
        edges = [];
        edgesMap = {};
        velocities = {};
        hostsMap = {};
        graphModel.setDomainId(domainId);
    }

    GraphModel {
        id: graphModel
    }

    Connections {
        target: graphModel

        /*
         * onNewNodeSignal(name, edgeName, hostName)
         * - If node already exists: reuse it (don't recreate)
         * - If hostName provided and node wasn't in that host: add to hostsMap
         * - If edgeName exists (other node exists), create an edge only if not already present
         */
        function onNewNodeSignal(name, edgeName, hostName) {
            // ensure maps are initialized
            if (!nodesMap) nodesMap = {};
            if (!hostsMap) hostsMap = {};
            if (!velocities) velocities = {};
            if (!edges) edges = [];
            if (!edgesMap) edgesMap = {};

            var nodeInstance;

            if (nodesMap[name]) {
                // reuse existing node
                nodeInstance = nodesMap[name];

                // update host membership if a non-empty hostName is given
                if (hostName && hostName !== "") {
                    // if the node had a different host before, remove from that host list
                    var prevHost = (typeof nodeInstance.hostName !== "undefined") ? nodeInstance.hostName : "";
                    if (prevHost !== hostName) {
                        if (prevHost && hostsMap[prevHost]) {
                            hostsMap[prevHost] = hostsMap[prevHost].filter(function(n) { return n.nodeName !== name; });
                            if (hostsMap[prevHost].length === 0)
                                delete hostsMap[prevHost];
                        }
                        // register under new host
                        if (!hostsMap[hostName]) hostsMap[hostName] = [];
                        // avoid duplicate entries
                        var already = false;
                        for (var i = 0; i < hostsMap[hostName].length; ++i) {
                            if (hostsMap[hostName][i].nodeName === name) { already = true; break; }
                        }
                        if (!already) hostsMap[hostName].push(nodeInstance);
                        nodeInstance.hostName = hostName;
                    }
                }
            } else {
                // create new node
                var nodeComponent = Qt.createComponent("qrc:/src/views/nodes/Bubble.qml");
                if (nodeComponent.status !== Component.Ready) {
                    console.error("Failed to load Bubble.qml:", nodeComponent.errorString());
                    return;
                }

                var randomX = Math.random() * root.width;
                var randomY = Math.random() * root.height;
                var bubbleColor = (hostName && hostName !== "") ? "#5E92F3" : "#29B6F6";

                nodeInstance = nodeComponent.createObject(root, {
                    x: randomX,
                    y: randomY,
                    text: name,
                    color: bubbleColor,
                    nodeName: name,
                    hostName: hostName || ""
                });

                if (!nodeInstance) {
                    console.error("Failed to instantiate Bubble.qml for", name);
                    return;
                }

                nodesMap[name] = nodeInstance;
                if (!velocities[name]) velocities[name] = { vx: 0, vy: 0 };

                // add to hostsMap (if host is non-empty)
                if (hostName && hostName !== "") {
                    if (!hostsMap[hostName]) hostsMap[hostName] = [];
                    hostsMap[hostName].push(nodeInstance);
                }
            }

            // If edgeName is provided and that node exists, create edge (but don't duplicate)
            if (edgeName) {
                if (!nodesMap[edgeName]) {
                    // other node isn't present yet — skip edge creation.
                    // This is intentional: only create edges when both endpoints exist.
                } else {
                    var a = name;
                    var b = edgeName;
                    var edgeId = (a < b) ? (a + "::" + b) : (b + "::" + a);

                    if (!edgesMap[edgeId]) {
                        var edgeComponent = Qt.createComponent("qrc:/src/views/nodes/Edge.qml");
                        if (edgeComponent.status !== Component.Ready) {
                            console.error("Failed to load Edge.qml:", edgeComponent.errorString());
                            return;
                        }

                        // create the Edge visual
                        var edgeInstance = edgeComponent.createObject(root, {
                            bubble1: nodesMap[edgeName],
                            bubble2: nodeInstance,
                            z: -1
                        });
                        if (!edgeInstance) {
                            console.error("Failed to instantiate Edge.qml for", edgeId);
                            return;
                        }

                        edges.push({
                            source: nodesMap[edgeName],
                            target: nodeInstance
                        });
                        edgesMap[edgeId] = edgeInstance;
                    }
                }
            }
        }

        /*
         * onRemoveNodeSignal(name, edgeName)
         * - destroys node and all edges attached to it
         * - cleans up hostsMap and velocities
         */
        function onRemoveNodeSignal(name, edgeName) {
            var hostName = nodesMap[name] ? nodesMap[name].hostName : null;

            // destroy the node
            if (nodesMap[name]) {
                try { nodesMap[name].destroy(); } catch (e) { /* ignore */ }
                delete nodesMap[name];
            }
            if (velocities && velocities[name]) delete velocities[name];

            // remove/destroy any edges that include this node (both from edges array and edgesMap)
            // edgesMap keys are "a::b"
            for (var id in edgesMap) {
                if (!edgesMap.hasOwnProperty(id)) continue;
                var parts = id.split("::");
                if (parts.length !== 2) continue;
                if (parts[0] === name || parts[1] === name) {
                    try { edgesMap[id].destroy(); } catch (e) { /* ignore */ }
                    delete edgesMap[id];
                }
            }
            edges = edges.filter(function(e) {
                return (e.source && e.source.nodeName !== name) && (e.target && e.target.nodeName !== name);
            });

            // clean up hosts map
            if (hostName && hostsMap[hostName]) {
                hostsMap[hostName] = hostsMap[hostName].filter(function(n) {
                    return n.nodeName !== name;
                });
                if (hostsMap[hostName].length === 0)
                    delete hostsMap[hostName];
            }

            // Also be safe: remove this node from all host lists (in case hostName was empty or unknown)
            for (var h in hostsMap) {
                if (!hostsMap.hasOwnProperty(h)) continue;
                hostsMap[h] = hostsMap[h].filter(function(n) { return n.nodeName !== name; });
                if (hostsMap[h].length === 0) delete hostsMap[h];
            }
        }
    }

    function calculatePhysics() {
        var nodeList = Object.values(nodesMap);

        for (var i = 0; i < nodeList.length; i++) {
            var b1 = nodeList[i];
            var nodeName = b1.nodeName;
            if (!velocities[nodeName])
                velocities[nodeName] = { vx: 0, vy: 0 };
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
                    var displacement = dist2 - nodeViewId.idealLength;
                    fx += (dx2 / dist2) * displacement * 0.02;
                    fy += (dy2 / dist2) * displacement * 0.02;
                }
            }

            // HOST GROUP ATTRACTION (only for non-empty host names)
            if (b1.hostName && b1.hostName !== "") {
                var group = hostsMap[b1.hostName];
                if (group) {
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

    // Host background canvas (renders grouped rounded rects and hostname labels)
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
                if (h === "") continue; // skip rendering for empty hostname

                var group = hostsMap[h];
                if (!group || group.length === 0) continue;

                var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
                for (var i = 0; i < group.length; i++) {
                    var n = group[i];
                    minX = Math.min(minX, n.x);
                    minY = Math.min(minY, n.y);
                    maxX = Math.max(maxX, n.x + n.width);
                    maxY = Math.max(maxY, n.y + n.height);
                }

                function hsvToRgb(h, s, v) {
                    var r, g, b;

                    var i = Math.floor(h * 6);
                    var f = h * 6 - i;
                    var p = v * (1 - s);
                    var q = v * (1 - f * s);
                    var t = v * (1 - (1 - f) * s);

                    switch(i % 6) {
                        case 0: r = v; g = t; b = p; break;
                        case 1: r = q; g = v; b = p; break;
                        case 2: r = p; g = v; b = t; break;
                        case 3: r = p; g = q; b = v; break;
                        case 4: r = t; g = p; b = v; break;
                        case 5: r = v; g = p; b = q; break;
                    }
                    return [ Math.round(r * 255), Math.round(g * 255), Math.round(b * 255) ];
                }

                var pad = 20;

                // Generate pseudo-random H, S, V based on hIndex for consistency
                function getColor(hIndex) {
                    var randomSeed = (hIndex * 9301 + 49297) % 233280;  // simple deterministic seed
                    // Simple deterministic PRNG for consistent host colors
                    function random() {
                        return Math.random();
                    }

                    var h = random();                  // hue: 0-1
                    var s = 0.5 + 0.5 * random();     // saturation: 0.5-1.0
                    var v = 0.7 + 0.3 * random();     // value: 0.7-1.0

                    var rgb = hsvToRgb(h, s, v);
                    return `rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, 0.25)`;
                }

                // Store and reuse host color for consistent coloring
                if (!hostColors)
                    hostColors = {};
                if (!hostColors[h]) {
                    hostColors[h] = getColor(hIndex);
                }
                ctx.fillStyle = hostColors[h];

                drawRoundedRect(
                    minX - pad,
                    minY - pad,
                    (maxX - minX) + pad * 2,
                    (maxY - minY) + pad * 2,
                    15
                );
                ctx.fill();


                // Draw hostname text
                ctx.globalAlpha = 1.0;
                ctx.fillStyle = rootWindow.isDarkMode ? "#FFFFFF" : "#000000";
                ctx.font = "bold 14px sans-serif";
                ctx.fillText(h, minX - pad + 5, minY - pad - 5);
            }
        }
    }

    // Physics Timer
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: calculatePhysics()
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
