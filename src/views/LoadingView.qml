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


Rectangle {
    anchors.fill: parent
    color: rootWindow.isDarkMode ? Constants.darkMainContentBackground : Constants.lightMainContentBackground

    AnimatedImage {
        id: animatedLoadingId
        anchors.centerIn: parent
        source: "qrc:/res/images/spinning.gif"
        sourceSize.height: 100
        sourceSize.width: 100
        height: 100
        width: 100
    }

    Label {
        text: "Loading ..."
        anchors.top: animatedLoadingId.bottom
        anchors.horizontalCenter: animatedLoadingId.horizontalCenter
    }
}