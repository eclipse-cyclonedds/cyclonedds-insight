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

            /*ComboBox { # TODO: in the next PR
                //currentIndex: 0
                //enabled: !libraryView.selectionActivated
                id: librariesCombobox
                //width: parent.width * 0.6
                Layout.preferredWidth: parent.width * 0.33
                model: testerModel
                displayText: "Select Writer"
                Layout.fillWidth: true
                //anchors.centerIn: parent
                textRole: "text"
                onCurrentIndexChanged: {
                    console.log("onCurrentIndexChanged")
                    //myLibraryModel.download(model.getIdByIndex(currentIndex))
                }
            }*/

            Item {
                implicitHeight: 1
                Layout.fillWidth: true
            }
            Button {
                text: "Delete All Writers"
                onClicked: datamodelRepoModel.deleteAllReaders()
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
        
        
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    var str = `
import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import org.eclipse.cyclonedds.insight

Rectangle {
    id: settingsViewId
    anchors.fill: parent
    color: rootWindow.isDarkMode ? "black" : "white"

    ScrollView {
        anchors.fill: parent

        GridLayout {
            columns: 2
            anchors.fill: parent
            anchors.margins: 10
            rowSpacing: 10
            columnSpacing: 10

            Label {
                text: "vehicles::Vehicle"
                font.bold: true
            }
            Item {}
            Label {
                text: "name"
            }
            TextField {
                id: idname
            }
            Label {
                text: "x"
            }
            TextField {
                id: idx
                text: "0"
            }
            Label {
                text: "y"
            }
            TextField {
                id: idy
                text: "0"
            }
            Label {
                text: "ha"
            }
            Item {}
            Label {
                text: "franz"
            }
            TextField {
                id: idhafranz
            }
            Label {
                text: "z"
            }
            TextField {
                id: idhaz
                text: "0"
            }
            Label {
                text: "b"
            }
            TextField {
                id: idhab
                text: "0.0"
            }
            Label {
                text: "d"
            }
            TextField {
                id: idhad
                text: "0.0"
            }
            Label {
                text: "c"
            }
            TextField {
                id: idhac
            }
            Button {
                text: qsTr("Write")
                onClicked: {
                    console.log("write button pressed")
                    console.log(idname.text, parseInt(idx.text), parseInt(idy.text), idhafranz.text, parseInt(idhaz.text), parseFloat(idhab.text), parseFloat(idhad.text), idhac.text)
                }
            }
        }
    }
}
                    `;
                    var component = Qt.createQmlObject(str, contentRec);
                }
            }
        }
    }
}
