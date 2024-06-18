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

import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import org.eclipse.cyclonedds.insight


Rectangle {
    id: settingsViewId
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

    ScrollView {
        anchors.fill: parent

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
                id: cycloneUriLabelId
                text: "CYCLONEDDS_URI:"
            }
            TextField {
                id: login
                text: CYCLONEDDS_URI
                Layout.preferredWidth: settingsViewId.width - cycloneUriLabelId.width - 30
                Layout.minimumWidth: 200
                readOnly: true
            }

            Label {
                text: qsTr("Appearance:")
            }
            RadioButton {
                text: "Automatic (System)"
                checked: true
                checkable: false
            }

            Label {
                text: qsTr("AppDataLocation:")
            }
            Button {
                text: "Open Folder"
                onClicked: Qt.openUrlExternally(StandardPaths.writableLocation(StandardPaths.AppDataLocation));
            }
            Item {
                Layout.columnSpan: 2
                Layout.fillHeight: true
            }
        }
    }
}
