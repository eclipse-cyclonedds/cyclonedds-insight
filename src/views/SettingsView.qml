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
import "qrc:/src/views/selection_details"


Rectangle {
    id: settingsViewId
    color: Constants.mainContentColor(rootWindow.isDarkMode)
    property int port: 8080
    readonly property color surfaceColor: Constants.cardBackgroundColor(rootWindow.isDarkMode)
    readonly property color borderColor: Constants.designBorderColor(rootWindow.isDarkMode)
    readonly property color secondaryTextColor: Constants.secondaryTextColor(rootWindow.isDarkMode)

    Settings {
        id: proxySettings
        category: "proxy"
        property alias enabled: useProxyCheckBox.checked
        property alias host: httpProxy.text
        property alias port: settingsViewId.port
    }

    Settings {
        category: "general"
        property alias domains: defaultDomainsTextField.text
    }

    ScrollView {
        id: settingsScrollView
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            x: 16
            width: Math.max(0, settingsScrollView.availableWidth - 32)
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                spacing: 9

                DetailBadge {
                    kind: "settings"
                }

                Label {
                    text: qsTrId("general.settings")
                    font.pixelSize: Constants.pageTitleFontSize
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: configurationLayout.implicitHeight + 24
                radius: Constants.cardRadius
                color: settingsViewId.surfaceColor
                border.width: 1
                border.color: settingsViewId.borderColor

                ColumnLayout {
                    id: configurationLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    Label {
                        Layout.fillWidth: true
                        text: qsTrId("settings.configuration")
                        font.pixelSize: Constants.sectionTitleFontSize
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Constants.separatorColor(rootWindow.isDarkMode)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: qsTrId("settings.config.use.environment")
                            wrapMode: Text.WordWrap
                        }
                        Switch {
                            Accessible.name: qsTrId("settings.config.use.environment")
                            checked: ddsConfig.selectedSource === "environment"
                            onClicked: {
                                if (checked)
                                    ddsConfig.useStartupConfiguration()
                                else
                                    ddsConfig.useManagedConfiguration()
                            }
                        }
                    }
                    Label {
                        text: "CYCLONEDDS_URI"
                        color: settingsViewId.secondaryTextColor
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        TextField {
                            Layout.fillWidth: true
                            text: ddsConfig.selectedSource === "xml" ? ddsConfig.editorXml : ddsConfig.startupUri
                            placeholderText: qsTr("Not set")
                            readOnly: true
                            selectByMouse: true
                        }
                        Button {
                            text: qsTrId("settings.config.edit")
                            onClicked: layout.currentIndex = 2
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        visible: ddsConfig.restartRequired || ddsConfig.status.length > 0
                        text: ddsConfig.status || (ddsConfig.restartRequired ? qsTr("Restart required") : "")
                        color: settingsViewId.secondaryTextColor
                    }

                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: appearanceLayout.implicitHeight + 24
                radius: Constants.cardRadius
                color: settingsViewId.surfaceColor
                border.width: 1
                border.color: settingsViewId.borderColor

                ColumnLayout {
                    id: appearanceLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8

                    Label {
                        text: qsTrId("settings.appearance")
                        font.pixelSize: Constants.sectionTitleFontSize
                        font.bold: true
                    }

                    Label {
                        text: qsTrId("settings.appearance.description")
                        color: settingsViewId.secondaryTextColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        RadioButton {
                            text: qsTrId("settings.theme.system")
                            checked: true
                            onClicked: if (checked) qmlUtils.setColorScheme(0)
                        }

                        RadioButton {
                            text: qsTrId("settings.theme.light")
                            onClicked: if (checked) qmlUtils.setColorScheme(1)
                        }

                        RadioButton {
                            text: qsTrId("settings.theme.dark")
                            onClicked: if (checked) qmlUtils.setColorScheme(2)
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: proxyLayout.implicitHeight + 24
                radius: Constants.cardRadius
                color: settingsViewId.surfaceColor
                border.width: 1
                border.color: settingsViewId.borderColor

                ColumnLayout {
                    id: proxyLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            text: qsTrId("settings.proxy.settings")
                            font.pixelSize: Constants.sectionTitleFontSize
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        CheckBox {
                            id: useProxyCheckBox
                            text: qsTrId("settings.proxy.use")
                            onCheckedChanged: proxySettings.enabled = checked
                            Component.onCompleted: checked = proxySettings.enabled
                        }
                    }

                    Label {
                        text: qsTrId("settings.proxy.description")
                        color: settingsViewId.secondaryTextColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        enabled: useProxyCheckBox.checked
                        opacity: enabled ? 1 : 0.45
                        spacing: 8

                        Label {
                            text: qsTrId("settings.proxy.http")
                            color: settingsViewId.secondaryTextColor
                        }

                        TextField {
                            id: httpProxy
                            Layout.fillWidth: true
                            Component.onCompleted: text = proxySettings.host
                            onTextChanged: proxySettings.host = text
                        }

                        Label {
                            text: qsTrId("settings.proxy.port")
                            color: settingsViewId.secondaryTextColor
                        }

                        TextField {
                            id: portTextField
                            Layout.preferredWidth: 80
                            text: "0"
                            validator: IntValidator {
                                bottom: 0
                                top: 65535
                            }
                            Component.onCompleted: text = proxySettings.port
                            onTextChanged: {
                                const parsedPort = parseInt(text)
                                settingsViewId.port = isNaN(parsedPort)
                                                      ? 0
                                                      : parsedPort
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: domainsLayout.implicitHeight + 24
                radius: Constants.cardRadius
                color: settingsViewId.surfaceColor
                border.width: 1
                border.color: settingsViewId.borderColor

                ColumnLayout {
                    id: domainsLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8

                    Label {
                        text: qsTrId("settings.default_domains.label")
                        font.pixelSize: Constants.sectionTitleFontSize
                        font.bold: true
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTrId("settings.default_domains.description")
                        color: settingsViewId.secondaryTextColor
                        wrapMode: Text.Wrap
                    }

                    TextField {
                        id: defaultDomainsTextField
                        Layout.fillWidth: true
                        placeholderText: "0,1,2"
                        validator: RegularExpressionValidator {
                            regularExpression: /^((0|[1-9]\d?|1\d\d|2[0-1]\d|22\d|23[0-2])(,(0|[1-9]\d?|1\d\d|2[0-1]\d|22\d|23[0-2]))*)?$/
                        }
                        onTextChanged: {
                            const parts = text.split(",")
                            const seen = new Set()
                            for (let i = 0; i < parts.length; ++i) {
                                if (parts[i] !== "" && seen.has(parts[i])) {
                                    text = parts.slice(0, i)
                                                .concat(parts.slice(i + 1))
                                                .join(",")
                                    return
                                }
                                seen.add(parts[i])
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: appDataLayout.implicitHeight + 24
                radius: Constants.cardRadius
                color: settingsViewId.surfaceColor
                border.width: 1
                border.color: settingsViewId.borderColor

                ColumnLayout {
                    id: appDataLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    Label {
                        Layout.fillWidth: true
                        text: qsTrId("settings.appdata.location")
                        font.pixelSize: Constants.sectionTitleFontSize
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: StandardPaths.writableLocation(StandardPaths.AppDataLocation)
                        color: settingsViewId.secondaryTextColor
                        wrapMode: Text.WrapAnywhere
                    }
                    Button {
                        text: qsTrId("settings.folder.open")
                        onClicked: Qt.openUrlExternally(
                                       StandardPaths.writableLocation(
                                           StandardPaths.AppDataLocation))
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: settingsFileLayout.implicitHeight + 24
                radius: Constants.cardRadius
                color: settingsViewId.surfaceColor
                border.width: 1
                border.color: settingsViewId.borderColor

                ColumnLayout {
                    id: settingsFileLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    Label {
                        Layout.fillWidth: true
                        text: qsTrId("settings.storage.location")
                        font.pixelSize: Constants.sectionTitleFontSize
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: ddsConfig.settingsFile
                        color: settingsViewId.secondaryTextColor
                        wrapMode: Text.WrapAnywhere
                    }
                    Button {
                        text: qsTr("Open file")
                        enabled: ddsConfig.settingsFileAvailable
                        onClicked: ddsConfig.openSettingsFile()
                    }
                }
            }

            Item {
                Layout.preferredHeight: 2
            }
        }
    }
}
