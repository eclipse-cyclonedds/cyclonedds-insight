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


Window {
    id: shapeDemoViewId
    title: "Shapes Demo"
    width: 800
    height: 450
    flags: Qt.Dialog
    property var shapesMap

    Component.onCompleted: {
        shapesMap = {};
    }

    onVisibleChanged: {
        if (visible) {
            shapesDemoModel.start();
        }
    }

    Connections {
        target: shapesDemoModel
        function onShapeUpdateSignale(id, shape, color, x, y, size, disposed) {
            if (shapesMap[id] === undefined) {
                if (disposed) {
                    console.log("Shape with ID", id, "was disposed");
                } else {
                    spawnShape(id, shape, x, y, size, pastelColor(color));
                }
            } else {
                if (disposed) { 
                    console.log("Shape with ID", id, "was disposed");
                    shapesMap[id].destroy();
                    delete shapesMap[id];
                } else {
                    moveShape(id, x, y, size);
                }
            }
        }
    }

    function spawnShape(shapeId, shape, initX, initY, initSize, color) {
        var rect = null;
        if (shape === "Circle") {
            rect = circleComponent.createObject(shapesPlane, { x: initX, y: initY, width: initSize, height: initSize, color: color });
        } else if (shape === "Triangle") {
            rect = triangleComponent.createObject(shapesPlane, { x: initX, y: initY, width: initSize, height: initSize, color: color });
        } else {
            rect = rectangleComponent.createObject(shapesPlane, { x: initX, y: initY, width: initSize, height: initSize, color: color });
        }
        if (rect !== null) {
            shapesMap[shapeId] = rect;
        }
    }

    function moveShape(id, newX, newY, newSize) {
        if (shapesMap && shapesMap[id] !== undefined) {
            shapesMap[id].x = newX;
            shapesMap[id].y = newY;
            shapesMap[id].height = newSize;
            shapesMap[id].width = newSize;
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
                id: leftColumn
                Layout.preferredWidth: 250
                Layout.maximumWidth: 250
                Layout.fillHeight: true

                GroupBox {
                    title: qsTr("Publish Shape")
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Label {
                                id: shapeLabel
                                text: qsTr("Shape:")
                            }
                            ComboBox {
                                id: shapeSelector
                                Layout.preferredWidth: leftColumn.width - shapeLabel.width - 10
                                model: ["Square", "Triangle", "Circle"]
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
                                text: qsTr("Color:")
                            }
                            ComboBox {
                                id: colorSelector
                                Layout.fillWidth: true
                                model: ["Red", "Blue", "Green", "Yellow", "Orange", "Cyan", "Magenta", "Purple", "Gray", "Black"]
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    console.log("Selected color:", currentText)
                                }
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

                        Button {
                            text: "Publish"
                            onClicked: {
                                console.log("Publish shape:", shapeSelector.currentText, "Color:", colorSelector.currentText, "Size:", sizeSlider.value, "Speed:", speedSlider.value);
                                shapesDemoModel.setPublishInfos(shapeSelector.currentText, colorSelector.currentText, sizeSlider.value, speedSlider.value);

                                //shapesDemoQosSelector.setType(shapeSelector.currentText, 4)
                                shapesDemoQosSelector.setTypes(0, shapeSelector.currentText, [shapeSelector.currentText], 3);
                                shapesDemoQosSelector.setButtonName("Publish Shape")
                                shapesDemoQosSelector.open()
                            }
                        }
                    }
                }

                GroupBox {
                    title: qsTr("Subscribe Shape")
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Label {
                                id: shapeLabelSubscribe
                                text: qsTr("Shape:")
                            }

                            ComboBox {
                                id: shapeSelectorSubscribe
                                Layout.preferredWidth: leftColumn.width - shapeLabelSubscribe.width - 10
                                model: ["Square", "Triangle", "Circle"]
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

                    Component {
                        id: rectangleComponent
                        Rectangle {
                            width: 50
                            height: 50
                            color: "blue"
                            border.color: rootWindow.isDarkMode ? "darkgray" : "black"
                            border.width: 1
                        }
                    }
                    Component {
                        id: circleComponent
                        Rectangle {
                            width: 50
                            height: 50
                            color: "blue"
                            radius: width / 2
                            clip: true
                            border.color: rootWindow.isDarkMode ? "darkgray" : "black"
                            border.width: 1
                        }
                    }
                    Component {
                        id: triangleComponent

                        Item {
                            id: triangleItem
                            property color color: "blue"
                            property real borderWidth: 1
                            property color borderColor: rootWindow.isDarkMode ? "darkgray" : "black"

                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)

                                    ctx.beginPath()
                                    ctx.moveTo(width / 2, 0)       // Top center
                                    ctx.lineTo(0, height)           // Bottom left
                                    ctx.lineTo(width, height)       // Bottom right
                                    ctx.closePath()

                                    ctx.fillStyle = triangleItem.color
                                    ctx.fill()
                        
                                    if (triangleItem.borderWidth > 0) {
                                        ctx.lineWidth = triangleItem.borderWidth
                                        ctx.strokeStyle = triangleItem.borderColor
                                        ctx.stroke()
                                    }
                                }

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onVisibleChanged: if (visible) requestPaint()
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
        case "black":
            return "#333333";
        case "purple":
            return "#9966CC";
        default:
            return "#333333"; // fallback to black
        }
    }

    QosSelector {
        id: shapesDemoQosSelector
        model: shapesDemoModel
    }
}
