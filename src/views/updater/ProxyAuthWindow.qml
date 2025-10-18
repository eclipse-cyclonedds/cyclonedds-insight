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
import QtQuick.Controls
import QtQuick.Layouts

import "qrc:/src/views"


Window {
    id: proxyAuthWindow

    title: "Proxy Authentication"
    visible: false
    flags: Qt.Dialog
    modality: Qt.ApplicationModal
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

    property int proxyAuthWidth: 300
    property int proxyAuthHeight: 150
    property var resultHandler

    width: proxyAuthWidth
    height: proxyAuthHeight
    minimumWidth: proxyAuthWidth
    minimumHeight: proxyAuthHeight
    maximumWidth: proxyAuthWidth
    maximumHeight: proxyAuthHeight

    ColumnLayout {
        anchors.fill: parent
        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        spacing: 10

        Label {
            text: qsTr("Proxy Authentication Required")
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: proxyUsername
            placeholderText: qsTr("Username")
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
        }

        TextField {
            id: proxyPassword
            placeholderText: qsTr("Password")
            echoMode: TextInput.Password
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            onAccepted: submitButton.clicked()
        }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button {
                id: submitButton
                text: qsTr("Submit")
                flat: false
                highlighted: true
                enabled: proxyUsername.length > 0 && proxyPassword.length > 0
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    console.log("Submit button clicked")
                    updaterModel.setProxyCredentials(proxyUsername.text, proxyPassword.text)
                    proxyAuthWindow.visible = false
                    resultHandler.showAndCheckForUpdates()
                    proxyUsername.text = ""
                    proxyPassword.text = ""
                }
            }
            Button {
                id: cancelButton
                text: qsTr("Cancel")
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    proxyAuthWindow.visible = false
                    resultHandler.showWithoutUpdate()
                    proxyUsername.text = ""
                    proxyPassword.text = ""
                }
            }
        }
    }
}
