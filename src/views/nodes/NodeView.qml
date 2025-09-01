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

    Component.onCompleted: {

    }

    ColumnLayout  {
        anchors.fill: parent
        anchors.margins: 0

        GroupBox {
            title: qsTr("Node View")
            spacing: 0

            ColumnLayout {
                anchors.fill: parent

                CheckBox {
                    id: useAllDomainsCheckBox
                    text: qsTr("Show all domains")
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
                    text: qsTr("Hide self")
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
                        text: qsTr("Show Speeds")
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
                        tooltipText: qsTr("This feature is only available for Cyclone DDS endpoints which have enabled Internal/MonitorPort.")
                    }
                }

                RowLayout {
                    spacing: 10
                    Label {
                        text: qsTr("Node Spacing:")
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

                Button {
                    text: architectureView === null ? "Show" : "Hide"
                    onClicked: {
                        if (architectureView !== null) {
                            architectureView.stop()
                            architectureView.destroy()
                        } else {
                            architectureView = createArchitectureView(useAllDomainsCheckBox.checked ? -1 : domainViewId.domainId, hideSelfCheckbox.checked, showSpeedsCheckBox.checked, speedSelectComboBox.currentText)
                            architectureView.setSpeedUnit(speedSelectComboBox.currentText);
                        }   
                    }
                }
            }
        }

        Rectangle {
            id: root
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.color: rootWindow.isDarkMode ? Constants.darkBorderColor : Constants.lightBorderColor
            border.width: architectureView !== null ? 1 : 0
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
