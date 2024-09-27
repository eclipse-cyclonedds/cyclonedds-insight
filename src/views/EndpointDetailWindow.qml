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
import QtQuick.Dialogs

import org.eclipse.cyclonedds.insight


Window {
    property string endpointText

    visible: false
    width: 650
    height: 450
    flags: Qt.Dialog

    Rectangle {
        anchors.fill: parent
        color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent
    }

    Label {
        id: colorLabel
        visible: false
    }

    TextEdit {
        anchors.fill: parent
        text: endpointText
        readOnly: true
        wrapMode: Text.WordWrap
        selectByMouse: true
        padding: 10
        color: colorLabel.color
    }
}
