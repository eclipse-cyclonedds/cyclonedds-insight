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


Popup {
    anchors.centerIn: parent
    modal: true
    height: 150
    width: 300

    GridLayout {
        columns: 2
        anchors.fill: parent
        anchors.margins: 10
        rowSpacing: 10
        columnSpacing: 10

        Label {
            text: qsTr("Settings")
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        Item {}

        Label {
            text: "CYCLONEDDS_URI:"
        }
        TextField {
            id: login
            text: CYCLONEDDS_URI
            Layout.fillWidth: true
            readOnly: true
            activeFocusOnPress: false
        }

        Label {
            text: qsTr("Appearance:")
        }
        RadioButton {
            text: "Automatic (System)"
            checked: true
            checkable: false
        }   
    }
}
