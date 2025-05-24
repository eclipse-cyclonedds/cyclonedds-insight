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


Window {
    id: shapeDemoViewId
    title: "Shapes Demo"
    width: 800
    minimumWidth: 400
    height: 450
    minimumHeight: 400
    flags: Qt.Window
    property var shapesMap
    property var pendingWriterMap
    property var triangleScale: 0.7
    property bool paused: false

    Component.onCompleted: {
        shapesMap = {};
    }

    Connections {
        target: shapesDemoModel
        function onShapeUpdateSignale(id, shape, color, x, y, size, rotation, fillKind, disposed, fromDds) {

            if (shapeDemoViewId.paused) {
                return
            }

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
        color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

        RowLayout {
            anchors.fill: parent
            spacing: 5

            ColumnLayout {
                id: leftColumnOverview
                Layout.preferredWidth: 250
                Layout.maximumWidth: 250
                Layout.fillHeight: true

                TabBar {
                    id: bar
                    Layout.fillWidth: true

                    TabButton {
                        text: qsTr("Shape Lab")
                    }
                    TabButton {
                        text: qsTr("Manage")
                    }
                }

                StackLayout {
                    id: mainLayoutId
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: bar.currentIndex

                    Item {
                        id: createTabItem
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            id: leftColumn
                            anchors.fill: parent

                            GroupBox {
                                title: qsTr("Publish Shape")
                                Layout.fillWidth: true

                                ColumnLayout {
                                    anchors.fill: parent

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Label {
                                            id: shapeLabel
                                            text: qsTr("Shape:")
                                        }
                                        ComboBox {
                                            id: shapeSelector
                                            Layout.preferredWidth: leftColumn.width - shapeLabel.width - 20
                                            model: ["Square", "Triangle", "Circle", "<<ALL>>"]
                                            currentIndex: 0
                                            onCurrentIndexChanged: {
                                                console.log("Selected shape:", currentText)
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Label {
                                            id: pubColorLabel
                                            text: qsTr("Color:")
                                        }
                                        ComboBox {
                                            id: colorSelector
                                            model: ["Red", "Blue", "Green", "Yellow", "Orange", "Cyan", "Magenta", "Purple", "Gray", "Black", "<<ALL>>"]
                                            currentIndex: 0
                                            Layout.preferredWidth: leftColumn.width - pubColorLabel.width - 20
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Label {
                                            text: qsTr("Size:")
                                        }
                                        Slider {
                                            id: sizeSlider
                                            Layout.fillWidth: true
                                            from: 1
                                            to: 99
                                            value: 30
                                            stepSize: 1
                                        }
                                        Label {
                                            id: sizeSliderLabel
                                            text: sizeSlider.value
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Label {
                                            text: qsTr("Speed:")
                                        }
                                        Slider {
                                            id: speedSlider
                                            Layout.fillWidth: true
                                            from: 1
                                            to: 20
                                            value: 4
                                            stepSize: 1
                                        }
                                        Label {
                                            id: speedSliderLabel
                                            text: speedSlider.value
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        enabled: rotationSpeedSlider.value === 0

                                        Label {
                                            text: qsTr("Angle:")
                                        }
                                        Slider {
                                            id: rotationSlider
                                            Layout.fillWidth: true
                                            from: 0
                                            to: 360
                                            value: 0
                                            stepSize: 1
                                        }
                                        Label {
                                            id: rotationSliderLabel
                                            text: rotationSlider.value + "\u00B0"
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Label {
                                            id: pubRotLabel
                                            text: qsTr("Rotation-Speed:")
                                        }
                                        Slider {
                                            id: rotationSpeedSlider
                                            Layout.fillWidth: true
                                            from: 0
                                            to: 20
                                            value: 0
                                            stepSize: 1
                                            Layout.preferredWidth: leftColumn.width - pubRotLabel.width - rotationSpeedSliderLabel.width - 30
                                        }
                                        Label {
                                            id: rotationSpeedSliderLabel
                                            text: rotationSpeedSlider.value
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Label {
                                            id: pubFillLabel
                                            text: qsTr("Fill:")
                                        }
                                        ComboBox {
                                            id: fillKindSelector
                                            Layout.preferredWidth: leftColumn.width - pubFillLabel.width - 20
                                            model: ["SOLID_FILL", "TRANSPARENT_FILL", "HORIZONTAL_HATCH_FILL", "VERTICAL_HATCH_FILL"]
                                            currentIndex: 0
                                            onCurrentIndexChanged: {
                                                console.log("Selected fill:", currentText)
                                            }
                                        }
                                    }

                                    Button {
                                        text: "Publish"
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
                                            shapesDemoQosSelector.setButtonName("Publish Shape")
                                            shapesDemoQosSelector.open()
                                        }
                                    }
                                }
                            }

                            GroupBox {
                                title: qsTr("Subscribe Shape")
                                Layout.fillWidth: true

                                ColumnLayout {
                                    anchors.fill: parent

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Label {
                                            id: shapeLabelSubscribe
                                            text: qsTr("Shape:")
                                        }

                                        ComboBox {
                                            id: shapeSelectorSubscribe
                                            Layout.preferredWidth: leftColumn.width - shapeLabelSubscribe.width - 20
                                            model: ["Square", "Triangle", "Circle", "<<ALL>>"]
                                            currentIndex: 0
                                            onCurrentIndexChanged: {
                                                console.log("Selected shape:", currentText)
                                            }
                                        }
                                    }

                                    Button {
                                        text: "Subscribe"
                                        onClicked: {
                                            shapesDemoModel.setSubscribeInfos(shapeSelectorSubscribe.currentText);
                                            shapesDemoQosSelector.setType(shapeSelectorSubscribe.currentText, 3)
                                            shapesDemoQosSelector.setButtonName("Subscribe Shape")
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
                            anchors.fill: parent
                            Layout.leftMargin: 10
                            clip: true
                            ScrollBar.vertical: ScrollBar {}
                            model: shapesDemoModel

                            delegate: Item {
                                width: listTabItem.width
                                height: 30

                                Rectangle {
                                    anchors.fill: parent
                                    color: (mouseArea.hovered || infoButton.hovered || removeButton.hovered) ? rootWindow.isDarkMode ? Constants.darkSelectionBackground : Constants.lightSelectionBackground : "transparent"
                                    opacity: 0.3
                                }

                                Label {
                                    text: name
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    property bool hovered: false
                                    onEntered: {
                                        hovered = true
                                    }
                                    onExited: {
                                        hovered = false
                                    }
                                }

                                Button {
                                    id: infoButton
                                    text: "Info"
                                    hoverEnabled: true
                                    width: 50
                                    height: 30
                                    onClicked: {
                                        if (endpDetailWindow.visible) {
                                            endpDetailWindow.raise()
                                        } else {
                                            var centerPos = infoButton.mapToGlobal(infoButton.width / 2, infoButton.height)
                                            endpDetailWindow.x = centerPos.x - endpDetailWindow.width / 2
                                            endpDetailWindow.y = centerPos.y
                                            endpDetailWindow.visible = true
                                        }
                                    }
                                    ToolTip {
                                        id: infoTooltip
                                        parent: infoButton
                                        visible: infoButton.hovered
                                        delay: 200
                                        text: "Qos:\n" + qos
                                        contentItem: Label {
                                            text: infoTooltip.text
                                        }
                                        background: Rectangle {
                                            border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
                                            border.width: 1
                                            color: rootWindow.isDarkMode ? Constants.darkCardBackgroundColor : Constants.lightCardBackgroundColor
                                        }
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: removeButton.left
                                }

                                Button {
                                    id: removeButton
                                    hoverEnabled: true
                                    text: "X"
                                    width: 40
                                    height: 30
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: 5
                                    onClicked: shapesDemoModel.removeItem(index)
                                }
                                EndpointDetailWindow {
                                    id: endpDetailWindow
                                    title: name
                                    endpointText: infoTooltip.text
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    id: shapesPlane
                    color: rootWindow.isDarkMode ? "black" : "white"
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Label {
                        text: "Paused"
                        visible: shapeDemoViewId.paused
                        anchors.top: parent.top
                        anchors.right: parent.right
                        font.pixelSize: 24
                        anchors.margins: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            shapeDemoViewId.paused = !shapeDemoViewId.paused
                        }
                    }               
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10

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
