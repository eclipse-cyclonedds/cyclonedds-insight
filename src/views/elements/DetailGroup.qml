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
import QtQuick.Controls.Basic as Basic
import "qrc:/src/views"

Basic.GroupBox {
    id: control
    padding: 12
    spacing: 12

    label: Label {
        x: control.leftPadding
        y: control.padding
        width: control.availableWidth
        text: control.title
        font.bold: true
        color: rootWindow.isDarkMode ? "#eeeeee" : "#262626"
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Constants.cardRadius
        color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
        border.width: 1
        border.color: Constants.designBorderColor(rootWindow.isDarkMode)
    }
}
