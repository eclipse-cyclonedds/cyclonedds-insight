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
    property var model: null

    anchors.centerIn: parent
    modal: true
    x: (rootWindow.width - width) / 2
    y: (rootWindow.height - height) / 2

    width: 600
    height: 400

    property int domainId: 0
    property string topicType
    property int entityType

    Component.onCompleted: {
        console.log("Reader", readerTesterDiaId.topicType)
    }
    property string topicName
    property var topicTypeNameList: []
    property string selectedTypeText: ""
    property string buttonName: ""

    function setType(topicType, entityType) {
        topicTypeNameList = []
        topicName = topicType.replace(/::/g, "_");
        readerTesterDiaId.topicType = topicType
        readerTesterDiaId.entityType = entityType

        setButtonNameDefault()
    }

    function setTypes(domain, name, typeList, entityType) {
        readerTesterDiaId.domainId = domain
        readerTesterDiaId.topicName = name
        readerTesterDiaId.topicTypeNameList = typeList
        readerTesterDiaId.entityType = entityType
        domainIdTextField.text = domain

        setButtonNameDefault()
    }

    function setButtonName(name) {
        buttonName = name
    }

    function setButtonNameDefault() {
        buttonName = readerTesterDiaId.entityType === 3 ? qsTr("Create Reader (Listener)") : qsTr("Create Writer (Tester)")
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
            id: lay
            width: parent.width
            spacing: 5

            Label {
                text: readerTesterDiaId.entityType === 3 ? "Create Reader" : "Create Writer"
                font.bold: true
                font.pixelSize: 30
            }

            Label {
                text: "Domain"
                font.bold: true
            }
            TextField {
                id: domainIdTextField
                text: "0"
                validator: IntValidator {
                    bottom: 0
                    top: 232
                }
                focus: true
                onTextChanged: {
                    if (domainIdTextField.text > 232) {
                        domainIdTextField.text = 232
                    }
                }
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
                text: "Quality of Service (QoS)"
                font.bold: true
            }
            TabBar {
                id: bar
                width: readerTesterDiaId.width - 40

                TabButton {
                    text: readerTesterDiaId.entityType === 3 ? qsTr("Reader") : qsTr("Writer")
                }
                TabButton {
                    text: readerTesterDiaId.entityType === 3 ? qsTr("Subscriber") : qsTr("Publisher")
                }
                TabButton {
                    text: qsTr("Topic")
                }
                /*TabButton {
                    text: qsTr("Participant")
                }*/
            }

            StackLayout {
                id: mainLayoutId
                width: readerTesterDiaId.width - 40
                currentIndex: bar.currentIndex
                height: {
                    let child = mainLayoutId.children[mainLayoutId.currentIndex];
                    return child && child.implicitHeight > 0 ? child.implicitHeight : 0;
                }

                Item {
                    id: endpointTab
                    implicitHeight: endpointTabCol.implicitHeight

                    Column {
                        id: endpointTabCol

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
                                    enabled: !reliabilityCheckbox.checked
                                }
                                CheckBox {
                                    id: reliabilityCheckbox
                                    checked: false
                                    text: qsTr("infinite")
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
                            visible: readerTesterDiaId.entityType === 3
                            text: "TypeConsistency"
                            font.bold: true
                        }
                        Column {
                            visible: readerTesterDiaId.entityType === 3
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
                                        checked: false
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
                                    from: 1
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
                            visible: readerTesterDiaId.entityType === 4
                            text: "Lifespan"
                            font.bold: true
                        }
                        Row {
                            visible: readerTesterDiaId.entityType === 4
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
                            visible: readerTesterDiaId.entityType === 4
                            text: "OwnershipStrength"
                            font.bold: true
                        }
                        SpinBox {
                            visible: readerTesterDiaId.entityType === 4
                            id: ownershipStrengthSpinBox
                            to: 1e9
                            value: 0
                        }

                        Label {
                            visible: readerTesterDiaId.entityType === 4
                            text: "WriterDataLifecycle"
                            font.bold: true
                        }
                        CheckBox {
                            visible: readerTesterDiaId.entityType === 4
                            id: writerDataLifecycleCheckbox
                            checked: true
                            text: qsTr("autodispose")
                        }

                        Label {
                            visible: readerTesterDiaId.entityType === 3
                            text: "ReaderDataLifecycle"
                            font.bold: true
                        }
                        Column {
                            visible: readerTesterDiaId.entityType === 3
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
                            visible: readerTesterDiaId.entityType === 3
                            text: "TimeBasedFilter"
                            font.bold: true
                        }
                        Row {
                            visible: readerTesterDiaId.entityType === 3
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
                            visible: readerTesterDiaId.entityType === 4
                            text: "DurabilityService"
                            font.bold: true
                        }
                        Column {
                            visible: readerTesterDiaId.entityType === 4
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
                                            from: 1
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

                        Label {
                            text: "UserData"
                            font.bold: true
                        }
                        TextField {
                            leftPadding: 10
                            id: userdataField
                            placeholderText: "Enter Userdata"
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
                            Switch {
                                id: prop_propagate
                                text: qsTr("Propagate")
                                checked: false
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
                            Switch {
                                id: bin_prop_propagate
                                text: qsTr("Propagate")
                                checked: false
                            }
                        }
                    }
                }

                Item {
                    id: pubSubTab
                    implicitHeight: pubSubTabCol.implicitHeight

                    Column {
                        id: pubSubTabCol
                        
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
                            text: "Presentation"
                            font.bold: true
                        }
                        Column {
                            ComboBox {
                                id: pubSubPresentationAccessScopeComboId
                                model: ["Instance", "Topic", "Group"]
                                width: readerTesterDiaId.width - 30
                            }
                            Row {
                                CheckBox {
                                    id: pubSubCoherent_accessCheckbox
                                    checked: false
                                    text: qsTr("coherent_access")
                                }
                                CheckBox {
                                    id: pubSubOrdered_accessCheckbox
                                    checked: false
                                    text: qsTr("ordered_access")
                                }
                            }
                        }

                        Label {
                            text: "Groupdata"
                            font.bold: true
                        }
                        TextField {
                            leftPadding: 10
                            id: puSubGroupdataField
                            placeholderText: "Enter Groupdata"
                            text: ""
                        }

                        Label {
                            text: "UserData"
                            font.bold: true
                        }
                        TextField {
                            leftPadding: 10
                            id: pubSubUserdataField
                            placeholderText: "Enter Userdata"
                            text: ""
                        }

                        Label {
                            text: "EntityFactory"
                            enabled: false
                            font.bold: true
                        }
                        CheckBox {
                            id: pubSubEntityFactoryAutoenableCreatedEntitiesCheckbox
                            enabled: false
                            checked: true
                            text: "autoenable_created_entities"
                        }
                    }
                }

                Item {
                    id: topicTab
                    implicitHeight: topicTabCol.implicitHeight

                    Column {
                        id: topicTabCol

                        Label {
                            text: "Reliability"
                            font.bold: true
                        }
                        Column {
                            ComboBox {
                                id: topicQosReliabilityComboId
                                model: ["DDS_RELIABILITY_BEST_EFFORT", "DDS_RELIABILITY_RELIABLE"]
                                width: readerTesterDiaId.width - 30
                            }
                            Row {
                                visible: topicQosReliabilityComboId.currentText === "DDS_RELIABILITY_RELIABLE" 
                                Label {
                                    text: "max_blocking_time in milliseconds: "
                                }
                                SpinBox {
                                    id: topicQosReliabilitySpinBox
                                    to: 1e9
                                    value: 100
                                    enabled: !topicQosReliabilityCheckbox.checked
                                }
                                CheckBox {
                                    id: topicQosReliabilityCheckbox
                                    checked: false
                                    text: qsTr("infinite")
                                }
                            }
                        }

                        Label {
                            text: "Durability"
                            font.bold: true
                        }
                        ComboBox {
                            id: topicQosDurabilityComboId
                            model: ["DDS_DURABILITY_VOLATILE", "DDS_DURABILITY_TRANSIENT_LOCAL", "DDS_DURABILITY_TRANSIENT", "DDS_DURABILITY_PERSISTENT"]
                            width: readerTesterDiaId.width - 30
                        }

                        Label {
                            text: "Ownership"
                            font.bold: true
                        }
                        ComboBox {
                            id: topicQosOwnershipComboId
                            model: ["DDS_OWNERSHIP_SHARED", "DDS_OWNERSHIP_EXCLUSIVE"]
                            width: readerTesterDiaId.width - 30
                        }



                        Label {
                            text: "DataRepresentation"
                            font.bold: true
                        }
                        Row {
                            CheckBox {
                                id: topicQosDataReprDefaultCheckbox
                                checked: true
                                text: qsTr("Default")
                                onCheckedChanged: {
                                    if (checked) {
                                        topicQosDataReprXcdr1Checkbox.checked = false;
                                        topicQosDataReprXcdr2Checkbox.checked = false;
                                    }
                                    if (!topicQosDataReprXcdr1Checkbox.checked && !topicQosDataReprXcdr2Checkbox.checked) {
                                        checked = true;
                                    }
                                }
                            }
                            CheckBox {
                                id: topicQosDataReprXcdr1Checkbox
                                checked: false
                                text: qsTr("XCDR1")
                                onCheckedChanged: {
                                    if (checked) {
                                        topicQosDataReprDefaultCheckbox.checked = false;
                                    } else {
                                        if (!topicQosDataReprXcdr2Checkbox.checked) {
                                            topicQosDataReprDefaultCheckbox.checked = true;
                                        }
                                    }
                                }
                            }
                            CheckBox {
                                id: topicQosDataReprXcdr2Checkbox
                                checked: false
                                text: qsTr("XCDR2")
                                onCheckedChanged: {
                                    if (checked) {
                                        topicQosDataReprDefaultCheckbox.checked = false;
                                    } else {
                                        if (!topicQosDataReprXcdr1Checkbox.checked) {
                                            topicQosDataReprDefaultCheckbox.checked = true;
                                        }
                                    }
                                }
                            }
                        }
                        
                        Label {
                            text: "History"
                            font.bold: true
                        }
                        Column {
                            ComboBox {
                                id: topicQosHistoryComboId
                                model: ["KeepLast", "KeepAll"]
                                width: readerTesterDiaId.width - 30
                            }
                            Row {
                                Label {
                                    text: "depth"
                                    visible: topicQosHistoryComboId.currentText === "KeepLast"
                                }
                                SpinBox {
                                    id: topicQosKeepLastSpinBox
                                    from: 1
                                    to: 1e9
                                    value: 1
                                    visible: topicQosHistoryComboId.currentText === "KeepLast"
                                }
                            }
                        }

                        Label {
                            text: "DestinationOrder"
                            font.bold: true
                        }
                        ComboBox {
                            id: topicQosDestinationOrderComboId
                            model: ["ByReceptionTimestamp", "BySourceTimestamp"]
                            width: readerTesterDiaId.width - 30
                        }

                        Label {
                            text: "Liveliness"
                            font.bold: true
                        }
                        Column {
                            ComboBox {
                                id: topicQosLivelinessComboId
                                model: ["Automatic", "ManualByParticipant", "ManualByTopic"]
                                width: readerTesterDiaId.width - 30
                            }
                            Row {
                                Label {
                                    text: "Seconds: "
                                }
                                SpinBox {
                                    id: topicQosLivelinessSpinBox
                                    to: 1e9
                                    value: 1
                                    enabled: !topicQosLivelinessCheckbox.checked
                                }
                                CheckBox {
                                    id: topicQosLivelinessCheckbox
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
                                id: topicQosLifespanSpinBox
                                to: 1e9
                                value: 2
                                enabled: !topicQosLifespanCheckbox.checked
                            }
                            CheckBox {
                                id: topicQosLifespanCheckbox
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
                                id: topicQosDeadlineSpinBox
                                to: 1e9
                                value: 2
                                enabled: !topicQosDeadlineCheckbox.checked
                            }
                            CheckBox {
                                id: topicQosDeadlineCheckbox
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
                                id: topicQosLatencyBudgetSpinBox
                                to: 1e9
                                value: 0
                                enabled: !topicQosLatencyBudgetCheckbox.checked
                            }
                            CheckBox {
                                id: topicQosLatencyBudgetCheckbox
                                checked: false
                                text: qsTr("infinite")
                            }
                        }

                        Label {
                            text: "TransportPriority"
                            font.bold: true
                        }
                        SpinBox {
                            id: topicQosTransportPrioritySpinBox
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
                                    id: topicQosMax_samplesSpinBox
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
                                    id: topicQosMax_instancesSpinBox
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
                                    id: topicQosMax_samples_per_instanceSpinBox
                                    from: -1
                                    to: 1e9
                                    value: -1
                                }
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
                                    id: topicQosCleanup_delaySpinBox
                                    to: 1e9
                                    value: 0
                                    enabled: !topicQosCleanup_delayCheckbox.checked
                                }
                                CheckBox {
                                    id: topicQosCleanup_delayCheckbox
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
                                        id: topicQosDurabilityServiceHistoryComboId
                                        model: ["KeepLast", "KeepAll"]
                                        width: readerTesterDiaId.width - 30
                                    }
                                    Row {
                                        Label {
                                            text: "depth"
                                            enabled: topicQosDurabilityServiceHistoryComboId.currentText === "KeepLast"
                                        }
                                        SpinBox {
                                            id: topicQosDurabilityServiceKeepLastSpinBox
                                            from: 1
                                            to: 1e9
                                            value: 1
                                            enabled: topicQosDurabilityServiceHistoryComboId.currentText === "KeepLast"
                                        }
                                    }
                                }
                                Row {
                                    Label {
                                        text: "max_samples"
                                    }
                                    SpinBox {
                                        id: topicQosDurabilityServiceMaxSamplesSpinBox
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
                                        id: topicQosDurabilityServiceMaxInstancesSpinBox
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
                                        id: topicQosDurabilityServiceMaxSamplesPerInstanceSpinBox
                                        to: 1e9
                                        from: -1
                                        value: -1
                                    }
                                }
                            }
                        }

                        Label {
                            text: "TopicData"
                            font.bold: true
                        }
                        TextField {
                            leftPadding: 10
                            id: topicQosDataField
                            placeholderText: "Enter TopicData"
                            text: ""
                        }
                    }
                }

                Item {
                    id: participantTab
                    implicitHeight: participantTabCol.implicitHeight

                    Column {
                        id: participantTabCol

                        Label {
                            text: "Participant Handling"
                            font.bold: true
                        }
                        CheckBox {
                            id: dpReuseParticipantCheckbox
                            checked: true
                            text: "Use the default participant (otherwise create a new one)"
                        }

                        Label {
                            visible: !dpReuseParticipantCheckbox.checked
                            text: "UserData"
                            font.bold: true
                        }
                        TextField {
                            visible: !dpReuseParticipantCheckbox.checked
                            leftPadding: 10
                            id: dpUserdataField
                            placeholderText: "Enter Userdata"
                            text: ""
                        }

                        Label {
                            text: "EntityFactory"
                            enabled: false
                            visible: !dpReuseParticipantCheckbox.checked
                            font.bold: true
                        }
                        CheckBox {
                            id: dpEntityFactoryAutoenableCreatedEntitiesCheckbox
                            enabled: false
                            checked: true
                            visible: !dpReuseParticipantCheckbox.checked
                            text: "autoenable_created_entities"
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
            text: buttonName
            onClicked: {
                var pubSubPartitions = [];
                for (var i = 0; i < partitionModel.count; i++) {
                    pubSubPartitions.push(partitionModel.get(i).partition);
                }
                model.setQosSelection(
                    // General
                    domainIdTextField.text,
                    topicNameTextFieldId.text,
                    topicType,
                    entityType,

                    // Reader/Writer
                    ownershipComboId.currentText,
                    durabilityComboId.currentText,
                    reliabilityComboId.currentText,
                    reliabilityCheckbox.checked ? -1 : reliabilitySpinBox.value,
                    dataReprXcdr1Checkbox.checked,
                    dataReprXcdr2Checkbox.checked,
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
                    entityNameField.text,
                    propertyKeyField.text,
                    propertyValueField.text,
                    prop_propagate.checked,
                    binaryPropertyKeyField.text,
                    binaryPropertyValueField.text,
                    bin_prop_propagate.checked,
                    cleanup_delayCheckbox.checked ? -1 : cleanup_delaySpinBox.value,
                    durabilityServiceHistoryComboId.currentText,
                    durabilityServiceKeepLastSpinBox.value,
                    durabilityServiceMaxSamplesSpinBox.value,
                    durabilityServiceMaxInstancesSpinBox.value,
                    durabilityServiceMaxSamplesPerInstanceSpinBox.value,

                    // Pub/Sub
                    pubSubPartitions,
                    pubSubPresentationAccessScopeComboId.currentText,
                    pubSubCoherent_accessCheckbox.checked,
                    pubSubOrdered_accessCheckbox.checked,
                    puSubGroupdataField.text,

                    // Topic
                    topicQosOwnershipComboId.currentText,
                    topicQosDurabilityComboId.currentText,
                    topicQosReliabilityComboId.currentText,
                    topicQosReliabilityCheckbox.checked ? -1 : topicQosReliabilitySpinBox.value,
                    topicQosDataReprXcdr1Checkbox.checked,
                    topicQosDataReprXcdr2Checkbox.checked,
                    topicQosHistoryComboId.currentText,
                    topicQosKeepLastSpinBox.value,
                    topicQosDestinationOrderComboId.currentText,
                    topicQosLivelinessComboId.currentText,
                    topicQosLivelinessCheckbox.checked ? -1 : topicQosLivelinessSpinBox.value,
                    topicQosLifespanCheckbox.checked ? -1 : topicQosLifespanSpinBox.value,
                    topicQosDeadlineCheckbox.checked ? -1 : topicQosDeadlineSpinBox.value,
                    topicQosLatencyBudgetCheckbox.checked ? -1 : topicQosLatencyBudgetSpinBox.value,
                    topicQosTransportPrioritySpinBox.value,
                    topicQosMax_samplesSpinBox.value,
                    topicQosMax_instancesSpinBox.value,
                    topicQosMax_samples_per_instanceSpinBox.value,
                    topicQosDataField.text,
                    topicQosCleanup_delayCheckbox.checked ? -1 : topicQosCleanup_delaySpinBox.value,
                    topicQosDurabilityServiceHistoryComboId.currentText,
                    topicQosDurabilityServiceKeepLastSpinBox.value,
                    topicQosDurabilityServiceMaxSamplesSpinBox.value,
                    topicQosDurabilityServiceMaxInstancesSpinBox.value,
                    topicQosDurabilityServiceMaxSamplesPerInstanceSpinBox.value,

                    // Participant
                    dpReuseParticipantCheckbox.checked,
                    dpUserdataField.text,
                    dpEntityFactoryAutoenableCreatedEntitiesCheckbox.checked
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
