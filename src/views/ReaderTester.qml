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
        topicNameTextFieldId.text = topicType.replace(/::/g, "_");
        readerTesterDiaId.topicType = topicType
    }

    ListModel {
        id: partitionModel
    }

    ScrollView {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: buttonRow.top
        clip: true

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
            anchors.fill: parent
            spacing: 5
            padding: 5

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
                width: readerTesterDiaId.width - 40
            }

            Label {
                text: "Ownership"
                font.bold: true
            }
            ComboBox {
                id: ownershipComboId
                model: ["DDS_OWNERSHIP_SHARED", "DDS_OWNERSHIP_EXCLUSIVE"]
                width: readerTesterDiaId.width - 30
            }

            Label {
                text: "Durability"
                font.bold: true
            }
            ComboBox {
                id: durabilityComboId
                model: ["DDS_DURABILITY_VOLATILE", "DDS_DURABILITY_TRANSIENT_LOCAL", "DDS_DURABILITY_TRANSIENT", "DDS_DURABILITY_PERSISTENT"]
                width: readerTesterDiaId.width - 30
            }

            Label {
                text: "Reliability"
                font.bold: true
            }
            ComboBox {
                id: reliabilityComboId
                model: ["DDS_RELIABILITY_BEST_EFFORT", "DDS_RELIABILITY_RELIABLE"]
                width: readerTesterDiaId.width - 30
            }

            Column {
                Label {
                    text: "Partitions"
                    font.bold: true
                }

                Button {
                    text: "Add Partition"
                    onClicked: partitionModel.append({"partition": ""})
                }
            }
            Repeater {
                model: partitionModel

                Row {
                    spacing: 10
                    Rectangle {
                        width: 20
                        height: partitionField.height
                        color: "transparent"
                    }
                    TextField {
                        leftPadding: 10
                        id: partitionField
                        placeholderText: "Enter partition"
                        text: modelData
                        onTextChanged: partitionModel.set(index, {"partition": text})
                    }
                    Button {
                        text: "Remove"
                        onClicked: partitionModel.remove(index)
                    }
                }
            }

            Label {
                text: "DataRepresentation"
                font.bold: true
            }
            Row {
                CheckBox {
                    id: dataReprDefaultCheckbox
                    checked: true
                    text: qsTr("Default")
                    onCheckedChanged: {
                        if (checked) {
                            dataReprXcdr1Checkbox.checked = false;
                            dataReprXcdr2Checkbox.checked = false;
                        }
                        if (!dataReprXcdr1Checkbox.checked && !dataReprXcdr2Checkbox.checked) {
                            checked = true;
                        }
                    }
                }
                CheckBox {
                    id: dataReprXcdr1Checkbox
                    checked: false
                    text: qsTr("XCDR1")
                    onCheckedChanged: {
                        if (checked) {
                            dataReprDefaultCheckbox.checked = false;
                        } else {
                            if (!dataReprXcdr2Checkbox.checked) {
                                dataReprDefaultCheckbox.checked = true;
                            }
                        }
                    }
                }
                CheckBox {
                    id: dataReprXcdr2Checkbox
                    checked: false
                    text: qsTr("XCDR2")
                    onCheckedChanged: {
                        if (checked) {
                            dataReprDefaultCheckbox.checked = false;
                        } else {
                            if (!dataReprXcdr1Checkbox.checked) {
                                dataReprDefaultCheckbox.checked = true;
                            }
                        }
                    }
                }
            }
        }
    }

    Row {
        id: buttonRow
        spacing: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10

        Button {
            text: qsTr("Create Reader")
            onClicked: {
                var partitions = [];
                for (var i = 0; i < partitionModel.count; i++) {
                    partitions.push(partitionModel.get(i).partition);
                }
                datamodelRepoModel.addReader(
                    readerDomainIdSpinBox.value,
                    topicNameTextFieldId.text,
                    topicType,
                    ownershipComboId.currentText,
                    durabilityComboId.currentText,
                    reliabilityComboId.currentText,
                    dataReprXcdr1Checkbox.checked,
                    dataReprXcdr2Checkbox.checked,
                    partitions
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
