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
    property string topicName
    property var topicTypeNameList: []
    property string selectedTypeText: ""

    function setType(topicType) {
        topicTypeNameList = []
        topicName = topicType.replace(/::/g, "_");
        readerTesterDiaId.topicType = topicType
    }

    function setTypes(domain, name, typeList) {
        readerTesterDiaId.domainId = domain
        readerTesterDiaId.topicName = name
        readerTesterDiaId.topicTypeNameList = typeList
        readerDomainIdSpinBox.value = domain
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
                enabled: topicTypeNameList.length === 0
            }

            Label {
                text: "Topic Type"
                font.bold: true
            }
            Column {
                ComboBox {
                    id: typeComboBox
                    model: topicTypeNameList
                    visible: topicTypeNameList.length !== 0
                    width: readerTesterDiaId.width - 30
                    onCurrentTextChanged: {
                        topicType = typeComboBox.currentText;
                    }
                }
                Label {
                    text: readerTesterDiaId.topicType
                    visible: topicTypeNameList.length === 0
                }
            }

            Label {
                text: "Topic Name"
                font.bold: true
            }
            TextField {
                id: topicNameTextFieldId
                text: topicName
                width: readerTesterDiaId.width - 40
            }

            Label {
                text: "Reliability"
                font.bold: true
            }
            Column {
                ComboBox {
                    id: reliabilityComboId
                    model: ["DDS_RELIABILITY_BEST_EFFORT", "DDS_RELIABILITY_RELIABLE"]
                    width: readerTesterDiaId.width - 30
                }
                Row {
                    visible: reliabilityComboId.currentText === "DDS_RELIABILITY_RELIABLE" 
                    Label {
                        text: "max_blocking_time in milliseconds: "
                    }
                    SpinBox {
                        id: reliabilitySpinBox
                        to: 1e9
                        value: 100
                    }
                }
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
                text: "Ownership"
                font.bold: true
            }
            ComboBox {
                id: ownershipComboId
                model: ["DDS_OWNERSHIP_SHARED", "DDS_OWNERSHIP_EXCLUSIVE"]
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

            Label {
                text: "TypeConsistency"
                font.bold: true
            }
            Column {
                ComboBox {
                    id: typeConsistencyComboId
                    model: ["AllowTypeCoercion", "DisallowTypeCoercion"]
                    width: readerTesterDiaId.width - 30
                }
                Column {
                    visible: typeConsistencyComboId.currentText === "AllowTypeCoercion"
                    Row {
                        CheckBox {
                            id: allowTypeCoercion_ignore_sequence_bounds
                            checked: true
                            text: qsTr("ignore_sequence_bounds")
                        }
                        CheckBox {
                            id: allowTypeCoercion_ignore_string_bounds
                            checked: true
                            text: qsTr("ignore_string_bounds")
                        }
                        CheckBox {
                            id: allowTypeCoercion_ignore_member_names
                            checked: true
                            text: qsTr("ignore_member_names")
                        }
                    }
                    Row {
                        CheckBox {
                            id: allowTypeCoercion_prevent_type_widening
                            checked: false
                            text: qsTr("prevent_type_widening")
                        }
                        CheckBox {
                            id: allowTypeCoercion_force_type_validation
                            checked: false
                            text: qsTr("force_type_validation")
                        }
                    }
                }

                CheckBox {
                    id: disallowTypeCoercionForce_type_validationCheckbox
                    checked: false
                    text: qsTr("force_type_validation")
                    visible: typeConsistencyComboId.currentText === "DisallowTypeCoercion" 
                }
            }

            Label {
                text: "History"
                font.bold: true
            }
            Column {
                ComboBox {
                    id: historyComboId
                    model: ["KeepLast", "KeepAll"]
                    width: readerTesterDiaId.width - 30
                }
                Row {
                    Label {
                        text: "depth"
                        visible: historyComboId.currentText === "KeepLast"
                    }
                    SpinBox {
                        id: keepLastSpinBox
                        to: 1e9
                        value: 1
                        visible: historyComboId.currentText === "KeepLast"
                    }
                }
            }

            Label {
                text: "DestinationOrder"
                font.bold: true
            }
            ComboBox {
                id: destinationOrderComboId
                model: ["ByReceptionTimestamp", "BySourceTimestamp"]
                width: readerTesterDiaId.width - 30
            }

            Label {
                text: "Liveliness"
                font.bold: true
            }
            Column {
                ComboBox {
                    id: livelinessComboId
                    model: ["Automatic", "ManualByParticipant", "ManualByTopic"]
                    width: readerTesterDiaId.width - 30
                }
                Row {
                    Label {
                        text: "Seconds: "
                    }
                    SpinBox {
                        id: livelinessSpinBox
                        to: 1e9
                        value: 1
                        enabled: !livelinessCheckbox.checked
                    }
                    CheckBox {
                        id: livelinessCheckbox
                        checked: true
                        text: qsTr("infinite")
                    }
                }
            }

            Label {
                text: "Lifespan"
                font.bold: true
            }
            Row {
                Label {
                    text: "Seconds: "
                }
                SpinBox {
                    id: lifespanSpinBox
                    to: 1e9
                    value: 2
                    enabled: !lifespanCheckbox.checked
                }
                CheckBox {
                    id: lifespanCheckbox
                    checked: true
                    text: qsTr("infinite")
                }
            }

            Label {
                text: "Deadline"
                font.bold: true
            }
            Row {
                Label {
                    text: "Seconds: "
                }
                SpinBox {
                    id: deadlineSpinBox
                    to: 1e9
                    value: 2
                    enabled: !deadlineCheckbox.checked
                }
                CheckBox {
                    id: deadlineCheckbox
                    checked: true
                    text: qsTr("infinite")
                }
            }

            Label {
                text: "LatencyBudget"
                font.bold: true
            }
            Row {
                Label {
                    text: "Seconds: "
                }
                SpinBox {
                    id: latencyBudgetSpinBox
                    to: 1e9
                    value: 0
                    enabled: !latencyBudgetCheckbox.checked
                }
                CheckBox {
                    id: latencyBudgetCheckbox
                    checked: false
                    text: qsTr("infinite")
                }
            }

            Label {
                text: "OwnershipStrength"
                font.bold: true
            }
            SpinBox {
                id: ownershipStrengthSpinBox
                to: 1e9
                value: 0
            }

            Label {
                text: "PresentationAccessScope"
                font.bold: true
            }
            Column {
                ComboBox {
                    id: presentationAccessScopeComboId
                    model: ["Instance", "Topic", "Group"]
                    width: readerTesterDiaId.width - 30
                }
                Row {
                    CheckBox {
                        id: coherent_accessCheckbox
                        checked: false
                        text: qsTr("coherent_access")
                    }
                    CheckBox {
                        id: ordered_accessCheckbox
                        checked: false
                        text: qsTr("ordered_access")
                    }
                }
            }
            Label {
                text: "WriterDataLifecycle"
                font.bold: true
            }
            CheckBox {
                id: writerDataLifecycleCheckbox
                checked: true
                text: qsTr("autodispose")
            }

            Label {
                text: "ReaderDataLifecycle"
                font.bold: true
            }
            Column {
                Row {
                    Label {
                        text: "autopurge_nowriter_samples_delay in minutes: "
                    }
                    SpinBox {
                        id: autopurge_nowriter_samples_delaySpinBox
                        to: 1e9
                        value: 1
                        enabled: !autopurge_nowriter_samples_delayCheckbox.checked
                    }
                    CheckBox {
                        id: autopurge_nowriter_samples_delayCheckbox
                        checked: true
                        text: qsTr("infinite")
                    }
                }
                Row {
                    Label {
                        text: "autopurge_disposed_samples_delay in minutes: "
                    }
                    SpinBox {
                        id: autopurge_disposed_samples_delaySpinBox
                        to: 1e9
                        value: 1
                        enabled: !autopurge_disposed_samples_delaySpinBoxCheckbox.checked
                    }
                    CheckBox {
                        id: autopurge_disposed_samples_delaySpinBoxCheckbox
                        checked: true
                        text: qsTr("infinite")
                    }
                }

            }

            Label {
                text: "TransportPriority"
                font.bold: true
            }
            SpinBox {
                id: transportPrioritySpinBox
                to: 1e9
                value: 0
            }
            
            Label {
                text: "ResourceLimits"
                font.bold: true
            }
            Column {
                Row {
                    Label {
                        text: "max_samples"
                    }
                    SpinBox {
                        id: max_samplesSpinBox
                        from: -1
                        to: 1e9
                        value: -1
                    }
                }
                Row {
                    Label {
                        text: "max_instances"
                    }
                    SpinBox {
                        id: max_instancesSpinBox
                        from: -1
                        to: 1e9
                        value: -1
                    }
                }
                Row {
                    Label {
                        text: "max_samples_per_instance"
                    }
                    SpinBox {
                        id: max_samples_per_instanceSpinBox
                        from: -1
                        to: 1e9
                        value: -1
                    }
                }
            }

            Label {
                text: "TimeBasedFilter"
                font.bold: true
            }
            Row {
                Label {
                    text: "filter_fn in seconds: "
                }
                SpinBox {
                    id: timeBasedFilterSpinBox
                    to: 1e9
                    value: 0
                }
            }

            Label {
                text: "IgnoreLocal"
                font.bold: true
            }
            ComboBox {
                id: ignoreLocalComboId
                model: ["Nothing", "Participant", "Process"]
                width: readerTesterDiaId.width - 30
            }

            Label {
                text: "Userdata"
                font.bold: true
            }
            TextField {
                leftPadding: 10
                id: userdataField
                placeholderText: "Enter Userdata"
                text: ""
            }

            Label {
                text: "Groupdata"
                font.bold: true
            }
            TextField {
                leftPadding: 10
                id: groupdataField
                placeholderText: "Enter Groupdata"
                text: ""
            }

            Label {
                text: "EntityName"
                font.bold: true
            }
            TextField {
                leftPadding: 10
                id: entityNameField
                placeholderText: "Enter EntityName"
                text: ""
            }

            Label {
                text: "Property"
                font.bold: true
            }
            Row {
                TextField {
                    leftPadding: 10
                    id: propertyKeyField
                    placeholderText: "Enter key"
                    text: ""
                }
                TextField {
                    leftPadding: 10
                    id: propertyValueField
                    placeholderText: "Enter value"
                    text: ""
                }
            }

            Label {
                text: "BinaryProperty"
                font.bold: true
            }
            Row {
                TextField {
                    leftPadding: 10
                    id: binaryPropertyKeyField
                    placeholderText: "Enter key"
                    text: ""
                }
                TextField {
                    leftPadding: 10
                    id: binaryPropertyValueField
                    placeholderText: "Enter value"
                    text: ""
                }
            }

            Label {
                text: "DurabilityService"
                font.bold: true
            }
            Column {
                Row {
                    Label {
                        text: "cleanup_delay in minutes: "
                    }
                    SpinBox {
                        id: cleanup_delaySpinBox
                        to: 1e9
                        value: 0
                        enabled: !cleanup_delayCheckbox.checked
                    }
                    CheckBox {
                        id: cleanup_delayCheckbox
                        checked: false
                        text: qsTr("infinite")
                    }
                }
                Column {
                    Label {
                        text: "History"
                    }
                    Column {
                        ComboBox {
                            id: durabilityServiceHistoryComboId
                            model: ["KeepLast", "KeepAll"]
                            width: readerTesterDiaId.width - 30
                        }
                        Row {
                            Label {
                                text: "depth"
                                enabled: durabilityServiceHistoryComboId.currentText === "KeepLast"
                            }
                            SpinBox {
                                id: durabilityServiceKeepLastSpinBox
                                to: 1e9
                                value: 1
                                enabled: durabilityServiceHistoryComboId.currentText === "KeepLast"
                            }
                        }
                    }
                    Row {
                        Label {
                            text: "max_samples"
                        }
                        SpinBox {
                            id: durabilityServiceMaxSamplesSpinBox
                            to: 1e9
                            from: -1
                            value: -1
                        }
                    }
                    Row {
                        Label {
                            text: "max_instances"
                        }
                        SpinBox {
                            id: durabilityServiceMaxInstancesSpinBox
                            to: 1e9
                            from: -1
                            value: -1
                        }
                    }
                    Row {
                        Label {
                            text: "max_samples_per_instance"
                        }
                        SpinBox {
                            id: durabilityServiceMaxSamplesPerInstanceSpinBox
                            to: 1e9
                            from: -1
                            value: -1
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
                    reliabilitySpinBox.value,
                    dataReprXcdr1Checkbox.checked,
                    dataReprXcdr2Checkbox.checked,
                    partitions,
                    typeConsistencyComboId.currentText,
                    allowTypeCoercion_ignore_sequence_bounds.checked,
                    allowTypeCoercion_ignore_string_bounds.checked,
                    allowTypeCoercion_ignore_member_names.checked,
                    allowTypeCoercion_prevent_type_widening.checked,
                    allowTypeCoercion_force_type_validation.checked,
                    disallowTypeCoercionForce_type_validationCheckbox.checked,
                    historyComboId.currentText,
                    keepLastSpinBox.value,
                    destinationOrderComboId.currentText,
                    livelinessComboId.currentText,
                    livelinessCheckbox.checked ? -1 : livelinessSpinBox.value,
                    lifespanCheckbox.checked ? -1 : lifespanSpinBox.value,
                    deadlineCheckbox.checked ? -1 : deadlineSpinBox.value,
                    latencyBudgetCheckbox.checked ? -1 : latencyBudgetSpinBox.value,
                    ownershipStrengthSpinBox.value,
                    presentationAccessScopeComboId.currentText,
                    coherent_accessCheckbox.checked,
                    ordered_accessCheckbox.checked,
                    writerDataLifecycleCheckbox.checked,
                    autopurge_nowriter_samples_delayCheckbox.checked ? -1 : autopurge_nowriter_samples_delaySpinBox.value,
                    autopurge_disposed_samples_delaySpinBoxCheckbox.checked ? -1 : autopurge_disposed_samples_delaySpinBox.value,
                    transportPrioritySpinBox.value,
                    max_samplesSpinBox.value,
                    max_instancesSpinBox.value,
                    max_samples_per_instanceSpinBox.value,
                    timeBasedFilterSpinBox.value,
                    ignoreLocalComboId.currentText,
                    userdataField.text,
                    groupdataField.text,
                    entityNameField.text,
                    propertyKeyField.text,
                    propertyValueField.text,
                    binaryPropertyKeyField.text,
                    binaryPropertyValueField.text,
                    cleanup_delayCheckbox.checked ? -1 : cleanup_delaySpinBox.value,
                    durabilityServiceHistoryComboId.currentText,
                    durabilityServiceKeepLastSpinBox.value,
                    durabilityServiceMaxSamplesSpinBox.value,
                    durabilityServiceMaxInstancesSpinBox.value,
                    durabilityServiceMaxSamplesPerInstanceSpinBox.value
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
