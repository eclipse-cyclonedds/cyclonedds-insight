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
    id: readerTesterDiaId

    anchors.centerIn: parent
    modal: true
    x: (rootWindow.width - width) / 2
    y: (rootWindow.height - height) / 2

    width: 600
    height: 400

    property int domainId: 0
    property string topicType

    Component.onCompleted: {
        console.log("Reader", readerTesterDiaId.topicType)
    }

    function setType(topicType) {
        topicNameTextFieldId.text = topicType.replace(".", "_")
        readerTesterDiaId.topicType = topicType
    }

    Column {
        anchors.fill: parent
        spacing: 5
        padding: 0

        Label {
            text: "Create Reader"
            font.bold: true
            font.pixelSize: 30
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Domain"
            font.bold: true
        }
        SpinBox {
            id: readerDomainIdSpinBox
            value: 0
            editable: false
            from: 0
            to: 232
        }

        Label {
            text: "Topic Type"
            font.bold: true
        }
        Label {
            text: readerTesterDiaId.topicType
        }

        Label {
            text: "Topic Name"
            font.bold: true
        }
        TextField {
            id: topicNameTextFieldId
            width: readerTesterDiaId.width - 20
        }

        Label {
            text: "Ownership"
            font.bold: true
        }
        ComboBox {
            id: ownershipComboId
            model: ["DDS_OWNERSHIP_SHARED", "DDS_OWNERSHIP_EXCLUSIVE"]
            width: readerTesterDiaId.width - 20
        }

        Label {
            text: "Durability"
            font.bold: true
        }
        ComboBox {
            id: durabilityComboId
            model: ["DDS_DURABILITY_VOLATILE", "DDS_DURABILITY_TRANSIENT_LOCAL", "DDS_DURABILITY_TRANSIENT", "DDS_DURABILITY_PERSISTENT"]
            width: readerTesterDiaId.width - 20
        }

        Label {
            text: "Reliability"
            font.bold: true
        }
        ComboBox {
            id: reliabilityComboId
            model: ["DDS_RELIABILITY_BEST_EFFORT", "DDS_RELIABILITY_RELIABLE"]
            width: readerTesterDiaId.width - 20
        }

        Row {
            Button {
                text: qsTr("Create Reader")
                onClicked: {
                    datamodelRepoModel.addReader(
                        readerDomainIdSpinBox.value,
                        topicNameTextFieldId.text,
                        topicType,
                        ownershipComboId.currentText,
                        durabilityComboId.currentText,
                        reliabilityComboId.currentText
                    )
                    readerTesterDiaId.close()
                }
            }
            Button {
                text: qsTr("Cancel")
                onClicked: {
                    readerTesterDiaId.close()
                }
            }
        }
    }

}
