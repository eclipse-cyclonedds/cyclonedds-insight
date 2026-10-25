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
import QtQuick.Controls
import "qrc:/src/views"
import "qrc:/src/views/selection_details"

Rectangle {
    id: node
    x: 400
    y: 200
    property real nodeScale: 1.0
    property real weightScale: 1.0
    property int participantCount: 0
    property int topicCount: 0
    property int endpointCount: 0
    property real participantSizeFactor: 1.0
    property real combinedSizeFactor: 1.0
    property alias text: nodeText.text
    property string nodeName: ""
    property string hostName: ""
    property string nodeKey: ""
    property string vendorShortName: ""
    property string iconSource: ""
    property bool isDomain: false
    property color accentColor: Constants.accentColor
    property bool selected: false
    property bool related: false
    property bool selectionActive: false
    property bool hiddenByUser: false
    visible: !hiddenByUser
    readonly property bool hovered: dragArea.containsMouse || labelArea.containsMouse
    readonly property bool isDragging: dragArea.drag.active
    // Include the name above the circle when keeping neighboring nodes apart.
    readonly property real layoutWidth: Math.max(width, nodeText.implicitWidth, vendorBadge.width)
    readonly property real layoutHeight: height + nodeText.implicitHeight + 4 * nodeScale
    signal activated()
    signal contextMenuRequested(real menuX, real menuY)

    function handleClick(area, mouse) {
        if (mouse.button === Qt.RightButton) {
            var position = area.mapToItem(node, mouse.x, mouse.y)
            contextMenuRequested(position.x, position.y)
        } else {
            activated()
        }
    }

    width: 32 * nodeScale * weightScale
    height: width
    radius: width / 2
    z: selected || isDragging ? 4 : hovered ? 3 : 2
    opacity: selectionActive && !selected && !related ? 0.3 : 1
    color: isDomain ? Constants.graphDomainColor : Constants.cardBackgroundColor(rootWindow.isDarkMode)
    border.color: selected || hovered || isDomain ? accentColor
                  : Constants.designBorderColor(rootWindow.isDarkMode)
    border.width: selected ? 2.5 : hovered ? 2 : 1

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 10 * node.nodeScale
        height: width
        radius: width / 2
        visible: node.selected
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(node.accentColor.r, node.accentColor.g, node.accentColor.b, 0.3)
    }

    Label {
        id: nodeText
        visible: !node.selectionActive || node.selected || node.related || node.hovered
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 4 * node.nodeScale
        textFormat: Text.PlainText
        font.pixelSize: 12 * node.nodeScale
        horizontalAlignment: Text.AlignHCenter
        color: rootWindow.isDarkMode ? "white" : "black"
        leftPadding: 4 * node.nodeScale
        rightPadding: 4 * node.nodeScale
        topPadding: 2 * node.nodeScale
        bottomPadding: 2 * node.nodeScale
        background: Rectangle {
            visible: node.selected || node.hovered
            color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
            radius: Constants.controlRadius
            border.color: node.selected ? node.accentColor : Constants.designBorderColor(rootWindow.isDarkMode)
        }
        MouseArea {
            id: labelArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) { node.handleClick(labelArea, mouse) }
        }
    }

    DetailBadge {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: node.nodeScale
        color: "transparent"
        iconColor: node.isDomain ? Qt.darker(Constants.graphDomainColor, 3.2) : node.accentColor
        kind: node.isDomain ? "domain" : "process"
        visible: node.isDomain || (node.vendorShortName === "" && vendorLogo.status !== Image.Ready)
    }
    Image {
        id: vendorLogo
        visible: !node.isDomain && status === Image.Ready
        source: node.iconSource
        anchors.centerIn: parent
        width: 24 * node.nodeScale
        height: width
        sourceSize.width: 48
        sourceSize.height: 48
        fillMode: Image.PreserveAspectFit
    }
    Rectangle {
        id: vendorBadge
        anchors.centerIn: parent
        visible: !node.isDomain && node.vendorShortName !== "" && vendorLogo.status !== Image.Ready
        width: Math.max(22 * node.nodeScale, vendorFallbackText.implicitWidth + 10 * node.nodeScale)
        height: 18 * node.nodeScale
        radius: 4 * node.nodeScale
        color: rootWindow.isDarkMode ? "#444444" : "#e8e8e8"
        border.color: node.selected ? node.accentColor : Constants.designBorderColor(rootWindow.isDarkMode)
        border.width: 1

        Label {
            id: vendorFallbackText
            anchors.centerIn: parent
            text: node.vendorShortName
            textFormat: Text.PlainText
            font.pixelSize: 8 * node.nodeScale
            font.weight: Font.DemiBold
            color: rootWindow.isDarkMode ? "white" : "black"
        }
    }

    MouseArea {
        id: dragArea
        anchors.centerIn: parent
        width: Math.max(node.width, vendorBadge.visible ? vendorBadge.width : 0)
        height: node.height
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: pressedButtons & Qt.LeftButton ? node : null
        drag.axis: Drag.XAndYAxis
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.minimumX: 0
        drag.maximumX: Math.max(0, node.parent.width - node.width)
        drag.minimumY: 0
        drag.maximumY: Math.max(0, node.parent.height - node.height)
        onClicked: function(mouse) { node.handleClick(dragArea, mouse) }
    }
}
