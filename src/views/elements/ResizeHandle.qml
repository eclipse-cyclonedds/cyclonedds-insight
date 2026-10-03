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

Item {
    id: control

    property int orientation: Qt.Horizontal
    property bool touchMode: IS_MOBILE
    readonly property bool verticalLine: orientation === Qt.Horizontal
    readonly property bool active: SplitHandle.hovered || SplitHandle.pressed
    readonly property color lineColor: active
                                      ? Constants.accentColor
                                      : Constants.splitHandleColor(rootWindow.isDarkMode)

    implicitWidth: touchMode ? 10 : 6
    implicitHeight: touchMode ? 10 : 6

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: 2
        color: control.lineColor
    }

    Item {
        anchors.centerIn: parent
        width: control.verticalLine ? 3 : 15
        height: control.verticalLine ? 15 : 3

        Repeater {
            model: 3

            Rectangle {
                required property int index
                x: control.verticalLine ? 0 : index * 6
                y: control.verticalLine ? index * 6 : 0
                width: 3
                height: 3
                radius: 1.5
                color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                // Keep the dots distinguishable without a bright central accent.
                opacity: 0.35
            }
        }
    }
}
