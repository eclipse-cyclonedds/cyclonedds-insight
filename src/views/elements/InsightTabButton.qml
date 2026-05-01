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
import QtQuick.Layouts

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"

TabButton {
    id: control
    property alias tabText: label.text


    anchors.top: parent.top
    anchors.bottom: parent.bottom

    background: Rectangle {
        color: control.checked ? (rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent) : (control.hovered ? (rootWindow.isDarkMode ? "#454545" : "#c9c7c7") : (rootWindow.isDarkMode ? "#383838" : "#dcdcdc"))
        
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 1
            color: rootWindow.isDarkMode ? "#1e1e1e" : "#b9b9b9"
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            color: "#144fff"
            visible: control.checked
        }
    }

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        Label {
            id: label
            text: control.tabText
            font.pixelSize: 16

            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 16
        }
    }
}
