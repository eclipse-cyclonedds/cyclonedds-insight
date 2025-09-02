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


Item {
    id: root
    width: 24
    height: 24

    property color circleColor: "grey"  // light gray
    property color textColor: "white"
    property int fontSize: 14
    property string tooltipText: ""

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: circleColor

        Text {
            anchors.centerIn: parent
            text: "i"
            font.bold: true
            font.pixelSize: fontSize
            color: textColor
        }
    }

    ToolTip {
        id: infoIconTooltip
        parent: ma
        visible: ma.containsMouse && tooltipText.length > 0
        delay: 50
        text: tooltipText
        contentItem: Label {
            text: infoIconTooltip.text
        }
        background: Rectangle {
            border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
            border.width: 1
            color: rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true


    }
}
