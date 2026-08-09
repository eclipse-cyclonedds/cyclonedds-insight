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
import "qrc:/src/views"
import "qrc:/src/views/selection_details"


Window {
    id: shapeDemoViewId
    title: qsTrId("shapes.title")
    width: 800
    minimumWidth: 400
    height: 490
    minimumHeight: 400
    flags: Qt.Window
    property var shapesMap
    property var pendingWriterMap
    property var triangleScale: 0.7
    property bool paused: false
    property int currentControlTab: 0
    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    readonly property color borderColor: Constants.designBorderColor(rootWindow.isDarkMode)

    Component.onCompleted: {
        shapesMap = {};
    }

    Connections {
        target: shapesDemoModel
        function onShapeUpdateSignale(id, shape, color, x, y, size, rotation, fillKind, disposed, fromDds) {

            var realSize = size;
            if (shape === "Triangle") {
                realSize = size * (2-shapeDemoViewId.triangleScale);
            }

            var realColor = color;
            if (fillKind >= 1) {
                realColor = "transparent";
            }

            var opacity = 1.0
            var centerColor = "black"
            if (!fromDds) {
                opacity = 0.5
                centerColor = "white"
            }
            var rgbaColor = pastelColorToQColor(realColor, opacity)

            var isHatch = fillKind > 1;
            var orientation = "";
            if (fillKind === 2) {
                orientation = "horizontal";
            } else if (fillKind === 3) {
                orientation = "vertical";
            }

            if (shapesMap[id] === undefined) {
                if (disposed) {
                    console.log("Shape with ID:", id, "was disposed");
                } else {
                    spawnShape(id, shape, x, y, realSize, rgbaColor, rotation, centerColor, !fromDds, orientation, isHatch);
                }
            } else {
                if (disposed) { 
                    console.log("Shape with ID", id, "was disposed");
                    destroyShape(id)
                } else {
                    updateShape(id, x, y, realSize, rotation, rgbaColor, orientation, isHatch); 
                }
            }
        }
    }

    function destroyShape(id) {
        if (shapesMap !== undefined && shapesMap[id] !== undefined) {
            shapesMap[id].destroy();
            delete shapesMap[id];
        }
    }

    function spawnShape(shapeId, shape, initX, initY, initSize, color, rotation, centerColor, isForeground, orientation, isHatch) {
        var rect = null;
        if (shape === "Circle") {
            var circleComponent = Qt.createComponent("qrc:/src/views/shapes_demo/ShapesDemoCircle.qml");
            if (circleComponent.status !== Component.Ready) {
                console.error("Failed to load ShapesDemoCircle.qml:", circleComponent.errorString());
                return;
            }
            rect = circleComponent.createObject(shapesPlane, { x: initX, y: initY, width: initSize, height: initSize, color: color, rotation: rotation, orientation: orientation, isHatch: isHatch, centerColor: centerColor, isForeground: isForeground });
        } else if (shape === "Triangle") {
            var triangleComponent = Qt.createComponent("qrc:/src/views/shapes_demo/ShapesDemoTriangle.qml");
            if (triangleComponent.status !== Component.Ready) {
                console.error("Failed to load ShapesDemoTriangle.qml:", circleComponent.errorString());
                return;
            }
            rect = triangleComponent.createObject(shapesPlane, { x: initX, y: initY, width: initSize, height: initSize, color: color, rotation: rotation, orientation: orientation, isHatch: isHatch, centerColor: centerColor, isForeground: isForeground });
        } else {
            var rectangleComponent = Qt.createComponent("qrc:/src/views/shapes_demo/ShapesDemoSquare.qml");
            if (rectangleComponent.status !== Component.Ready) {
                console.error("Failed to load ShapesDemoSquare.qml:", circleComponent.errorString());
                return;
            }
            rect = rectangleComponent.createObject(shapesPlane, { x: initX, y: initY, width: initSize, height: initSize, color: color, rotation: rotation, orientation: orientation, isHatch: isHatch, centerColor: centerColor, isForeground: isForeground });
        }
        if (rect !== null) {
            shapesMap[shapeId] = rect;
        }
    }

    function updateShape(id, newX, newY, newSize, rotation, color, orientation, isHatch) {
        if (shapesMap && shapesMap[id] !== undefined) {
            shapesMap[id].x = newX;
            shapesMap[id].y = newY;
            shapesMap[id].height = newSize;
            shapesMap[id].width = newSize;
            shapesMap[id].rotation = rotation;
            shapesMap[id].color = color;
            shapesMap[id].orientation = orientation;
            shapesMap[id].isHatch = isHatch;
        } else {
            console.log("Shape with ID", id, "not found!");
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: Constants.mainContentColor(rootWindow.isDarkMode)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Constants.pageMargin
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                DetailBadge {
                    kind: "shapes"
                }

                Label {
                    text: qsTrId("general.shapedemo")
                    font.pixelSize: Constants.pageTitleFontSize
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: shapeDemoViewId.paused ? Constants.errorColor : Constants.successColor
                }

                Label {
                    text: shapeDemoViewId.paused
                          ? qsTrId("status.paused")
                          : qsTrId("status.running")
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                ColumnLayout {
                    id: leftColumnOverview
                    objectName: "shapeControls"
                    Layout.preferredWidth: 245
                    Layout.minimumWidth: 240
                    Layout.maximumWidth: 250
                    Layout.fillHeight: true
                    spacing: 0

                    Row {
                        Layout.preferredHeight: 30
                        Layout.bottomMargin: -1
                        spacing: 3
                        z: 2

                        Repeater {
                            model: [
                                qsTrId("demo.shapes.shapelab"),
                                qsTrId("demo.shapes.manage")
                            ]

                            Rectangle {
                                id: controlTab

                                required property int index
                                required property string modelData
                                readonly property bool selected:
                                    index === shapeDemoViewId.currentControlTab

                                width: (leftColumnOverview.width - 3) / 2
                                height: selected ? 30 : 27
                                y: selected ? 0 : 3
                                radius: Constants.controlRadius
                                color: selected
                                       ? shapeDemoViewId.surfaceColor
                                       : rootWindow.isDarkMode
                                         ? "#383838"
                                         : "#e2e2e2"
                                border.width: 1
                                border.color: selected
                                              ? shapeDemoViewId.borderColor
                                              : Constants.separatorColor(rootWindow.isDarkMode)
                                opacity: selected || tabMouseArea.containsMouse
                                         ? 1 : 0.78

                                Rectangle {
                                    visible: controlTab.selected
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 1
                                    anchors.rightMargin: 1
                                    height: 2
                                    color: parent.color
                                }

                                Label {
                                    anchors.centerIn: parent
                                    text: controlTab.modelData
                                    font.bold: controlTab.selected
                                }

                                MouseArea {
                                    id: tabMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        shapeDemoViewId.currentControlTab =
                                            controlTab.index
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Constants.cardRadius
                        color: shapeDemoViewId.surfaceColor
                        border.width: 1
                        border.color: shapeDemoViewId.borderColor
                        clip: true
                        z: 1

                        StackLayout {
                            id: mainLayoutId
                            anchors.fill: parent
                            anchors.margins: 10
                            currentIndex: shapeDemoViewId.currentControlTab

                            Item {
                                id: createTabItem
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    id: leftColumn
                                    spacing: 8

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight:
                                                publishShapeLayout.implicitHeight
                                                + 16
                                            radius: Constants.controlRadius
                                            color: rootWindow.isDarkMode
                                                   ? "#292929"
                                                   : "#f8f8f8"

                                ColumnLayout {
                                    id: publishShapeLayout
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 5

                                    Label {
                                        text: qsTrId("demo.shapes.publish.shape")
                                        font.bold: true
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 8
                                        rowSpacing: 5

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Label {
                                                text: qsTrId("demo.shapes.shape")
                                            }

                                            ComboBox {
                                                id: shapeSelector
                                                Layout.fillWidth: true
                                                model: ["Square", "Triangle", "Circle", "<<ALL>>"]
                                                currentIndex: 0
                                                onCurrentIndexChanged: {
                                                    console.log("Selected shape:", currentText)
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Label {
                                                text: qsTrId("demo.shapes.color")
                                            }

                                            ComboBox {
                                                id: colorSelector
                                                Layout.fillWidth: true
                                                model: ["Red", "Blue", "Green", "Yellow", "Orange", "Cyan", "Magenta", "Purple", "Gray", "Black", "<<ALL>>"]
                                                currentIndex: 0
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 5

                                            Label {
                                                Layout.preferredWidth: 92
                                                text: qsTrId(
                                                          "demo.shapes.size")
                                                elide: Text.ElideRight
                                            }
                                            Slider {
                                                id: sizeSlider
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 22
                                                from: 1
                                                to: 99
                                                value: 30
                                                stepSize: 1
                                            }
                                            Label {
                                                Layout.preferredWidth: 22
                                                text: sizeSlider.value
                                                horizontalAlignment:
                                                    Text.AlignRight
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 5

                                            Label {
                                                Layout.preferredWidth: 92
                                                text: qsTrId(
                                                          "demo.shapes.speed")
                                                elide: Text.ElideRight
                                            }
                                            Slider {
                                                id: speedSlider
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 22
                                                from: 1
                                                to: 20
                                                value: 4
                                                stepSize: 1
                                            }
                                            Label {
                                                Layout.preferredWidth: 22
                                                text: speedSlider.value
                                                horizontalAlignment:
                                                    Text.AlignRight
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            enabled: rotationSpeedSlider.value === 0
                                            spacing: 5

                                            Label {
                                                Layout.preferredWidth: 92
                                                text: qsTrId(
                                                          "demo.shapes.angle")
                                                elide: Text.ElideRight
                                            }
                                            Slider {
                                                id: rotationSlider
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 22
                                                from: 0
                                                to: 360
                                                value: 0
                                                stepSize: 1
                                            }
                                            Label {
                                                Layout.preferredWidth: 22
                                                text: rotationSlider.value
                                                      + "\u00B0"
                                                horizontalAlignment:
                                                    Text.AlignRight
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 5

                                            Label {
                                                Layout.preferredWidth: 92
                                                text: qsTrId(
                                                          "demo.shapes.rotation.speed")
                                                elide: Text.ElideRight
                                            }
                                            Slider {
                                                id: rotationSpeedSlider
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 22
                                                from: 0
                                                to: 20
                                                value: 0
                                                stepSize: 1
                                            }
                                            Label {
                                                Layout.preferredWidth: 22
                                                text:
                                                    rotationSpeedSlider.value
                                                horizontalAlignment:
                                                    Text.AlignRight
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Label {
                                            text: qsTrId("demo.shapes.fill")
                                        }
                                        ComboBox {
                                            id: fillKindSelector
                                            Layout.fillWidth: true
                                            model: ["SOLID_FILL", "TRANSPARENT_FILL", "HORIZONTAL_HATCH_FILL", "VERTICAL_HATCH_FILL"]
                                            currentIndex: 0
                                            onCurrentIndexChanged: {
                                                console.log("Selected fill:", currentText)
                                            }
                                        }
                                    }

                                    Button {
                                        Layout.fillWidth: true
                                        text: qsTrId("demo.shapes.publish")
                                        onClicked: {
                                            console.log("Publish shape:", shapeSelector.currentText, "Color:", colorSelector.currentText, "Size:", sizeSlider.value, "Speed:", speedSlider.value);
                                            shapesDemoModel.setPublishInfos(
                                                shapeSelector.currentText,
                                                colorSelector.currentText,
                                                sizeSlider.value,
                                                speedSlider.value,
                                                rotationSlider.value,
                                                rotationSpeedSlider.value,
                                                fillKindSelector.currentIndex);

                                            shapesDemoQosSelector.setType(shapeSelector.currentText, 4)
                                            shapesDemoQosSelector.setButtonName(qsTrId("demo.shapes.publish.shape"))
                                            shapesDemoQosSelector.open()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight:
                                    subscribeShapeLayout.implicitHeight + 16
                                radius: Constants.controlRadius
                                color: rootWindow.isDarkMode
                                       ? "#292929"
                                       : "#f8f8f8"

                                ColumnLayout {
                                    id: subscribeShapeLayout
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 5

                                    Label {
                                        text: qsTrId("demo.shapes.subscribe.shape")
                                        font.bold: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Label {
                                            text: qsTrId("demo.shapes.shape")
                                        }

                                        ComboBox {
                                            id: shapeSelectorSubscribe
                                            Layout.fillWidth: true
                                            model: ["Square", "Triangle", "Circle", "<<ALL>>"]
                                            currentIndex: 0
                                            onCurrentIndexChanged: {
                                                console.log("Selected shape:", currentText)
                                            }
                                        }
                                    }

                                    Button {
                                        Layout.fillWidth: true
                                        text: qsTrId("demo.shapes.subscribe")
                                        onClicked: {
                                            shapesDemoModel.setSubscribeInfos(shapeSelectorSubscribe.currentText);
                                            shapesDemoQosSelector.setType(shapeSelectorSubscribe.currentText, 3)
                                            shapesDemoQosSelector.setButtonName(qsTrId("demo.shapes.subscribe.shape"))
                                            shapesDemoQosSelector.open()
                                        }
                                    }
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }
                        }
                    }

                            Item {
                                id: listTabItem
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ListView {
                                    id: manageList
                                    objectName: "manageList"
                                    anchors.fill: parent
                                    clip: true
                                    ScrollBar.vertical: ScrollBar {}
                                    model: shapesDemoModel
                                    spacing: 4

                                    delegate: Rectangle {
                                        id: manageDelegate

                                        required property int index
                                        required property string name
                                        required property string qos
                                        readonly property color textColor:
                                            rootWindow.isDarkMode
                                            ? "#eeeeee" : "#262626"
                                        readonly property color detailsColor:
                                            rootWindow.isDarkMode
                                            ? Constants.darkMutedForeground : "#555555"

                                        width: ListView.view.width
                                        height: 44
                                        radius: Constants.controlRadius
                                        color: rowMouseArea.containsMouse
                                               ? rootWindow.isDarkMode
                                                 ? "#3b3f49"
                                                 : "#e9edf7"
                                               : rootWindow.isDarkMode
                                                 ? "#292929"
                                                 : "#f8f8f8"
                                        border.width: 1
                                        border.color:
                                            rowMouseArea.containsMouse
                                            ? rootWindow.isDarkMode
                                              ? "#626a7b"
                                              : "#c7cee0"
                                            : shapeDemoViewId.borderColor

                                        Label {
                                            text: manageDelegate.name
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.right: detailsButton.left
                                            anchors.rightMargin: 8
                                            color: manageDelegate.textColor
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            id: rowMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                        }

                                        Rectangle {
                                            id: detailsButton
                                            width: detailsLabel.implicitWidth + 16
                                            height: 28
                                            radius: 5
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: removeButton.left
                                            anchors.rightMargin: 5
                                            color: detailsMouseArea.pressed
                                                   ? rootWindow.isDarkMode
                                                     ? "#4a4a4a"
                                                     : "#d7d7d7"
                                                   : detailsMouseArea.containsMouse
                                                     ? rootWindow.isDarkMode
                                                       ? "#3e3e3e"
                                                       : "#e8e8e8"
                                                     : rootWindow.isDarkMode
                                                       ? "#303030"
                                                       : "#f1f1f1"
                                            border.width: 1
                                            border.color: rootWindow.isDarkMode
                                                          ? "#666666"
                                                          : "#b5b5b5"

                                            Label {
                                                id: detailsLabel
                                                anchors.centerIn: parent
                                                text: qsTrId(
                                                          "endpoint.details")
                                                color:
                                                    manageDelegate.detailsColor
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: detailsMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape:
                                                    Qt.PointingHandCursor
                                                onClicked: {
                                                    if (endpDetailWindow.visible) {
                                                        endpDetailWindow.raise()
                                                    } else {
                                                        var centerPos =
                                                            detailsButton
                                                            .mapToGlobal(
                                                                width / 2,
                                                                height)
                                                        endpDetailWindow.x =
                                                            centerPos.x
                                                            - endpDetailWindow
                                                              .width / 2
                                                        endpDetailWindow.y =
                                                            centerPos.y
                                                        endpDetailWindow
                                                            .visible = true
                                                    }
                                                }
                                            }

                                            ToolTip {
                                                id: infoTooltip
                                                parent: detailsButton
                                                visible:
                                                    detailsMouseArea
                                                    .containsMouse
                                                delay: 200
                                                text: qsTrId("shapes.qos.value").arg(manageDelegate.qos)
                                                contentItem: Label {
                                                    text: infoTooltip.text
                                                }
                                                background: Rectangle {
                                                    border.color: Constants.borderColor(rootWindow.isDarkMode)
                                                    border.width: 1
                                                    color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: removeButton
                                            width: 28
                                            height: 28
                                            radius: 5
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: parent.right
                                            anchors.rightMargin: 7
                                            color: removeMouseArea.pressed
                                                   ? rootWindow.isDarkMode
                                                     ? "#5a292d"
                                                     : "#ffd9dc"
                                                   : removeMouseArea
                                                     .containsMouse
                                                     ? rootWindow.isDarkMode
                                                       ? "#47272a"
                                                       : "#ffeaec"
                                                     : "transparent"
                                            border.width: 1
                                            border.color: rootWindow.isDarkMode
                                                          ? "#e56b73"
                                                          : "#c83f49"

                                            Item {
                                                anchors.centerIn: parent
                                                width: 10
                                                height: 10

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 12
                                                    height: 1.5
                                                    radius: 1
                                                    rotation: 45
                                                    color:
                                                        rootWindow.isDarkMode
                                                        ? "#ff949b"
                                                        : "#b72f39"
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 12
                                                    height: 1.5
                                                    radius: 1
                                                    rotation: -45
                                                    color:
                                                        rootWindow.isDarkMode
                                                        ? "#ff949b"
                                                        : "#b72f39"
                                                }
                                            }

                                            MouseArea {
                                                id: removeMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape:
                                                    Qt.PointingHandCursor
                                                onClicked:
                                                    shapesDemoModel.removeItem(
                                                        manageDelegate.index)
                                            }

                                            ToolTip {
                                                id: removeTooltip
                                                parent: removeButton
                                                visible:
                                                    removeMouseArea
                                                    .containsMouse
                                                delay: 300
                                                text: qsTrId("shapes.endpoint.remove")
                                                contentItem: Label {
                                                    text: removeTooltip.text
                                                    padding: 4
                                                    color:
                                                        rootWindow.isDarkMode
                                                        ? "#eeeeee"
                                                        : "#262626"
                                                }
                                                background: Rectangle {
                                                    radius: 4
                                                    border.width: 1
                                                    border.color:
                                                        rootWindow.isDarkMode
                                                        ? Constants
                                                          .darkBorderColor
                                                        : Constants
                                                          .lightBorderColor
                                                    color:
                                                        rootWindow.isDarkMode
                                                        ? Constants
                                                          .darkCardBackgroundColor
                                                        : Constants
                                                          .lightCardBackgroundColor
                                                }
                                            }
                                        }

                                        EndpointDetailWindow {
                                            id: endpDetailWindow
                                            title: manageDelegate.name
                                            endpointText: infoTooltip.text
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: shapesPlane
                    objectName: "shapesPlane"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Constants.cardRadius
                    color: rootWindow.isDarkMode ? "#111111" : "#ffffff"
                    border.width: 1
                    border.color: shapeDemoViewId.borderColor
                    clip: true

                    Rectangle {
                        visible: shapeDemoViewId.paused
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: pausedLabel.implicitWidth + 18
                        height: 26
                        radius: 13
                        color: rootWindow.isDarkMode ? "#512727" : "#ffe3e3"

                        Label {
                            id: pausedLabel
                            anchors.centerIn: parent
                            text: qsTrId("shapes.paused")
                            font.bold: true
                            color: rootWindow.isDarkMode
                                   ? "#ffaaaa"
                                   : "#9b2525"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            shapeDemoViewId.paused = !shapeDemoViewId.paused
                            if (shapeDemoViewId.paused) {
                                shapesDemoModel.pause()
                            } else {
                                shapesDemoModel.resume()
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.bottomMargin: 18

        color: "transparent"

        width: 130
        height: 50

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Image {
                source: "qrc:/res/images/cyclonedds.png"
                sourceSize.width: 30
                sourceSize.height: 30

            }

            /*AnimatedImage {
                id: animatedLoadingId
                source: "qrc:/res/images/spinning.gif"
                sourceSize.height: 30
                sourceSize.width: 30
                height: 30
                width: 30
            }*/

            Label {
                text: "Cyclone DDS"
            }
        }
    }

    function pastelColor(name) {
        switch (name.toLowerCase()) {
        case "blue":
            return "#336699";
        case "red":
            return "#CC3333";
        case "green":
            return "#99CC66";
        case "orange":
            return "#FF9933";
        case "yellow":
            return "#FFFF66";
        case "magenta":
            return "#CC99CC";
        case "cyan":
            return "#99CCFF";
        case "gray":
            return "#999999";
        case "lightgray":
        case "light grey":
            return "#CCCCCC";
        case "black":
            return "#333333";
        case "purple":
            return "#9966CC";
        case "transparent":
            return "transparent";
        default:
            return "#333333"; // fallback to black
        }
    }

    function hexToRgb(hex) {
        if (hex === "transparent") {
            return { r: 0, g: 0, b: 0, a: 0 };
        }
        hex = hex.replace("#", "");
        const bigint = parseInt(hex, 16);
        return {
            r: (bigint >> 16) & 255,
            g: (bigint >> 8) & 255,
            b: bigint & 255
        };
    }

    function pastelColorToQColor(name, opacity = 1.0) {
        const hex = pastelColor(name);
        const rgb = hexToRgb(hex);
        if (name === "transparent") {
            return rgb;
        }
        return Qt.rgba(rgb.r / 255, rgb.g / 255, rgb.b / 255, opacity);
    }

    QosSelector {
        id: shapesDemoQosSelector
        model: shapesDemoModel
    }
}
