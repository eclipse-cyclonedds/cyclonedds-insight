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
    modal: false
    height: 120
    width: 180

    Column {
        anchors.fill: parent
        spacing: 10
        padding: 10

        Label {
            text: qsTr("Add Domain")
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        SpinBox {
            id: domainIdSpinBox
            value: 1
            editable: false
            from: 0
            to: 232
        }
        Row {
            Button {
                id: addButton
                text: qsTr("Add")
                onClicked: {
                    treeModel.addDomainRequest(parseInt(domainIdSpinBox.value))
                    domainIdSpinBox.value += 1
                    close()
                }
            }
            Button {
                text: qsTr("Cancel")
                onClicked: close()
            }
        }
    }
}
