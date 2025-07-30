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

    Component.onCompleted: {
        nodesMap = {};
        graphModel.setDomainId(domainId);
    }

    GraphModel {
        id: graphModel
    }

    Connections {
        target: graphModel

        function onNewNodeSignal(name, edgeName) {
            var nodeComponent = Qt.createComponent("qrc:/src/views/nodes/Bubble.qml");
            if (nodeComponent.status !== Component.Ready) {
                console.error("Failed to load Bubble.qml:", nodeComponent.errorString());
                return;
            }
            var randomX = Math.floor(Math.random() * (400 - 200 + 1)) + 200;
            var randomY = Math.floor(Math.random() * (400 - 200 + 1)) + 200;
            var nodeInstance = nodeComponent.createObject(root, { x: randomX, y: randomY, text: name, color: "lightblue" });
            nodesMap[name] = nodeInstance;

            if (edgeName && nodesMap[edgeName]) {
                var edgeComponent = Qt.createComponent("qrc:/src/views/nodes/Edge.qml");
                if (edgeComponent.status !== Component.Ready) {
                    console.error("Failed to load Edge.qml:", edgeComponent.errorString());
                    return;
                }
                var edgeInstance = edgeComponent.createObject(root, { bubble1: nodesMap[edgeName], bubble2: nodeInstance, z: -1 });
                nodesMap[name + edgeName] = edgeInstance;
            }
        }

        function onRemoveNodeSignal(name, edgeName) {
            if (nodesMap[name]) {
                nodesMap[name].destroy();
                delete nodesMap[name];
            }
            if (edgeName && nodesMap[name + edgeName]) {
                nodesMap[name + edgeName].destroy();
                delete nodesMap[name + edgeName];
            }
        }
    }

    function destroyNode(id) {
        if (nodesMap !== undefined && nodesMap[id] !== undefined) {
            nodesMap[id].destroy();
            delete nodesMap[id];
        }
    }

    ColumnLayout  {
        anchors.fill: parent
        anchors.margins: 10

        Label {
            text: qsTr("Domain")
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignLeft
            Layout.alignment: Qt.AlignLeft
        }
        Label {
            text: qsTr("Domain ID: ") + domainViewId.domainId
        }

        Rectangle {
            id: root
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

/*
            Edge {
                bubble1: bubble1
                bubble2: bubble2
            }

            Bubble {
                id: bubble1
                x: 100
                y: 100
                color: "lightblue"
                text: "Bubble 1"

                border.color: "gray"
                border.width: 1
            }

            Bubble {
                id: bubble2
                x: 400
                y: 200
                text: "Bubble 2"
                color: "lightgreen"
            }
*/
        }

        /*Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }*/
    }
}
