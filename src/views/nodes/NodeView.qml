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
import QtQuick.Shapes

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"
import "qrc:/src/views/nodes"
import "qrc:/src/views/icons"


Rectangle {
    id: domainViewId
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent

    property int domainId

    property var architectureView: null
    property bool controlsVisible: true
    property real nodeScale: 1.0

    Component.onCompleted: {

    }

    Rectangle {
        id: root
        anchors.fill: parent
        color: "transparent"
    }

    Rectangle {
        id: controlsPanel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 0
        z: 10
        color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent
        width: controlsLayout.implicitWidth
        height: controlsLayout.implicitHeight

        ColumnLayout  {
            id: controlsLayout
            anchors.top: parent.top
            anchors.left: parent.left
            spacing: 0

        Button {
            text: controlsVisible ? qsTrId("node.view.panel.hide") : qsTrId("node.view.panel.show")
            onClicked: controlsVisible = !controlsVisible
        }

        GroupBox {
            title: qsTrId("node.view")
            spacing: 0
            visible: controlsVisible

            ColumnLayout {
                anchors.fill: parent

                CheckBox {
                    id: useAllDomainsCheckBox
                    text: qsTrId("domain.show.all")
                    checked: false
                    onCheckedChanged: {
                        if (architectureView !== null) {
                            architectureView.destroy()
                            architectureView = createArchitectureView(useAllDomainsCheckBox.checked ? -1 : domainViewId.domainId, hideSelfCheckbox.checked, showSpeedsCheckBox.checked, speedSelectComboBox.currentText)
                        }
                    }
                }

                CheckBox {
                    id: hideSelfCheckbox
                    text: qsTrId("node.hide.self")
                    checked: false
                    onCheckedChanged: {
                        if (architectureView !== null) {
                            architectureView.stop()
                            architectureView.destroy()
                            architectureView = createArchitectureView(useAllDomainsCheckBox.checked ? -1 : domainViewId.domainId, hideSelfCheckbox.checked, showSpeedsCheckBox.checked, speedSelectComboBox.currentText)
                        }
                    }
                }

                RowLayout {
                    spacing: 10

                    CheckBox {
                        id: showSpeedsCheckBox
                        text: qsTrId("node.show.speeds")
                        checked: false
                        onCheckedChanged: {
                            if (architectureView !== null) {
                                architectureView.enableSpeeds(showSpeedsCheckBox.checked);
                                architectureView.setSpeedUnit(speedSelectComboBox.currentText);
                            }
                        }
                    }

                    ComboBox {
                        id: speedSelectComboBox
                        enabled: showSpeedsCheckBox.checked
                        model: ["B/s", "KB/s", "MB/s", "GB/s", "TB/s", "PB/s"]
                        currentIndex: 2
                        onCurrentTextChanged: {
                            if (architectureView !== null && showSpeedsCheckBox.checked) {
                                architectureView.setSpeedUnit(currentText);
                            }
                        }
                    }

                    InfoIcon {
                        width: 15
                        height: 15
                        tooltipText: qsTrId("statistic.monitor.usage.hint")
                    }
                }

                RowLayout {
                    spacing: 10
                    Label {
                        text: qsTrId("node.spacing") + ":"
                    }
                    Slider {
                        id: idealLengthSlider
                        from: 50
                        to: 500
                        value: 110
                        stepSize: 1
                        Layout.preferredWidth: 150
                        onValueChanged: {
                            if (architectureView && architectureView.hasOwnProperty("idealLength")) {
                                architectureView.idealLength = value
                            }
                        }
                    }
                    Label {
                        text: Math.round(idealLengthSlider.value)
                        width: 40
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                RowLayout {
                    spacing: 10

                    Label {
                        text: qsTrId("node.view.size") + ":"
                    }

                    Button {
                        text: "-"
                        enabled: nodeScale > 0.1
                        onClicked: {
                            nodeScale = Math.max(0.1, nodeScale - 0.1)
                            if (architectureView !== null) {
                                architectureView.setNodeScale(nodeScale)
                            }
                        }
                    }

                    Label {
                        text: Math.round(nodeScale * 100) + "%"
                        width: 45
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Button {
                        text: "+"
                        onClicked: {
                            nodeScale = nodeScale + 0.1
                            if (architectureView !== null) {
                                architectureView.setNodeScale(nodeScale)
                            }
                        }
                    }
                }

                Button {
                    text: architectureView === null ? qsTrId("node.view.start") : qsTrId("node.view.stop")
                    onClicked: {
                        if (architectureView !== null) {
                            architectureView.stop()
                            architectureView.destroy()
                            architectureView = null
                        } else {
                            architectureView = createArchitectureView(useAllDomainsCheckBox.checked ? -1 : domainViewId.domainId, hideSelfCheckbox.checked, showSpeedsCheckBox.checked, speedSelectComboBox.currentText)
                            architectureView.setSpeedUnit(speedSelectComboBox.currentText);
                        }   
                    }
                }
            }
        }
        }
    }

    function createArchitectureView(domainIdValue, hideSelf, enableSpeeds, currentSpeedUnit) {

        var component = Qt.createComponent("qrc:/src/views/nodes/NodeDetailView.qml")
        if (component.status === Component.Ready) {
            var newView = component.createObject(root, {
                domainId: domainIdValue,
                hideSelf: hideSelf,
                speedEnabled: enableSpeeds,
                currentSpeedUnit: currentSpeedUnit
            })
            if (newView === null) {
                console.log("Failed to create NodeDetailView")
                return null
            }
            newView.idealLength = idealLengthSlider.value
            newView.setNodeScale(nodeScale)
            return newView
        } else {
            console.log("Component loading failed:", component.errorString())
            return null
        }
    }

    function aboutToClose() {
        console.log("NodeView: about to close.")
        if (architectureView !== null) {
            architectureView.stop()
        }
    }
}
