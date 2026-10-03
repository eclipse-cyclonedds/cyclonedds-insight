/*
 * Copyright(c) 2026 Sven Trittler
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0, or the Eclipse Distribution License
 * v. 1.0 which is available at
 * http://www.eclipse.org/org/documents/edl-v10.php.
 *
 * SPDX-License-Identifier: EPL-2.0 OR BSD-3-Clause
 */

pragma ComponentBehavior: Bound

import QtQuick
import "qrc:/src/views"
import "qrc:/src/views/icons"

Rectangle {
    id: badge

    property string kind: "participant"
    property real iconScale: 1.0
    property color iconColor: Constants.accentColor

    implicitWidth: 24
    implicitHeight: 24
    radius: Constants.badgeRadius
    color: rootWindow.isDarkMode ? "#17254f" : "#e6ebff"

    Loader {
        anchors.centerIn: parent
        scale: badge.iconScale
        sourceComponent: {
            if (badge.kind === "domain")
                return domainIcon
            if (badge.kind === "host")
                return hostIcon
            if (badge.kind === "process")
                return processIcon
            if (badge.kind === "topic")
                return topicIcon
            if (badge.kind === "endpoint")
                return endpointIcon
            if (badge.kind === "statistics")
                return statisticsIcon
            if (badge.kind === "tester")
                return testerIcon
            if (badge.kind === "listener")
                return listenerIcon
            if (badge.kind === "details")
                return detailsIcon
            if (badge.kind === "settings")
                return settingsIcon
            if (badge.kind === "configuration")
                return configurationIcon
            if (badge.kind === "shapes")
                return shapesIcon
            if (badge.kind === "qos")
                return qosIcon
            if (badge.kind === "update")
                return updateIcon
            if (badge.kind === "about")
                return aboutIcon
            if (badge.kind === "log")
                return logIcon
            if (badge.kind === "selection")
                return selectionIcon
            return participantIcon
        }
    }

    Component {
        id: participantIcon

        EntityIcon {
            width: 18
            height: 18
            symbol: "participant"
            iconColor: badge.iconColor
        }
    }

    Component {
        id: domainIcon

        Canvas {
            width: 18
            height: 18
            property color strokeColor: badge.iconColor
            onStrokeColorChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = strokeColor
                ctx.lineWidth = 1.6
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(9, 1.5)
                ctx.lineTo(16, 5.3)
                ctx.lineTo(16, 12.7)
                ctx.lineTo(9, 16.5)
                ctx.lineTo(2, 12.7)
                ctx.lineTo(2, 5.3)
                ctx.closePath()
                ctx.moveTo(2, 5.3)
                ctx.lineTo(9, 9.1)
                ctx.lineTo(16, 5.3)
                ctx.moveTo(9, 9.1)
                ctx.lineTo(9, 16.5)
                ctx.stroke()
            }
        }
    }

    Component {
        id: hostIcon

        Item {
            width: 14
            height: 13

            Rectangle {
                width: 14
                height: 9
                radius: 2
                color: "transparent"
                border.width: 1.5
                border.color: badge.iconColor
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 9
                width: 2
                height: 3
                color: badge.iconColor
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 8
                height: 1.5
                radius: 0.75
                color: badge.iconColor
            }
        }
    }

    Component {
        id: processIcon

        Item {
            width: 14
            height: 13

            Repeater {
                model: [0, 5, 10]

                Item {
                    required property int modelData
                    y: modelData
                    width: 14
                    height: 3

                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: badge.iconColor
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9
                        height: 1.5
                        radius: 0.75
                        color: badge.iconColor
                    }
                }
            }
        }
    }

    Component {
        id: topicIcon

        EntityIcon {
            width: 18
            height: 18
            symbol: "topic"
            iconColor: badge.iconColor
        }
    }

    Component {
        id: endpointIcon

        Item {
            width: 14
            height: 12

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 1.5
                color: badge.iconColor
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: 5
                radius: 2.5
                color: badge.iconColor
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: 5
                radius: 2.5
                color: badge.iconColor
            }
        }
    }

    Component {
        id: statisticsIcon

        Item {
            width: 14
            height: 14

            Rectangle {
                x: 1
                y: 1
                width: 1.5
                height: 12
                color: badge.iconColor
            }

            Rectangle {
                x: 1
                y: 11.5
                width: 12
                height: 1.5
                color: badge.iconColor
            }

            Rectangle {
                x: 2
                y: 8
                width: 5
                height: 1.5
                radius: 0.75
                rotation: -35
                transformOrigin: Item.Left
                color: badge.iconColor
            }

            Rectangle {
                x: 6
                y: 5.5
                width: 4
                height: 1.5
                radius: 0.75
                rotation: 24
                transformOrigin: Item.Left
                color: badge.iconColor
            }

            Rectangle {
                x: 9
                y: 7
                width: 5
                height: 1.5
                radius: 0.75
                rotation: -52
                transformOrigin: Item.Left
                color: badge.iconColor
            }
        }
    }

    Component {
        id: testerIcon

        Canvas {
            width: 18
            height: 18
            property color strokeColor: badge.iconColor
            onStrokeColorChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = badge.iconColor
                ctx.lineWidth = 1.6
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(5, 2.5)
                ctx.lineTo(15.5, 9)
                ctx.lineTo(5, 15.5)
                ctx.closePath()
                ctx.stroke()
            }
        }
    }

    Component {
        id: listenerIcon

        Canvas {
            width: 18
            height: 18
            property color strokeColor: badge.iconColor
            onStrokeColorChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = badge.iconColor
                ctx.lineWidth = 1.6
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.arc(9, 11, 1.8, 0, Math.PI * 2)
                ctx.fillStyle = badge.iconColor
                ctx.fill()
                ctx.beginPath()
                ctx.moveTo(9, 13)
                ctx.lineTo(9, 16)
                ctx.moveTo(5.8, 14.2)
                ctx.arc(9, 11, 4.5, Math.PI * 0.75, Math.PI * 2.25)
                ctx.moveTo(3.7, 16.3)
                ctx.arc(9, 11, 7.5, Math.PI * 0.75, Math.PI * 2.25)
                ctx.stroke()
            }
        }
    }

    Component {
        id: detailsIcon

        Item {
            width: 13
            height: 14

            Rectangle {
                width: 13
                height: 14
                radius: 2
                color: "transparent"
                border.width: 1.5
                border.color: badge.iconColor
            }

            Repeater {
                model: [4, 7, 10]

                Rectangle {
                    required property int modelData
                    x: 3
                    y: modelData
                    width: 7
                    height: 1.5
                    radius: 0.75
                    color: badge.iconColor
                }
            }
        }
    }

    Component {
        id: settingsIcon

        Item {
            width: 14
            height: 14

            Repeater {
                model: [[2, 3, 8], [2, 7, 4], [2, 11, 9]]

                Item {
                    required property var modelData
                    x: modelData[0]
                    y: modelData[1]
                    width: 12
                    height: 2

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1.5
                        radius: 0.75
                        color: badge.iconColor
                    }

                    Rectangle {
                        x: modelData[2]
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: badge.iconColor
                    }
                }
            }
        }
    }

    Component {
        id: configurationIcon

        Item {
            width: 14
            height: 14

            Rectangle {
                width: 14
                height: 14
                radius: 2
                color: "transparent"
                border.width: 1.5
                border.color: badge.iconColor
            }

            Repeater {
                model: [[3, 4, 5], [3, 8, 8]]

                Item {
                    required property var modelData
                    x: modelData[0]
                    y: modelData[1]
                    width: 9
                    height: 2

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1.5
                        radius: 0.75
                        color: badge.iconColor
                    }

                    Rectangle {
                        x: modelData[2]
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: badge.iconColor
                    }
                }
            }
        }
    }

    Component {
        id: shapesIcon

        Item {
            width: 14
            height: 14

            Rectangle {
                x: 1
                y: 1
                width: 6
                height: 6
                radius: 3
                color: badge.iconColor
            }

            Rectangle {
                x: 7
                y: 7
                width: 6
                height: 6
                radius: 1
                color: badge.iconColor
            }

            Canvas {
                anchors.fill: parent

                onPaint: {
                    const context = getContext("2d")
                    context.clearRect(0, 0, width, height)
                    context.fillStyle = badge.iconColor
                    context.beginPath()
                    context.moveTo(9.5, 1)
                    context.lineTo(13, 6.5)
                    context.lineTo(6, 6.5)
                    context.closePath()
                    context.fill()
                }
            }
        }
    }

    Component {
        id: qosIcon

        Text {
            text: "QoS"
            color: badge.iconColor
            font.pixelSize: 8
            font.bold: true
        }
    }

    Component {
        id: updateIcon

        Item {
            width: 14
            height: 14

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 1
                width: 2
                height: 8
                radius: 1
                color: badge.iconColor
            }

            Canvas {
                anchors.fill: parent
                onPaint: {
                    const context = getContext("2d")
                    context.clearRect(0, 0, width, height)
                    context.strokeStyle = badge.iconColor
                    context.fillStyle = badge.iconColor
                    context.lineWidth = 1.5
                    context.beginPath()
                    context.moveTo(3, 6)
                    context.lineTo(7, 10)
                    context.lineTo(11, 6)
                    context.stroke()
                }
            }

            Rectangle {
                x: 2
                y: 11
                width: 10
                height: 2
                radius: 1
                color: badge.iconColor
            }
        }
    }

    Component {
        id: aboutIcon

        Item {
            width: 14
            height: 14

            Rectangle {
                anchors.fill: parent
                radius: 7
                color: "transparent"
                border.width: 1.5
                border.color: badge.iconColor
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 3
                width: 2
                height: 2
                radius: 1
                color: badge.iconColor
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                width: 2
                height: 5
                radius: 1
                color: badge.iconColor
            }
        }
    }

    Component {
        id: logIcon

        Item {
            width: 14
            height: 14

            Rectangle {
                anchors.fill: parent
                radius: 2
                color: "transparent"
                border.width: 1.5
                border.color: badge.iconColor
            }

            Repeater {
                model: [3, 6.5, 10]

                Rectangle {
                    required property real modelData
                    x: 3
                    y: modelData
                    width: modelData === 10 ? 5 : 8
                    height: 1.5
                    radius: 0.75
                    color: badge.iconColor
                }
            }
        }
    }

    Component {
        id: selectionIcon

        Item {
            width: 14
            height: 14

            Rectangle {
                x: 1
                y: 1
                width: 10
                height: 9
                radius: 2
                color: "transparent"
                border.width: 1.5
                border.color: badge.iconColor
            }

            Canvas {
                anchors.fill: parent

                onPaint: {
                    const context = getContext("2d")
                    context.clearRect(0, 0, width, height)
                    context.beginPath()
                    context.moveTo(7, 6)
                    context.lineTo(13.5, 9.5)
                    context.lineTo(10.8, 10.7)
                    context.lineTo(9.7, 13.5)
                    context.closePath()
                    context.lineJoin = "round"
                    context.lineWidth = 2.5
                    context.strokeStyle = badge.color
                    context.stroke()
                    context.fillStyle = badge.iconColor
                    context.fill()
                }
            }
        }
    }
}
