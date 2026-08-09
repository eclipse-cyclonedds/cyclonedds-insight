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
import QtQuick.Dialogs

import org.eclipse.cyclonedds.insight
import "qrc:/src/views/selection_details"


Popup {
    id: readerTesterDiaId
    property var model: null

    anchors.centerIn: parent
    modal: true
    x: (rootWindow.width - width) / 2
    y: (rootWindow.height - height) / 2

    width: 600
    height: 400
    padding: 0

    property int domainId: 0
    property string topicType
    property int entityType
    property int qosSourceIndex: 0
    property int qosPolicyIndex: 0
    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    readonly property color borderColor: rootWindow.isDarkMode
                                         ? "#505050" : "#d5d5d5"
    readonly property color secondaryTextColor: rootWindow.isDarkMode
                                                ? "#c8c8c8" : "#555555"

    background: Rectangle {
        radius: 10
        color: Constants.mainContentColor(rootWindow.isDarkMode)
        border.width: 1
        border.color: readerTesterDiaId.borderColor
    }

    Component.onCompleted: {
        console.log("Reader", readerTesterDiaId.topicType)
    }
    property string topicName
    property var topicTypeNameList: []
    property string selectedTypeText: ""
    property string buttonName: ""
    property string qosProviderFilePath: ""
    property var qosProviderKeys: []

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
        buttonName = readerTesterDiaId.entityType === 3 ? qsTrId("listener.create.reader") : qsTrId("tester.create.writer")
    }

    ListModel {
        id: partitionModel
    }

    ScrollView {
        id: qosScrollView
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: buttonRow.top
        anchors.topMargin: 14
        anchors.leftMargin: 16
        anchors.rightMargin: 10
        anchors.bottomMargin: 8
        clip: true
        contentWidth: availableWidth

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
            id: lay
            width: qosScrollView.availableWidth
            spacing: 10

            Row {
                spacing: 9

                DetailBadge {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "qos"
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: readerTesterDiaId.entityType === 3
                          ? qsTrId("qos.create.reader")
                          : qsTrId("qos.create.writer")
                    font.bold: true
                    font.pixelSize: Constants.pageTitleFontSize
                }
            }

            Rectangle {
                width: parent.width
                implicitHeight: endpointBasics.implicitHeight + 20
                radius: Constants.cardRadius
                color: readerTesterDiaId.surfaceColor
                border.width: 1
                border.color: readerTesterDiaId.borderColor

                GridLayout {
                    id: endpointBasics
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 7

                    Label {
                        Layout.row: 0
                        Layout.column: 0
                        text: qsTrId("qos.domain")
                        color: readerTesterDiaId.secondaryTextColor
                    }
                    TextField {
                        id: domainIdTextField
                        Layout.row: 0
                        Layout.column: 1
                        Layout.fillWidth: true
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
                        Layout.row: 1
                        Layout.column: 0
                        text: qsTrId("qos.topic.type")
                        color: readerTesterDiaId.secondaryTextColor
                    }
                    ComboBox {
                        id: typeComboBox
                        Layout.row: 1
                        Layout.column: 1
                        Layout.fillWidth: true
                        model: topicTypeNameList
                        visible: topicTypeNameList.length !== 0
                        onCurrentTextChanged: {
                            topicType = typeComboBox.currentText
                        }
                    }
                    Label {
                        Layout.row: 1
                        Layout.column: 1
                        Layout.fillWidth: true
                        text: readerTesterDiaId.topicType
                        visible: topicTypeNameList.length === 0
                        wrapMode: Text.WrapAnywhere
                        color: readerTesterDiaId.secondaryTextColor
                    }

                    Label {
                        Layout.row: 2
                        Layout.column: 0
                        text: qsTrId("qos.topic.name")
                        color: readerTesterDiaId.secondaryTextColor
                    }
                    TextField {
                        id: topicNameTextFieldId
                        Layout.row: 2
                        Layout.column: 1
                        Layout.fillWidth: true
                        text: topicName
                    }
                }
            }

            Label {
                text: qsTrId("qos.title")
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: 38
                radius: 7
                color: rootWindow.isDarkMode ? "#292929" : "#ededed"
                border.width: 1
                border.color: readerTesterDiaId.borderColor

                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    Repeater {
                        model: [
                            qsTrId("qos.provider.source.manual"),
                            qsTrId("qos.provider.source.provider")
                        ]

                        Rectangle {
                            id: sourceOption
                            required property int index
                            required property string modelData
                            readonly property bool selected:
                                readerTesterDiaId.qosSourceIndex === index

                            width: (parent.width - 3) / 2
                            height: parent.height
                            radius: 5
                            color: selected
                                   ? readerTesterDiaId.surfaceColor
                                   : sourceMouseArea.containsMouse
                                     ? rootWindow.isDarkMode
                                       ? "#3a3a3a" : "#dfdfdf"
                                     : "transparent"
                            border.width: selected ? 1 : 0
                            border.color: readerTesterDiaId.borderColor

                            Label {
                                anchors.centerIn: parent
                                text: sourceOption.modelData
                                font.bold: sourceOption.selected
                            }

                            MouseArea {
                                id: sourceMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked:
                                    readerTesterDiaId.qosSourceIndex =
                                        sourceOption.index
                            }
                        }
                    }
                }
            }

            Column {
                visible: readerTesterDiaId.qosSourceIndex === 0
                width: parent.width
                spacing: -1

                Row {
                    width: parent.width
                    height: 32
                    spacing: 3
                    z: 2

                    Repeater {
                        model: [
                            readerTesterDiaId.entityType === 3
                            ? qsTrId("entity.reader") : qsTrId("entity.writer"),
                            readerTesterDiaId.entityType === 3
                            ? qsTrId("entity.subscriber") : qsTrId("entity.publisher"),
                            qsTrId("entity.topic")
                        ]

                        Rectangle {
                            id: policyTab
                            required property int index
                            required property string modelData
                            readonly property bool selected:
                                readerTesterDiaId.qosPolicyIndex === index

                            width: (parent.width - 6) / 3
                            height: selected ? 33 : 29
                            y: selected ? 0 : 3
                            radius: Constants.controlRadius
                            color: selected
                                   ? readerTesterDiaId.surfaceColor
                                   : policyTabMouseArea.containsMouse
                                     ? rootWindow.isDarkMode
                                       ? "#3b3b3b" : "#e1e1e1"
                                     : rootWindow.isDarkMode
                                       ? "#303030" : "#ebebeb"
                            border.width: 1
                            border.color: selected
                                          ? readerTesterDiaId.borderColor
                                          : rootWindow.isDarkMode
                                            ? "#454545" : "#d3d3d3"

                            Rectangle {
                                visible: policyTab.selected
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 1
                                anchors.rightMargin: 1
                                height: 2
                                color: readerTesterDiaId.surfaceColor
                            }

                            Label {
                                anchors.centerIn: parent
                                text: policyTab.modelData
                                font.bold: policyTab.selected
                            }

                            MouseArea {
                                id: policyTabMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked:
                                    readerTesterDiaId.qosPolicyIndex =
                                        policyTab.index
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    implicitHeight: mainLayoutId.height + 20
                    radius: Constants.cardRadius
                    color: readerTesterDiaId.surfaceColor
                    border.width: 1
                    border.color: readerTesterDiaId.borderColor
                    z: 1

                    StackLayout {
                        id: mainLayoutId
                        y: 8
                        width: parent.width
                        currentIndex: readerTesterDiaId.qosPolicyIndex
                        height: {
                            let child =
                                mainLayoutId.children[
                                    mainLayoutId.currentIndex]
                            return child && child.implicitHeight > 0
                                    ? child.implicitHeight : 0
                        }

                        Item {
                            id: endpointTab
                            implicitHeight: endpointTabCol.implicitHeight

                            Column {
                                id: endpointTabCol

                        Label {
                            text: qsTrId("qos.reliability")
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
                                    text: qsTrId("qos.max.blocking.ms")
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
                                    text: qsTrId("infinite")
                                }
                            }
                        }

                        Label {
                            text: qsTrId("qos.durability")
                            font.bold: true
                        }
                        ComboBox {
                            id: durabilityComboId
                            model: ["DDS_DURABILITY_VOLATILE", "DDS_DURABILITY_TRANSIENT_LOCAL", "DDS_DURABILITY_TRANSIENT", "DDS_DURABILITY_PERSISTENT"]
                            width: readerTesterDiaId.width - 30
                        }

                        Label {
                            text: qsTrId("qos.ownership")
                            font.bold: true
                        }
                        ComboBox {
                            id: ownershipComboId
                            model: ["DDS_OWNERSHIP_SHARED", "DDS_OWNERSHIP_EXCLUSIVE"]
                            width: readerTesterDiaId.width - 30
                        }



                        Label {
                            text: qsTrId("qos.data.representation")
                            font.bold: true
                        }
                        Row {
                            CheckBox {
                                id: dataReprDefaultCheckbox
                                checked: true
                                text: qsTrId("general.default")
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
                                text: "XCDR1"
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
                                text: "XCDR2"
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
                            text: qsTrId("qos.type.consistency")
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
                                        text: qsTrId("ignore_sequence_bounds")
                                    }
                                    CheckBox {
                                        id: allowTypeCoercion_ignore_string_bounds
                                        checked: true
                                        text: qsTrId("ignore_string_bounds")
                                    }
                                    CheckBox {
                                        id: allowTypeCoercion_ignore_member_names
                                        checked: false
                                        text: qsTrId("ignore_member_names")
                                    }
                                }
                                Row {
                                    CheckBox {
                                        id: allowTypeCoercion_prevent_type_widening
                                        checked: false
                                        text: qsTrId("prevent_type_widening")
                                    }
                                    CheckBox {
                                        id: allowTypeCoercion_force_type_validation
                                        checked: false
                                        text: qsTrId("force_type_validation")
                                    }
                                }
                            }

                            CheckBox {
                                id: disallowTypeCoercionForce_type_validationCheckbox
                                checked: false
                                text: qsTrId("force_type_validation")
                                visible: typeConsistencyComboId.currentText === "DisallowTypeCoercion" 
                            }
                        }

                        Label {
                            text: qsTrId("qos.history")
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
                            text: qsTrId("qos.destination.order")
                            font.bold: true
                        }
                        ComboBox {
                            id: destinationOrderComboId
                            model: ["ByReceptionTimestamp", "BySourceTimestamp"]
                            width: readerTesterDiaId.width - 30
                        }

                        Label {
                            text: qsTrId("qos.liveliness")
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
                                    text: qsTrId("qos.seconds")
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
                                    text: qsTrId("infinite")
                                }
                            }
                        }

                        Label {
                            visible: readerTesterDiaId.entityType === 4
                            text: qsTrId("qos.lifespan")
                            font.bold: true
                        }
                        Row {
                            visible: readerTesterDiaId.entityType === 4
                            Label {
                                text: qsTrId("qos.seconds")
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
                                text: qsTrId("infinite")
                            }
                        }

                        Label {
                            text: qsTrId("qos.deadline")
                            font.bold: true
                        }
                        Row {
                            Label {
                                text: qsTrId("qos.seconds")
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
                                text: qsTrId("infinite")
                            }
                        }

                        Label {
                            text: qsTrId("qos.latency.budget")
                            font.bold: true
                        }
                        Row {
                            Label {
                                text: qsTrId("qos.seconds")
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
                                text: qsTrId("infinite")
                            }
                        }

                        Label {
                            visible: readerTesterDiaId.entityType === 4
                            text: qsTrId("qos.ownership.strength")
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
                            text: qsTrId("qos.writer.lifecycle")
                            font.bold: true
                        }
                        CheckBox {
                            visible: readerTesterDiaId.entityType === 4
                            id: writerDataLifecycleCheckbox
                            checked: true
                            text: qsTrId("autodispose")
                        }

                        Label {
                            visible: readerTesterDiaId.entityType === 3
                            text: qsTrId("qos.reader.lifecycle")
                            font.bold: true
                        }
                        Column {
                            visible: readerTesterDiaId.entityType === 3
                            Row {
                                Label {
                                    text: qsTrId("qos.autopurge.nowriter.min")
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
                                    text: qsTrId("infinite")
                                }
                            }
                            Row {
                                Label {
                                    text: qsTrId("qos.autopurge.disposed.min")
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
                                    text: qsTrId("infinite")
                                }
                            }

                        }

                        Label {
                            text: qsTrId("qos.transport.priority")
                            font.bold: true
                        }
                        SpinBox {
                            id: transportPrioritySpinBox
                            to: 1e9
                            value: 0
                        }
                        
                        Label {
                            text: qsTrId("qos.resource.limits")
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
                            text: qsTrId("qos.time.filter")
                            font.bold: true
                        }
                        Row {
                            visible: readerTesterDiaId.entityType === 3
                            Label {
                                text: qsTrId("qos.filter.seconds")
                            }
                            SpinBox {
                                id: timeBasedFilterSpinBox
                                to: 1e9
                                value: 0
                            }
                        }

                        Label {
                            text: qsTrId("qos.ignore.local")
                            font.bold: true
                        }
                        ComboBox {
                            id: ignoreLocalComboId
                            model: ["Nothing", "Participant", "Process"]
                            width: readerTesterDiaId.width - 30
                        }

                        Label {
                            visible: readerTesterDiaId.entityType === 4
                            text: qsTrId("qos.durability.service")
                            font.bold: true
                        }
                        Column {
                            visible: readerTesterDiaId.entityType === 4
                            Row {
                                Label {
                                    text: qsTrId("qos.cleanup.minutes")
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
                                    text: qsTrId("infinite")
                                }
                            }
                            Column {
                                Label {
                                    text: qsTrId("qos.history")
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
                            text: qsTrId("qos.user.data")
                            font.bold: true
                        }
                        TextField {
                            leftPadding: 10
                            id: userdataField
                            placeholderText: qsTrId("placeholder.userdata")
                            text: ""
                        }

                        Label {
                            text: qsTrId("qos.entity.name")
                            font.bold: true
                        }
                        TextField {
                            leftPadding: 10
                            id: entityNameField
                            placeholderText: qsTrId("placeholder.entity.name")
                            text: ""
                        }

                        Label {
                            text: qsTrId("qos.property")
                            font.bold: true
                        }
                        Row {
                            TextField {
                                leftPadding: 10
                                id: propertyKeyField
                                placeholderText: qsTrId("placeholder.key")
                                text: ""
                            }
                            TextField {
                                leftPadding: 10
                                id: propertyValueField
                                placeholderText: qsTrId("placeholder.value")
                                text: ""
                            }
                            Switch {
                                id: prop_propagate
                            text: qsTrId("qos.propagate")
                                checked: false
                            }
                        }

                        Label {
                            text: qsTrId("qos.binary.property")
                            font.bold: true
                        }
                        Row {
                            TextField {
                                leftPadding: 10
                                id: binaryPropertyKeyField
                                placeholderText: qsTrId("placeholder.key")
                                text: ""
                            }
                            TextField {
                                leftPadding: 10
                                id: binaryPropertyValueField
                                placeholderText: qsTrId("placeholder.value")
                                text: ""
                            }
                            Switch {
                                id: bin_prop_propagate
                            text: qsTrId("qos.propagate")
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
                                text: qsTrId("qos.partitions")
                                font.bold: true
                            }

                            Button {
                                text: qsTrId("qos.partition.add")
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
                                    placeholderText: qsTrId("placeholder.partition")
                                    text: modelData
                                    onTextChanged: partitionModel.set(index, {"partition": text})
                                }
                                Button {
                                    text: qsTrId("general.remove")
                                    onClicked: partitionModel.remove(index)
                                }
                            }
                        }

                        Label {
                            text: qsTrId("qos.presentation")
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
                                    text: qsTrId("coherent_access")
                                }
                                CheckBox {
                                    id: pubSubOrdered_accessCheckbox
                                    checked: false
                                    text: qsTrId("ordered_access")
                                }
                            }
                        }

                        Label {
                            text: qsTrId("qos.group.data")
                            font.bold: true
                        }
                        TextField {
                            leftPadding: 10
                            id: puSubGroupdataField
                            placeholderText: qsTrId("placeholder.groupdata")
                            text: ""
                        }

                        Label {
                            text: qsTrId("qos.user.data")
                            font.bold: true
                        }
                        TextField {
                            leftPadding: 10
                            id: pubSubUserdataField
                            placeholderText: qsTrId("placeholder.userdata")
                            text: ""
                        }

                        Label {
                            text: qsTrId("qos.entity.factory")
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
                            text: qsTrId("qos.reliability")
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
                                    text: qsTrId("qos.max.blocking.ms")
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
                                    text: qsTrId("infinite")
                                }
                            }
                        }

                        Label {
                            text: qsTrId("qos.durability")
                            font.bold: true
                        }
                        ComboBox {
                            id: topicQosDurabilityComboId
                            model: ["DDS_DURABILITY_VOLATILE", "DDS_DURABILITY_TRANSIENT_LOCAL", "DDS_DURABILITY_TRANSIENT", "DDS_DURABILITY_PERSISTENT"]
                            width: readerTesterDiaId.width - 30
                        }

                        Label {
                            text: qsTrId("qos.ownership")
                            font.bold: true
                        }
                        ComboBox {
                            id: topicQosOwnershipComboId
                            model: ["DDS_OWNERSHIP_SHARED", "DDS_OWNERSHIP_EXCLUSIVE"]
                            width: readerTesterDiaId.width - 30
                        }



                        Label {
                            text: qsTrId("qos.data.representation")
                            font.bold: true
                        }
                        Row {
                            CheckBox {
                                id: topicQosDataReprDefaultCheckbox
                                checked: true
                                text: qsTrId("general.default")
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
                                text: "XCDR1"
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
                                text: "XCDR2"
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
                            text: qsTrId("qos.history")
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
                            text: qsTrId("qos.destination.order")
                            font.bold: true
                        }
                        ComboBox {
                            id: topicQosDestinationOrderComboId
                            model: ["ByReceptionTimestamp", "BySourceTimestamp"]
                            width: readerTesterDiaId.width - 30
                        }

                        Label {
                            text: qsTrId("qos.liveliness")
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
                                    text: qsTrId("qos.seconds")
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
                                    text: qsTrId("infinite")
                                }
                            }
                        }

                        Label {
                            text: qsTrId("qos.lifespan")
                            font.bold: true
                        }
                        Row {
                            Label {
                                text: qsTrId("qos.seconds")
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
                                text: qsTrId("infinite")
                            }
                        }

                        Label {
                            text: qsTrId("qos.deadline")
                            font.bold: true
                        }
                        Row {
                            Label {
                                text: qsTrId("qos.seconds")
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
                                text: qsTrId("infinite")
                            }
                        }

                        Label {
                            text: qsTrId("qos.latency.budget")
                            font.bold: true
                        }
                        Row {
                            Label {
                                text: qsTrId("qos.seconds")
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
                                text: qsTrId("infinite")
                            }
                        }

                        Label {
                            text: qsTrId("qos.transport.priority")
                            font.bold: true
                        }
                        SpinBox {
                            id: topicQosTransportPrioritySpinBox
                            to: 1e9
                            value: 0
                        }

                        Label {
                            text: qsTrId("qos.resource.limits")
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
                            text: qsTrId("qos.durability.service")
                            font.bold: true
                        }
                        Column {
                            Row {
                                Label {
                                    text: qsTrId("qos.cleanup.minutes")
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
                                    text: qsTrId("infinite")
                                }
                            }
                            Column {
                                Label {
                                    text: qsTrId("qos.history")
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
                            text: qsTrId("qos.topic.data")
                            font.bold: true
                        }
                        TextField {
                            leftPadding: 10
                            id: topicQosDataField
                            placeholderText: qsTrId("placeholder.topicdata")
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
                            text: qsTrId("qos.participant.handling")
                            font.bold: true
                        }
                        CheckBox {
                            id: dpReuseParticipantCheckbox
                            checked: true
                            text: qsTrId("qos.participant.default")
                        }

                        Label {
                            visible: !dpReuseParticipantCheckbox.checked
                            text: qsTrId("qos.user.data")
                            font.bold: true
                        }
                        TextField {
                            visible: !dpReuseParticipantCheckbox.checked
                            leftPadding: 10
                            id: dpUserdataField
                            placeholderText: qsTrId("placeholder.userdata")
                            text: ""
                        }

                        Label {
                            text: qsTrId("qos.entity.factory")
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

            Rectangle {
                visible: readerTesterDiaId.qosSourceIndex === 1
                width: parent.width
                implicitHeight: providerContent.implicitHeight + 20
                radius: Constants.cardRadius
                color: readerTesterDiaId.surfaceColor
                border.width: 1
                border.color: readerTesterDiaId.borderColor

                ColumnLayout {
                    id: providerContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 7

                    Label {
                        text: qsTrId("qos.provider.file")
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        TextField {
                            Layout.fillWidth: true
                            text: readerTesterDiaId.qosProviderFilePath
                            placeholderText:
                                qsTrId("qos.provider.file.placeholder")
                            readOnly: true
                        }

                        Button {
                            text: qsTrId("qos.provider.browse")
                            onClicked: qosProviderFileDialog.open()
                        }
                    }

                    Label {
                        text: qsTrId("qos.provider.profile-key")
                        font.bold: true
                    }
                    ComboBox {
                        id: qosProviderKeyComboBox
                        Layout.fillWidth: true
                        model: readerTesterDiaId.qosProviderKeys
                        currentIndex:
                            readerTesterDiaId.qosProviderKeys.length > 0
                            ? 0 : -1
                        enabled:
                            readerTesterDiaId.qosProviderFilePath.length > 0
                            && !manualQosProviderKeyCheckBox.checked
                        displayText:
                            currentIndex >= 0
                            ? currentText
                            : readerTesterDiaId.qosProviderFilePath.length > 0
                              ? qsTrId(
                                    "qos.provider.profile-key.placeholder")
                              : ""
                    }

                    CheckBox {
                        id: manualQosProviderKeyCheckBox
                        text: qsTrId(
                                  "qos.provider.profile-key.manual")
                        enabled:
                            readerTesterDiaId.qosProviderFilePath.length > 0
                    }

                    TextField {
                        id: manualQosProviderKeyTextField
                        Layout.fillWidth: true
                        visible: manualQosProviderKeyCheckBox.checked
                        enabled:
                            readerTesterDiaId.qosProviderFilePath.length > 0
                        placeholderText:
                            qsTrId("qos.provider.profile-key.placeholder")
                        selectByMouse: true
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: readerTesterDiaId.secondaryTextColor
                        text: qsTrId("qos.provider.description")
                        enabled:
                            readerTesterDiaId.qosProviderFilePath.length > 0
                    }
                }
            }
        }
    }

    Rectangle {
        id: buttonRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 44
        radius: 10
        color: rootWindow.isDarkMode
               ? "#292929" : "#f0f0f0"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            spacing: 6

            Button {
                id: createEndpointButton
                objectName: "createEndpointButton"
                text: buttonName
                highlighted: true
                Layout.preferredHeight: 30
                onClicked: {
                    if (readerTesterDiaId.qosSourceIndex === 1) {
                        if (readerTesterDiaId.qosProviderFilePath.length === 0) {
                            qosProviderErrorDialog.text = qsTrId("qos.provider.error.file-required")
                            qosProviderErrorDialog.open()
                            return
                        }
                        const profileKey = manualQosProviderKeyCheckBox.checked
                                ? manualQosProviderKeyTextField.text.trim()
                                : qosProviderKeyComboBox.currentText.trim()
                        if (profileKey.length === 0) {
                            qosProviderErrorDialog.text = qsTrId("qos.provider.error.profile-key-required")
                            qosProviderErrorDialog.open()
                            if (manualQosProviderKeyCheckBox.checked) {
                                manualQosProviderKeyTextField.forceActiveFocus()
                            } else {
                                qosProviderKeyComboBox.forceActiveFocus()
                            }
                            return
                        }
                        const success = readerTesterDiaId.model.setQosProviderSelection(
                                          domainIdTextField.text,
                                          topicNameTextFieldId.text,
                                          readerTesterDiaId.topicType,
                                          readerTesterDiaId.entityType,
                                          readerTesterDiaId.qosProviderFilePath,
                                          profileKey)
                        if (success) {
                            readerTesterDiaId.close()
                        }
                        return
                    }

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
                objectName: "cancelButton"
                text: qsTrId("general.cancel")
                Layout.preferredHeight: 30
                onClicked: readerTesterDiaId.close()
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        context: Qt.WindowShortcut
        enabled: readerTesterDiaId.opened && !qosProviderErrorDialog.visible
        onActivated: createEndpointButton.clicked()
    }

    FileDialog {
        id: qosProviderFileDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTrId("qos.provider.filter.xml"), qsTrId("qos.provider.filter.all")]
        title: qsTrId("qos.provider.file-dialog.title")
        onAccepted: {
            readerTesterDiaId.qosProviderFilePath = qmlUtils.toLocalFile(selectedFile)
            readerTesterDiaId.qosProviderKeys =
                    readerTesterDiaId.model.getQosProviderKeys(
                        readerTesterDiaId.qosProviderFilePath,
                        readerTesterDiaId.entityType)
            qosProviderKeyComboBox.currentIndex =
                    readerTesterDiaId.qosProviderKeys.length > 0 ? 0 : -1
            manualQosProviderKeyTextField.clear()
            manualQosProviderKeyCheckBox.checked =
                    readerTesterDiaId.qosProviderKeys.length === 0
        }
    }

    Connections {
        target: readerTesterDiaId.model
        ignoreUnknownSignals: true

        function onQosProviderError(message) {
            qosProviderErrorDialog.text = message
            qosProviderErrorDialog.open()
        }
    }

    MessageDialog {
        id: qosProviderErrorDialog
        title: qsTrId("qos.provider.dialog.title")
        buttons: MessageDialog.Ok
    }
}
