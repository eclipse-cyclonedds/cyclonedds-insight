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


DropArea {
    id: dropAreaId
    anchors.fill: parent
    enabled: true
    property bool isEntered: false
    Drag.dragType: Drag.Automatic
    onEntered: {
        isEntered = true;
    }
    onExited: {
        isEntered = false;
    }
    onDropped: (drag) => {
        isEntered = false;
        var rejectedCount = 0

        if (drag.hasUrls) {
            for (let i = 0; i < drag.urls.length; ++i) {
                let url = drag.urls[i];
                if (url.toString().endsWith(".idl")) {
                    console.log("Dropped file ok: " + url);
                } else {
                    rejectedCount += 1
                    console.log("Dropped file is not a .idl file:" + url);
                }
            }
        }

        if (rejectedCount === 0) {
            drag.accept(Qt.CopyAction)
            datamodelRepoModel.addUrls(drag.urls)
        }
    }

    Rectangle {
        visible: dropAreaId.isEntered
        anchors.fill: parent
        color: Constants.warningColor
        border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
        border.width: 2
        radius: 10

        Label {
            anchors.centerIn: parent
            text: "Drop .idl files here"
            font.pixelSize: 30
            color: "black"
        }

        MouseArea {
            enabled: dropAreaId.isEntered
            anchors.fill: parent
            onClicked: {
                dropAreaId.isEntered = false
            }
        }
    }
}
