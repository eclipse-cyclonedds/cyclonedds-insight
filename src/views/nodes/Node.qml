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


Rectangle {
    x: 400
    y: 200
    width: 30
    height: 30
    radius: 15
    property alias text: nodeText.text
    property string nodeName: ""
    property string hostName: ""
    property string nodeKey: ""
    property bool isVendorCycloneDDS: false
    property bool isDomain: false

    border.color: "gray"
    border.width: 1

    color: isDomain ? "#14B4FF" : rootWindow.isDarkMode ? "black" : "white"

    Label {
        id: nodeText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 4  // Optional spacing between node and text
        text: ""
    }

    Image {
        visible: isVendorCycloneDDS
        source: "qrc:/res/images/cyclonedds.png"
        sourceSize.width: 20
        sourceSize.height: 20
        anchors.centerIn: parent
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: parent
        drag.axis: Drag.XAndYAxis
        cursorShape: Qt.OpenHandCursor

        drag.minimumX: 0
        drag.maximumX: root.width - parent.width
        drag.minimumY: 0
        drag.maximumY: root.height - parent.height
    }
}