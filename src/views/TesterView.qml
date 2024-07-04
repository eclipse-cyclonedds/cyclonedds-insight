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


Rectangle {
    id: listenerTabId
    anchors.fill: parent
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground
    property var component

    Connections {
        target: testerModel
        function onShowQml(id, qmlCode) {
            console.log("Show QML")
            component = Qt.createQmlObject(qmlCode, contentRec);
            component.mId = id
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.minimumHeight: 40
            Layout.maximumHeight: 40
            spacing: 10

            Item {
                implicitHeight: 1
                implicitWidth: 1
            }

            Label {
                text: "Select:"
            }

            ComboBox {
                // currentIndex: 0
                id: librariesCombobox
                Layout.preferredWidth: parent.width * 0.33
                model: testerModel
                Layout.fillWidth: true
                textRole: "name"
                onCurrentIndexChanged: {
                    console.log("onCurrentIndexChanged", currentIndex)
                    if (testerModel) {
                        testerModel.showTester(currentIndex)
                    }
                }
            }

            /*Item {
                implicitHeight: 1
                Layout.fillWidth: true
            }*/
            Button {
                text: "Delete All Writers"
                onClicked: {
                    component.destroy()
                    testerModel.deleteAllWriters()
                }
            }
            Item {
                implicitHeight: 1
                implicitWidth: 1
            }
        }

       Rectangle {
            id: contentRec
            color: rootWindow.isDarkMode ? "black" : "white"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 3

            /*Flickable {
                id: scrollView
                anchors.fill: parent
                boundsBehavior: Flickable.StopAtBounds
                interactive: true
                ScrollBar.vertical: ScrollBar {}

            }*/
        
        }
    }
}
