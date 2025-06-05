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
import QtQuick.Dialogs

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"


Rectangle {
    id: settingsViewId
    color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground
    property string fileContent: ""
    property bool configFileAvailable: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 5
        anchors.topMargin: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 10

        Label {
            text: "Configuration Editor"
            font.bold: true
            font.pointSize: 16
            Layout.alignment: Qt.AlignLeft
        }

        RowLayout {
            spacing: 0
            Label {
                text: "Available options can be found "
            }
            Label {
                text: "here"
                font.underline: true
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://github.com/eclipse-cyclonedds/cyclonedds/blob/master/docs/manual/options.md")
                }
            }
            Label {
                text: "."
            }
        }

        Label {
            id: uriLabel
            text: "CYCLONEDDS_URI: " + CYCLONEDDS_URI
            font.bold: true
        }

        ScrollView {
            id: scrollView
            visible: configFileAvailable
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextArea {
                id: textArea
                text: fileContent
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                selectByKeyboard: true
                onTextChanged: qmlUtils.saveFileContent(CYCLONEDDS_URI, text)
            }
        }

        Label {
            visible: !configFileAvailable 
            text: "No file found in the env variable CYCLONEDDS_URI."
        }

        Button {
            id: reloadButton
            text: "Create New Configuration"
            visible: !configFileAvailable 
            Layout.alignment: Qt.AlignLeft
            onClicked: {
                fileDialog.open()
            }
        }

        Label {
            visible: configFileAvailable
            text: "Changes will take effect after restarting the application."
        }

        TextEdit {
            id: envHintText
            visible: false
            text: ""
            readOnly: true
            wrapMode: Text.WordWrap
            selectByMouse: true
            color: uriLabel.color
        }

        Item {
            visible: !configFileAvailable
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    FileDialog {
        id: fileDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "xml"
        title: "Create New Configuration File"
        onAccepted: {
            qmlUtils.createFile(selectedFile)
            envHintText.text = "The new configuration file has been created.\n\nSet the env-variable:\nCYCLONEDDS_URI=" + selectedFile + "\n\nAnd restart the application."
            envHintText.visible = true
            var defaultConfig = `<?xml version="1.0" encoding="UTF-8" ?>
<CycloneDDS xmlns="https://cdds.io/config" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="https://cdds.io/config https://raw.githubusercontent.com/eclipse-cyclonedds/cyclonedds/master/etc/cyclonedds.xsd">
    <Domain Id="any">
        <General>
            <Interfaces>
                <NetworkInterface autodetermine="true" priority="default" multicast="default" />
            </Interfaces>
        </General>
    </Domain>
</CycloneDDS>
`;
            qmlUtils.saveFileContent(selectedFile, defaultConfig);
        }
    }

    Component.onCompleted: {
        if (qmlUtils.isValidFile(CYCLONEDDS_URI) && CYCLONEDDS_URI !== "<not set>" && CYCLONEDDS_URI !== "") {
            configFileAvailable = true;
            fileContent = qmlUtils.loadFileContent(CYCLONEDDS_URI)
            textArea.text = fileContent
        } else {
            configFileAvailable = false;
        }
    }
}
