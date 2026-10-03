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

import "qrc:/src/views/icons"

Button {
    id: control
    property bool expanded: false
    rightPadding: leftPadding + 24

    ChevronIcon {
        anchors.right: parent.right
        anchors.rightMargin: control.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        iconColor: control.palette.buttonText
        rotation: control.expanded ? 180 : 0
    }
}
