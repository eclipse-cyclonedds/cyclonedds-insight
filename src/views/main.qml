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
import "qrc:/src/views/selection_details"
import "qrc:/src/views/shapes_demo"
import "qrc:/src/views/config_editor"
import "qrc:/src/views/updater"


ApplicationWindow {
    id: rootWindow
    width: 1100
    height: 650
    visible: true
    title: "CycloneDDS Insight"

    property bool isDarkMode: false
    property bool shutdownInitiated: false

    header: HeaderToolBar {}

    menuBar: MenuBar {
        visible: Qt.platform.os === "osx"
        Menu {
            title: "File"
            MenuItem {
                text: "Export DDS Entities (JSON)"
                onTriggered: exportDdsSystemFileDialog.open()
            }
        }
        Menu {
            title: "View"
            MenuItem {
                text: "Show Configuration Editor"
                onTriggered: layout.currentIndex = 2
            }
            MenuItem {
                text: "Show Shapes Demo"
                onTriggered: shapeDemoViewId.visible = true
            }
            MenuItem {
                text: "Show Log Window"
                onTriggered: logViewId.visible = true
            }
        }
        Menu {
            title: "Help"

            MenuItem {
                text: "About"
                onTriggered: aboutWindow.visible = true
            }
            MenuItem {
                text: "Settings"
                onTriggered: layout.currentIndex = 0
            }
            MenuItem {
                text: "Check for Updates"
                onTriggered: checkForUpdatesWindow.showAndCheckForUpdates()
            }
        }
    }

    Shortcut {
        sequences: [ StandardKey.New ]
        sequence: "Ctrl+,"
        onActivated: {
            console.debug("Ctrl+, pressed!")
            layout.currentIndex = 0
        }
    }

    Shortcut {
        sequences: [ StandardKey.New ]
        sequence: "Ctrl+0"
        onActivated: {
            console.debug("Ctrl+0 pressed!")
            layout.currentIndex = 1
        }
    }

    AboutWindow {
        id: aboutWindow
    }

    CheckForUpdates {
        id: checkForUpdatesWindow
    }

    UpdaterView {
        id: updaterView
        visible: false
    }

    SystemPalette {
        id: mySysPalette
        onDarkChanged: {
            rootWindow.isDarkMode = getDarkMode()
        }
    }

    Component.onCompleted: {
        console.log("Running on platform.os:", Qt.platform.os)
        rootWindow.isDarkMode = getDarkMode()
    }

    StackLayout {
        id: layout
        anchors.fill: parent
        currentIndex: 1

        SettingsView {
            id: settingsDialog
        }

        Overview {
            id: overviewId
        }

        ConfigEditorView {
            id: configEditorViewId
        }
    }

    AddDomainView {
        id: addDomainView
    }

    MessageDialog {
        id: noDomainSelectedDialog
        title: qsTr("Alert");
        text: qsTr("No Domain selected!");
        buttons: MessageDialog.Ok;
    }

    IdlDropArea {
        id: idlDropAreaId
    }

    QosSelector {
        id: readerTesterDialogId
        model: datamodelRepoModel
    }

    function getDarkMode() {
        var isDarkModeVal = (mySysPalette.windowText.hsvValue > mySysPalette.window.hsvValue)
        console.log("darkmode:", isDarkModeVal)
        return isDarkModeVal
    }

    Connections {
        target: datamodelRepoModel
        function onIsLoadingSignal(loading) {
            loadingViewId.visible = loading
        }
    }

    LoadingView {
        id: loadingViewId
        visible: false
    }

    LogWindow {
        id: logViewId
        visible: false
    }

    function shutdown() {
        if (!shutdownInitiated) {
            shutdownInitiated = true
            console.log("Shutdown QML ...")
            overviewId.aboutToClose()
            treeModel.aboutToClose()  
            console.log("Shutdown QML ... DONE")
        }
    }

    Connections {
        target: qmlUtils
        function onAboutToQuit() {
            console.log("Application is about to quit.")
            shutdown()
        }
    }

    onClosing: (close) => {
        console.log("Received close request.")
        shutdown()
        close.accepted = true
    }

    ShapesDemoView {
        id: shapeDemoViewId
        visible: false
    }

    FileDialog {
        id: exportDdsSystemFileDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        title: "Export DDS System to json"
        onAccepted: {
            qmlUtils.createFileFromQUrl(selectedFile)
            var localPath = qmlUtils.toLocalFile(selectedFile);
            qmlUtils.exportDdsDataAsJson(localPath);
        }
    }

    ProxyAuthWindow {
        id: proxyAuthWindow
        resultHandler: checkForUpdatesWindow
        visible: false
    }

    ProxyAuthWindow {
        id: proxyAuthWindowUpdater
        resultHandler: updaterView
        visible: false
    }
}
