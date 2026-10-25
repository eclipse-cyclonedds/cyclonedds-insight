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
    id: nodeDetailViewId
    anchors.fill: parent
    color: "transparent"
    clip: true

    property int domainId
    property bool hideSelf
    property bool speedEnabled
    property string currentSpeedUnit

    property var nodesMap
    property var edges: []            // array of { source: Item, target: Item }
    property var edgesMap: ({})       // map edgeId -> edgeItem (for quick duplicate-check + removal)
    property var velocities: ({})
    property var hostsMap: ({})       // hostName -> [nodes]
    property int idealLength: 110
    property real nodeScale: 1.0
    property int sizeMode: 0 // Equal size, participants, combined.
    property string selectedNodeKey: ""
    property var hostColors: ({})
    property int hiddenNodeCount: 0

    Menu {
        id: nodeMenu
        objectName: "nodeContextMenu"
        property string nodeKey: ""
        MenuItem {
            objectName: "hideNodeAction"
            text: qsTrId("general.hide")
            onTriggered: nodeDetailViewId.hideNode(nodeMenu.nodeKey)
        }
    }

    Component.onCompleted: {
        nodesMap = {};
        edges = [];
        edgesMap = {};
        velocities = {};
        hostsMap = {};
        graphModel.setDomainId(domainId, hideSelf, speedEnabled);
    }

    GraphModel {
        id: graphModel
    }



    Connections {
        target: graphModel

        function onNewNodeSignal(key, name, edgeName, hostName, vendorShortName, vendorPicture) {
            if (!nodesMap) nodesMap = {};
            if (!hostsMap) hostsMap = {};
            if (!velocities) velocities = {};
            if (!edges) edges = [];
            if (!edgesMap) edgesMap = {};

            var nodeInstance;

            if (nodesMap[key]) {
                // reuse existing node
                nodeInstance = nodesMap[key];

                // update host membership if a non-empty hostName is given
                if (hostName && hostName !== "") {
                    // if the node had a different host before, remove from that host list
                    var prevHost = (typeof nodeInstance.hostName !== "undefined") ? nodeInstance.hostName : "";
                    if (prevHost !== hostName) {
                        if (prevHost && hostsMap[prevHost]) {
                            hostsMap[prevHost] = hostsMap[prevHost].filter(function(n) { return n.nodeKey !== key; });
                            if (hostsMap[prevHost].length === 0)
                                delete hostsMap[prevHost];
                        }
                        // register under new host
                        if (!hostsMap[hostName]) hostsMap[hostName] = [];
                        // avoid duplicate entries
                        var already = false;
                        for (var i = 0; i < hostsMap[hostName].length; ++i) {
                            if (hostsMap[hostName][i].nodeKey === key) { already = true; break; }
                        }
                        if (!already) hostsMap[hostName].push(nodeInstance);
                        nodeInstance.hostName = hostName;
                    }
                }
                nodeInstance.vendorShortName = vendorShortName || "";
                nodeInstance.iconSource = vendorPicture || "";
                nodeInstance.text = name;
                nodeInstance.nodeName = name;
                nodeInstance.accentColor = nodeInstance.hostName ? hostColor(nodeInstance.hostName) : Constants.accentColor;
            } else {
                // create new node
                var nodeComponent = Qt.createComponent("qrc:/src/views/nodes/Node.qml");
                if (nodeComponent.status !== Component.Ready) {
                    console.error("Failed to load Node.qml:", nodeComponent.errorString());
                    return;
                }

                var randomX = 40 + Math.random() * Math.max(0, root.width - 240);
                var randomY = 60 + Math.random() * Math.max(0, root.height - 180);

                nodeInstance = nodeComponent.createObject(root, {
                    x: randomX,
                    y: randomY,
                    text: name,
                    isDomain: !(hostName && hostName !== ""),
                    nodeName: name,
                    hostName: hostName || "",
                    nodeKey: key,
                    vendorShortName: vendorShortName || "",
                    iconSource: vendorPicture || "",
                    accentColor: hostName ? nodeDetailViewId.hostColor(hostName) : Constants.accentColor,
                    nodeScale: nodeDetailViewId.nodeScale
                });

                if (!nodeInstance) {
                    console.error("Failed to instantiate Node.qml for", key);
                    return;
                }

                nodeInstance.selected = Qt.binding(function() { return nodeDetailViewId.selectedNodeKey === key; });
                nodeInstance.weightScale = Qt.binding(function() {
                    return nodeDetailViewId.sizeMode === 0 ? 1
                         : nodeDetailViewId.sizeMode === 1 ? nodeInstance.participantSizeFactor
                         : nodeInstance.combinedSizeFactor;
                });
                nodeInstance.related = Qt.binding(function() { return nodeDetailViewId.isRelated(key); });
                nodeInstance.selectionActive = Qt.binding(function() { return nodeDetailViewId.selectedNodeKey !== ""; });
                nodeInstance.activated.connect(function() { nodeDetailViewId.selectNode(key); });
                nodeInstance.contextMenuRequested.connect(function(menuX, menuY) {
                    var position = nodeInstance.mapToItem(nodeDetailViewId, menuX, menuY);
                    nodeMenu.nodeKey = key;
                    nodeMenu.popup(position.x, position.y);
                });
                nodesMap[key] = nodeInstance;
                if (!velocities[key]) velocities[key] = { vx: 0, vy: 0 };

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
                    var a = key;
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
                            node1: nodesMap[edgeName],
                            node2: nodeInstance,
                            z: -1,
                            speedEnabled: speedEnabled,
                            currentUnit: currentSpeedUnit
                        });
                        if (!edgeInstance) {
                            console.error("Failed to instantiate Edge.qml for", edgeId);
                            return;
                        }

                        edges = edges.concat([{
                            source: nodesMap[edgeName],
                            target: nodeInstance
                        }]);
                        edgesMap[edgeId] = edgeInstance;
                    }
                }
            }
        }

        function onRemoveEdgeBetweenNodes(nodeA, nodeB) {
            if (!nodeA || !nodeB) return;
            var a = nodeA;
            var b = nodeB;
            var edgeId = (a < b) ? (a + "::" + b) : (b + "::" + a);

            if (edgesMap[edgeId]) {
            try { edgesMap[edgeId].destroy(); } catch (e) { /* ignore */ }
            delete edgesMap[edgeId];
            }

            edges = edges.filter(function(e) {
            return !(
                (e.source && e.target) &&
                ((e.source.nodeKey === a && e.target.nodeKey === b) ||
                 (e.source.nodeKey === b && e.target.nodeKey === a))
            );
            });
        }

        function onRemoveNodeSignal(key, edgeName) {
            if (nodeDetailViewId.selectedNodeKey === key)
                nodeDetailViewId.selectedNodeKey = "";
            var hostName = nodesMap[key] ? nodesMap[key].hostName : null;

            // destroy the node
            if (nodesMap[key]) {
                if (nodesMap[key].hiddenByUser) --hiddenNodeCount;
                if (nodeMenu.nodeKey === key) nodeMenu.close();
                try { nodesMap[key].destroy(); } catch (e) { /* ignore */ }
                delete nodesMap[key];
            }
            if (velocities && velocities[key]) delete velocities[key];

            // remove/destroy any edges that include this node (both from edges array and edgesMap)
            // edgesMap keys are "a::b"
            for (var id in edgesMap) {
                if (!edgesMap.hasOwnProperty(id)) continue;
                var parts = id.split("::");
                if (parts.length !== 2) continue;
                if (parts[0] === key || parts[1] === key) {
                    try { edgesMap[id].destroy(); } catch (e) { /* ignore */ }
                    delete edgesMap[id];
                }
            }
            edges = edges.filter(function(e) {
                return (e.source && e.source.nodeKey !== key) && (e.target && e.target.nodeKey !== key);
            });

            // clean up hosts map
            if (hostName && hostsMap[hostName]) {
                hostsMap[hostName] = hostsMap[hostName].filter(function(n) {
                    return n.nodeKey !== key;
                });
                if (hostsMap[hostName].length === 0)
                    delete hostsMap[hostName];
            }

            // Also be safe: remove this node from all host lists (in case hostName was empty or unknown)
            for (var h in hostsMap) {
                if (!hostsMap.hasOwnProperty(h)) continue;
                hostsMap[h] = hostsMap[h].filter(function(n) { return n.nodeKey !== key; });
                if (hostsMap[h].length === 0) delete hostsMap[h];
            }
            nodeDetailViewId.refreshNodeRanking();
        }

        function onUpdateEdgeSignal(nodeKey, edgeName, t, bps) {
            console.debug("Updating edge:", nodeKey, edgeName, t, bps);
            if (!edgesMap || !nodesMap) return;

            var a = nodeKey;
            var b = edgeName;
            var edgeId = (a < b) ? (a + "::" + b) : (b + "::" + a);

            if (edgesMap[edgeId]) {
                if (t === "sent") {
                    edgesMap[edgeId].updateUpBps(bps);
                } else if (t === "recv") {
                    edgesMap[edgeId].updateDownBps(bps);
                }
            } else {
                console.warn("Tried to update non-existing edge:", edgeId);
            }
        }

        function onNodeStatisticsSignal(key, participants, topics, endpoints, participantSize, combinedSize) {
            var node = nodesMap[key];
            if (!node) return;
            node.participantCount = participants;
            node.topicCount = topics;
            node.endpointCount = endpoints;
            node.participantSizeFactor = participantSize;
            node.combinedSizeFactor = combinedSize;
        }

        function onNodeStatisticsUpdated() { nodeDetailViewId.refreshNodeRanking(); }
    }

    function enableSpeeds(enabled) {
        if (enabled) {
            graphModel.start()
        } else {
            graphModel.stop();
        }
        if (!edgesMap) return;
        for (var edgeId in edgesMap) {
            if (edgesMap.hasOwnProperty(edgeId)) {
                edgesMap[edgeId].enableSpeeds(enabled);
            }
        }
    }

    function setSpeedUnit(unit) {
        nodeDetailViewId.currentSpeedUnit = unit;
        if (!edgesMap) return;
        for (var edgeId in edgesMap) {
            if (edgesMap.hasOwnProperty(edgeId)) {
                edgesMap[edgeId].setCurrentUnit(unit);
            }
        }
    }

    function setNodeScale(scale) {
        nodeDetailViewId.nodeScale = scale;
        if (!nodesMap) return;
        for (var key in nodesMap) {
            if (nodesMap.hasOwnProperty(key)) {
                nodesMap[key].nodeScale = scale;
            }
        }
    }

    function hostColor(hostName) {
        // Original hue/saturation/brightness range, retained for this view.
        if (!hostColors[hostName]) {
            hostColors[hostName] = Qt.hsva(Math.random(), 0.5 + 0.5 * Math.random(),
                                          0.7 + 0.3 * Math.random(), 1)
        }
        return hostColors[hostName]
    }

    function selectNode(key) {
        selectedNodeKey = selectedNodeKey === key ? "" : key
        if (selectedNodeKey) statisticsPanel.showNode(key, nodesMap[key].isDomain)
        forceActiveFocus()
    }

    function hideNode(key) {
        var node = nodesMap[key];
        if (!node || node.hiddenByUser) return;
        node.hiddenByUser = true;
        velocities[key] = { vx: 0, vy: 0 };
        ++hiddenNodeCount;
        if (selectedNodeKey === key) selectedNodeKey = "";
        hostBackground.requestPaint();
        refreshNodeRanking();
    }

    function showHiddenNodes() {
        for (var key in nodesMap) nodesMap[key].hiddenByUser = false;
        hiddenNodeCount = 0;
        hostBackground.requestPaint();
        refreshNodeRanking();
    }

    function isRelated(key) {
        if (!selectedNodeKey) return false
        if (selectedNodeKey === key) return true
        return edges.some(function(edge) {
            return !edge.source.hiddenByUser && !edge.target.hiddenByUser
                    && ((edge.source.nodeKey === selectedNodeKey && edge.target.nodeKey === key)
                    || (edge.target.nodeKey === selectedNodeKey && edge.source.nodeKey === key))
        })
    }

    Keys.onEscapePressed: selectedNodeKey = ""

    function refreshNodeRanking() {
        if (!statisticsPanel.expanded) return;
        // The dropdown presents endpoints before topics; Python counts store
        // participants, topics, endpoints in that order.
        var metric = [0, 2, 1, 3][statisticsPanel.metric];
        statisticsPanel.entries = graphModel.nodeStatisticsRows(metric).filter(function(entry) {
            var node = nodesMap[entry.key];
            return node && !node.hiddenByUser && (statisticsPanel.showDomains || !node.isDomain);
        }).map(function(entry) {
            var node = nodesMap[entry.key];
            return { key: entry.key, value: entry.value, name: node.nodeName,
                     hostName: node.hostName, color: node.isDomain ? Constants.graphDomainColor : node.accentColor,
                     participants: entry.participants, endpoints: entry.endpoints, topics: entry.topics };
        });
    }

    NodeStatisticsPanel {
        id: statisticsPanel
        objectName: "nodeStatisticsPanel"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 12
        z: 11
        selectedNodeKey: nodeDetailViewId.selectedNodeKey
        onExpandedChanged: if (expanded) nodeDetailViewId.refreshNodeRanking()
        onMetricChanged: nodeDetailViewId.refreshNodeRanking()
        onShowDomainsChanged: nodeDetailViewId.refreshNodeRanking()
        onNodeSelected: function(key) { nodeDetailViewId.selectNode(key); }
    }

    function calculatePhysics() {
        var nodeList = Object.values(nodesMap).filter(function(node) { return !node.hiddenByUser; });
        var activeHosts = {};
        for (var hostname in hostsMap) {
            var visibleMembers = hostsMap[hostname].filter(function(node) { return !node.hiddenByUser; });
            if (visibleMembers.length) activeHosts[hostname] = visibleMembers;
        }
        var scale = nodeDetailViewId.nodeScale;
        // Read QML geometry once per frame, outside the pairwise force loop.
        var geometry = nodeList.map(function(node) {
            return { x: node.x, y: node.y, width: node.layoutWidth, height: node.layoutHeight };
        });
        var degrees = {};
        var neighbors = {};
        for (var edgeIndex = 0; edgeIndex < edges.length; ++edgeIndex) {
            var connection = edges[edgeIndex];
            if (connection.source.hiddenByUser || connection.target.hiddenByUser) continue;
            degrees[connection.source.nodeKey] = (degrees[connection.source.nodeKey] || 0) + 1;
            degrees[connection.target.nodeKey] = (degrees[connection.target.nodeKey] || 0) + 1;
            if (!neighbors[connection.source.nodeKey]) neighbors[connection.source.nodeKey] = [];
            if (!neighbors[connection.target.nodeKey]) neighbors[connection.target.nodeKey] = [];
            neighbors[connection.source.nodeKey].push(connection.target);
            neighbors[connection.target.nodeKey].push(connection.source);
        }

        // Separate host clusters as well as individual nodes. Otherwise several
        // hosts connected to the same domain settle on top of one another.
        var hostNames = Object.keys(activeHosts);
        var hostCenters = {};
        for (var h = 0; h < hostNames.length; ++h) {
            var members = activeHosts[hostNames[h]];
            var cx = 0, cy = 0;
            var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
            for (var m = 0; m < members.length; ++m) {
                cx += members[m].x;
                cy += members[m].y;
                minX = Math.min(minX, members[m].x);
                minY = Math.min(minY, members[m].y);
                maxX = Math.max(maxX, members[m].x + members[m].width);
                maxY = Math.max(maxY, members[m].y + members[m].height);
            }
            hostCenters[hostNames[h]] = {
                x: cx / members.length, y: cy / members.length,
                radius: Math.min(Math.sqrt(members.length) * 60 * scale,
                                 Math.sqrt(root.width * root.height / hostNames.length) * 0.45),
                left: minX - 20 * scale, right: maxX + 20 * scale,
                top: minY - 40 * scale, bottom: maxY + 20 * scale
            };
        }
        var hostForces = {};
        for (var a = 0; a < hostNames.length; ++a) {
            var center = hostCenters[hostNames[a]];
            var hx = 0, hy = 0;
            for (var b = 0; b < hostNames.length; ++b) {
                if (a === b) continue;
                var otherCenter = hostCenters[hostNames[b]];
                var hdx = center.x - otherCenter.x;
                var hdy = center.y - otherCenter.y;
                var distance = Math.sqrt(hdx * hdx + hdy * hdy);
                if (distance < 0.01) { hdx = a < b ? -1 : 1; hdy = 0; distance = 1; }
                var overlap = center.radius + otherCenter.radius + 40 * scale - distance;
                if (overlap > 0) {
                    hx += hdx / distance * overlap * 0.08;
                    hy += hdy / distance * overlap * 0.08;
                }
            }
            hostForces[hostNames[a]] = { x: hx, y: hy };
        }

        // Keep domains outside visible host rectangles and their headings.
        var domainForces = {};
        for (var domainIndex = 0; domainIndex < nodeList.length; ++domainIndex) {
            var domainNode = nodeList[domainIndex];
            if (!domainNode.isDomain || domainNode.isDragging) continue;
            var fx = 0, fy = 0;
            var domainX = domainNode.x + domainNode.width / 2;
            var domainY = domainNode.y + domainNode.height / 2;
            for (var hostIndex = 0; hostIndex < hostNames.length; ++hostIndex) {
                var bounds = hostCenters[hostNames[hostIndex]];
                var left = bounds.left - domainNode.layoutWidth / 2 - 16 * scale;
                var right = bounds.right + domainNode.layoutWidth / 2 + 16 * scale;
                var top = bounds.top - domainNode.height / 2 - 16 * scale;
                var bottom = bounds.bottom + domainNode.layoutHeight - domainNode.height / 2 + 16 * scale;
                if (domainX <= left || domainX >= right || domainY <= top || domainY >= bottom) continue;
                var escape = Infinity, pushX = 0, pushY = 0;
                if (left >= 12 + domainNode.width / 2) {
                    escape = domainX - left; pushX = -escape;
                }
                if (right <= root.width - domainNode.width / 2 - 12 && right - domainX < escape) {
                    escape = right - domainX; pushX = escape; pushY = 0;
                }
                if (top >= 48 + domainNode.height / 2 && domainY - top < escape) {
                    escape = domainY - top; pushX = 0; pushY = -escape;
                }
                if (bottom <= root.height - domainNode.height / 2 - 12 && bottom - domainY < escape) {
                    pushX = 0; pushY = bottom - domainY;
                }
                fx += pushX * 0.4;
                fy += pushY * 0.4;
                // Let the host yield as well, so opposing host rectangles
                // cannot trap a domain between their repulsion forces.
                var reaction = 0.4 / activeHosts[hostNames[hostIndex]].length;
                hostForces[hostNames[hostIndex]].x -= pushX * reaction;
                hostForces[hostNames[hostIndex]].y -= pushY * reaction;
            }
            domainForces[domainNode.nodeKey] = { x: fx, y: fy };
        }

        for (var i = 0; i < nodeList.length; i++) {
            var b1 = nodeList[i];
            var nodeKey = b1.nodeKey;
            if (!velocities[nodeKey])
                velocities[nodeKey] = { vx: 0, vy: 0 };
            var vel = velocities[nodeKey];
            if (b1.isDragging) {
                vel.vx = 0;
                vel.vy = 0;
                continue;
            }

            var fx = 0, fy = 0;

            if (b1.isDomain) {
                fx += domainForces[nodeKey].x;
                fy += domainForces[nodeKey].y;
            }

            // REPULSION between all nodes
            for (var j = 0; j < nodeList.length; j++) {
                if (i === j) continue;
                var dx = geometry[i].x - geometry[j].x;
                var dy = geometry[i].y - geometry[j].y;
                // Coincident nodes need a direction too, including after a drag.
                if (Math.abs(dx) + Math.abs(dy) < 0.01) { dx = i < j ? -1 : 1; dy = 0; }
                var distSq = dx*dx + dy*dy + 0.01;
                var dist = Math.sqrt(distSq);
                if (dist > 0) {
                    var force = Math.min(20 * scale, 2000 * scale * scale / distSq);
                    fx += (dx / dist) * force;
                    fy += (dy / dist) * force;
                }
                // A short-range collision force accounts for labels, rather
                // than treating the visible circles as dimensionless points.
                var overlapX = (geometry[i].width + geometry[j].width) / 2 + 12 * scale - Math.abs(dx);
                var overlapY = (geometry[i].height + geometry[j].height) / 2 + 10 * scale - Math.abs(dy);
                if (overlapX > 0 && overlapY > 0) {
                    var atVerticalBoundary = (dy <= 0 && geometry[i].y <= 48)
                            || (dy >= 0 && geometry[i].y >= root.height - b1.height - 12);
                    if (overlapX < overlapY || atVerticalBoundary)
                        fx += (dx < 0 || (dx === 0 && i < j) ? -1 : 1) * overlapX * 0.2;
                    else
                        fy += (dy < 0 || (dy === 0 && i < j) ? -1 : 1) * overlapY * 0.2;
                }
            }

            // EDGE SPRING
            var connected = neighbors[nodeKey] || [];
            for (var e = 0; e < connected.length; e++) {
                var other = connected[e];
                var dx2 = other.x - b1.x;
                var dy2 = other.y - b1.y;
                var dist2 = Math.sqrt(dx2 * dx2 + dy2 * dy2) || 0.01;
                var degree = Math.max(degrees[b1.nodeKey] || 1, degrees[other.nodeKey] || 1);
                var crowding = Math.max(1, Math.min(2.5, Math.sqrt(degree / 6)));
                var displacement = dist2 - (nodeDetailViewId.idealLength * scale * crowding);
                var stiffness = 0.02 / Math.max(1, Math.sqrt(degree / 6));
                fx += (dx2 / dist2) * displacement * stiffness;
                fy += (dy2 / dist2) * displacement * stiffness;
            }

            // HOST GROUP ATTRACTION (only for non-empty host names)
            if (b1.hostName && b1.hostName !== "") {
                var group = activeHosts[b1.hostName];
                if (group) {
                    fx += hostForces[b1.hostName].x;
                    fy += hostForces[b1.hostName].y;
                    for (var g = 0; g < group.length; g++) {
                        var b2g = group[g];
                        if (b2g === b1) continue;
                        var dxh = b2g.x - b1.x;
                        var dyh = b2g.y - b1.y;
                        var distH = Math.sqrt(dxh * dxh + dyh * dyh) || 0.01;
                        var hostIdeal = 100 * nodeDetailViewId.nodeScale;
                        var displacementH = distH - hostIdeal;
                        // Keep cohesion independent of the number of processes.
                        var cohesion = 0.08 / Math.max(2, group.length - 1);
                        fx += (dxh / distH) * displacementH * cohesion;
                        fy += (dyh / distH) * displacementH * cohesion;
                    }
                }
            }

            // Update velocity & position
            vel.vx += fx * 0.05;
            vel.vy += fy * 0.05;
            vel.vx = Math.max(-12 * scale, Math.min(12 * scale, vel.vx * 0.85));
            vel.vy = Math.max(-12 * scale, Math.min(12 * scale, vel.vy * 0.85));

            b1.x += vel.vx;
            b1.y += vel.vy;

            var boundedX = Math.max(12, Math.min(root.width - b1.width - 12, b1.x));
            var boundedY = Math.max(48, Math.min(root.height - b1.height - 12, b1.y));
            if (boundedX !== b1.x) vel.vx = 0;
            if (boundedY !== b1.y) vel.vy = 0;
            b1.x = boundedX;
            b1.y = boundedY;
        }
    }

    // Host background canvas (renders grouped rounded rects and hostname labels)
    Canvas {
        id: hostBackground
        anchors.fill: root
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

                var group = hostsMap[h].filter(function(node) { return !node.hiddenByUser; });
                if (!group || group.length === 0) continue;

                var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
                for (var i = 0; i < group.length; i++) {
                    var n = group[i];
                    minX = Math.min(minX, n.x);
                    minY = Math.min(minY, n.y);
                    maxX = Math.max(maxX, n.x + n.width);
                    maxY = Math.max(maxY, n.y + n.height);
                }

                var pad = 20 * nodeDetailViewId.nodeScale;
                var x = minX - pad;
                var y = minY - pad;
                var w = maxX - minX + pad * 2;
                var groupHeight = maxY - minY + pad * 2;
                var accent = Qt.tint("transparent", nodeDetailViewId.hostColor(h));
                ctx.globalAlpha = !nodeDetailViewId.selectedNodeKey || group.some(function(n) {
                    return nodeDetailViewId.isRelated(n.nodeKey);
                }) ? 1 : 0.5;
                var radius = Constants.cardRadius * 1.5;
                ctx.fillStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.25);
                drawRoundedRect(x, y, w, groupHeight, radius);
                ctx.fill();
                ctx.strokeStyle = Qt.rgba(accent.r, accent.g, accent.b, rootWindow.isDarkMode ? 0.38 : 0.22);
                ctx.lineWidth = 1;
                ctx.stroke();

                // Keep the full hostname outside the group, as in the
                // original view, with stronger contrast and larger type.
                ctx.globalAlpha = 1;
                ctx.font = "bold " + (14 * nodeDetailViewId.nodeScale) + "px sans-serif";
                ctx.fillStyle = rootWindow.isDarkMode ? "#ffffff" : "#202020";
                ctx.fillText(h, x + 5 * nodeDetailViewId.nodeScale, y - 5 * nodeDetailViewId.nodeScale);
                ctx.globalAlpha = 1;
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

    // Timer for repainting host background
    Timer {
        interval: 33
        running: true
        repeat: true
        onTriggered: hostBackground.requestPaint()
    }

    // Root area for nodes and edges
    Item {
        id: root
        anchors.fill: parent
        anchors.rightMargin: statisticsPanel.expanded ? statisticsPanel.width + 24 : 0
        z: 1
        clip: true
        MouseArea {
            anchors.fill: parent
            z: -2
            onClicked: nodeDetailViewId.selectedNodeKey = ""
        }
    }

    function stop() {
        graphModel.stop();
    }
}
