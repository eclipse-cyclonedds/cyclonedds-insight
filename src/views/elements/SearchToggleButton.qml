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
import "qrc:/src/views/icons"

SidebarActionButton {
    id: control

    property bool expanded: false

    Accessible.name: qsTrId("general.search.placeholder")
    highlighted: expanded

    SearchIcon {
        anchors.centerIn: parent
        z: 1
        expanded: control.expanded
        iconColor: Constants.mutedForegroundColor(control.isDarkMode)
    }
}
