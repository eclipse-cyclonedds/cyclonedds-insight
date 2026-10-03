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

Item {
    id: root

    property color iconColor: "grey"
    property real lineWidth: 1.8
    property bool minus: false

    implicitWidth: 18
    implicitHeight: 18

    Rectangle {
        anchors.centerIn: parent
        width: 12
        height: root.lineWidth
        radius: height / 2
        color: root.iconColor
    }

    Rectangle {
        anchors.centerIn: parent
        visible: !root.minus
        width: root.lineWidth
        height: 12
        radius: width / 2
        color: root.iconColor
    }
}
