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
        anchors.margins: 10

        Label {
            text: qsTr("Domain")
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignLeft
            Layout.alignment: Qt.AlignLeft
        }
        Label {
            text: qsTr("Domain ID: ") + domainViewId.domainId
        }

        GroupBox {
            title: qsTr("Architecture View")
            spacing: 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent

                CheckBox {
                    id: useAllDomainsCheckBox
                    text: qsTr("Show all domains")
                    checked: false
                    onCheckedChanged: {
                        if (architectureView !== null) {
                            architectureView.destroy()
                            architectureView = createArchitectureView(useAllDomainsCheckBox.checked ? -1 : domainViewId.domainId)
                        }
                    }
                }

                Button {
                    text: architectureView === null ? "Open" : "Close"
                    onClicked: {
                        if (architectureView !== null) {
                            architectureView.destroy()
                        } else {
                            architectureView = createArchitectureView(useAllDomainsCheckBox.checked ? -1 : domainViewId.domainId)
                        }   
                    }
                }

                Rectangle {
                    id: root
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    function createArchitectureView(domainIdValue) {

        var component = Qt.createComponent("qrc:/src/views/nodes/ArchitectureView.qml")
        if (component.status === Component.Ready) {
            var newView = component.createObject(root, {
                domainId: domainIdValue
            })
            if (newView === null) {
                console.log("Failed to create ArchitectureView")
                return null
            }
            return newView
        } else {
            console.log("Component loading failed:", component.errorString())
            return null
        }
    }

}
