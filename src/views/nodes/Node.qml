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
    property real nodeScale: 1.0

    width: 30 * nodeScale
    height: 30 * nodeScale
    radius: width / 2
    property alias text: nodeText.text
    property string nodeName: ""
    property string hostName: ""
    property string nodeKey: ""
    property string vendorShortName: ""
    property string iconSource: ""
    property bool isDomain: false

    border.color: "gray"
    border.width: 1

    color: isDomain ? "#14B4FF" : rootWindow.isDarkMode ? "black" : "white"

    Label {
        id: nodeText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 4 * nodeScale
        font.pixelSize: 12 * nodeScale
        text: ""
    }

    Image {
        visible: iconSource !== ""
        source: iconSource
        sourceSize.width: 20 * nodeScale
        sourceSize.height: 20 * nodeScale
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
    }

    Rectangle {
        visible: iconSource === "" && vendorShortName !== "" && !isDomain
        anchors.centerIn: parent
        width: Math.max(20 * nodeScale, vendorFallbackText.implicitWidth + 6 * nodeScale)
        height: 16 * nodeScale
        radius: 4 * nodeScale
        color: rootWindow.isDarkMode ? "#444444" : "#e8e8e8"
        border.color: "gray"
        border.width: 1
        clip: true

        Label {
            id: vendorFallbackText
            anchors.fill: parent
            anchors.margins: 2 * nodeScale
            text: vendorShortName
            clip: true
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 8 * nodeScale
        }
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