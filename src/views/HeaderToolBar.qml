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

ToolBar {
    topPadding: 10
    bottomPadding: 10
    leftPadding: 10
    rightPadding: 10

    background: Rectangle {
        anchors.fill: parent
        color: rootWindow.isDarkMode ? Constants.darkHeaderBackground : Constants.lightHeaderBackground
    }

    RowLayout {
        anchors.fill: parent
        Image {
            source: "qrc:/res/images/cyclonedds.png"
            sourceSize.width: 30
            sourceSize.height: 30
        }
        Label {
            text: rootWindow.title
        }
        Item {
            Layout.fillWidth: true
        }
        ToolButton {
            text: "Home"
            onClicked: {
                layout.currentIndex = 1
            }
        }
        ToolButton {
            text: "Settings"
            onClicked: {
                layout.currentIndex = 0
            }
        }
    }
}
