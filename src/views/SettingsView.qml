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

import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import org.eclipse.cyclonedds.insight


Rectangle {
    id: settingsViewId
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground
    property int port: 8080

    Settings {
        id: proxySettings
        category: "proxy"
        property alias enabled: useProxyCheckBox.checked
        property alias host: httpProxy.text
        property alias port: settingsViewId.port
    }

    ScrollView {
        anchors.fill: parent

        GridLayout {
            columns: 2
            anchors.fill: parent
            anchors.margins: 10
            rowSpacing: 10
            columnSpacing: 10

            Label {
                text: qsTr("Settings")
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Item {}

            Label {
                id: cycloneUriLabelId
                text: "CYCLONEDDS_URI:"
            }
            TextField {
                id: login
                text: CYCLONEDDS_URI
                Layout.preferredWidth: settingsViewId.width - cycloneUriLabelId.width - 30
                Layout.minimumWidth: 200
                readOnly: true
            }

            Item  {}
            Button {
                id: editConfigButton
                text: "Edit Configuration File"
                onClicked: layout.currentIndex = 2
            }

            Label {
                text: qsTr("Appearance:")
            }
            Row {
                RadioButton {
                    text: "Automatic (System)"
                    checked: true
                    checkable: true
                    onClicked: {
                        if (checked) {
                            qmlUtils.setColorScheme(0)
                        }
                    }
                }
                RadioButton {
                    text: "Light"
                    checked: false
                    checkable: true
                    onClicked: {
                        if (checked) {
                            qmlUtils.setColorScheme(1)
                        }
                    }
                }
                RadioButton {
                    text: "Dark"
                    checked: false
                    checkable: true
                    onClicked: {
                        if (checked) {
                            qmlUtils.setColorScheme(2)
                        }
                    }
                }
            }

            Label {
                text: qsTr("AppDataLocation:")
            }
            Button {
                text: "Open Folder"
                onClicked: Qt.openUrlExternally(StandardPaths.writableLocation(StandardPaths.AppDataLocation));
            }

            Label {
                id: proxySettingsLabelId
                text: qsTr("Proxy Settings:")
            }
            CheckBox {
                id: useProxyCheckBox
                checked: false
                text: qsTr("Use HTTP Proxy")
                onCheckedChanged: {
                    proxySettings.enabled = checked
                }
                Component.onCompleted: {
                    checked = proxySettings.enabled
                }
            }

            Item {}
            Row {
                enabled: useProxyCheckBox.checked
                spacing: 0
                Label {
                    id: proxyLabelId
                    text: "HTTP proxy:"
                    rightPadding: 5
                }
                TextField {
                    id: httpProxy
                    text: ""
                    placeholderText: ""
                    width: 200
                    Component.onCompleted: {
                        text = proxySettings.host
                    }
                    onTextChanged: {
                        proxySettings.host = text
                    }
                }
                Label {
                    id: portLabelId
                    text: "Port:"
                    leftPadding: 5
                    rightPadding: 5
                }
                TextField {
                    id: portTextField
                    text: "0"
                    validator: IntValidator {
                        bottom: 0
                        top: 65535
                    }
                    width: 60
                    Component.onCompleted: {
                        portTextField.text = proxySettings.port
                    }
                    onTextChanged: {
                        var port = parseInt(text)
                        if (isNaN(port)) {
                            settingsViewId.port = 0
                        } else {
                            settingsViewId.port = port
                        }
                    }
                }
            }

            Item {}
            Label {
                enabled: useProxyCheckBox.checked
                text: "The proxy is used for update checks and downloading updates."
            }

            Item {
                Layout.columnSpan: 2
                Layout.fillHeight: true
            }
        }
    }
}
