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
import QtQuick.Controls.Basic as Basic
import ".."

Basic.ToolButton {
    id: control

    property bool isDarkMode: false

    implicitWidth: 32
    implicitHeight: 30
    padding: 0
    leftInset: 0
    rightInset: 0
    topInset: 0
    bottomInset: 0
    hoverEnabled: true

    HoverHandler {
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    background: Rectangle {
        radius: Constants.controlRadius
        color: control.down
               ? (control.isDarkMode ? "#555555" : "#b9b7b7")
             : control.hovered || control.highlighted
               ? (control.isDarkMode ? "#454545" : "#c9c7c7")
               : "transparent"
        border.width: control.visualFocus || control.hovered ? 1 : 0
        border.color: control.visualFocus ? Constants.accentColor
                     : Constants.designBorderColor(control.isDarkMode)
    }
}
