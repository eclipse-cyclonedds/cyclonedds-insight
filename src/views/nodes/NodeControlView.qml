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
                            architectureView = createArchitectureView(useAllDomainsCheckBox.checked ? -1 : domainViewId.domainId, hideSelfCheckbox.checked)
                        }
                    }
                }

                CheckBox {
                    id: hideSelfCheckbox
                    text: qsTr("Hide self")
                    checked: false
                    onCheckedChanged: {
                        if (architectureView !== null) {
                            architectureView.destroy()
                            architectureView = createArchitectureView(useAllDomainsCheckBox.checked ? -1 : domainViewId.domainId, hideSelfCheckbox.checked)
                        }
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
                    text: architectureView === null ? "Open" : "Close"
                    onClicked: {
                        if (architectureView !== null) {
                            architectureView.destroy()
                        } else {
                            architectureView = createArchitectureView(useAllDomainsCheckBox.checked ? -1 : domainViewId.domainId, hideSelfCheckbox.checked)
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

        /*Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }*/
    }

    function createArchitectureView(domainIdValue, hideSelf) {

        var component = Qt.createComponent("qrc:/src/views/nodes/NodeView.qml")
        if (component.status === Component.Ready) {
            var newView = component.createObject(root, {
                domainId: domainIdValue,
                hideSelf: hideSelf
            })
            if (newView === null) {
                console.log("Failed to create NodeView")
                return null
            }
            newView.idealLength = idealLengthSlider.value
            return newView
        } else {
            console.log("Component loading failed:", component.errorString())
            return null
        }
    }

}
