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
import "qrc:/src/views/errors"


ApplicationWindow {
    id: rootWindow
    width: 1100
    height: 650
    visible: true
    visibility: IS_MOBILE ? Window.Maximized : Window.AutomaticVisibility
    title: "CycloneDDS Insight"

    property bool isDarkMode: false
    property bool shutdownInitiated: false
    readonly property int problemCount: errorCenter.count
    readonly property int totalProblemCount: errorCenter.totalCount

    function openProblems() {
        errorCenter.openProblems()
    }

    header: HeaderToolBar {}

    menuBar: MenuBar {
        visible: Qt.platform.os === "osx"
        Menu {
            title: qsTrId("general.file")
            MenuItem {
                text: qsTrId("general.export.ddsentities")
                onTriggered: exportDdsSystemFileDialog.open()
            }
        }
        Menu {
            title: qsTrId("general.view")
            MenuItem {
                text: qsTrId("general.configeditor")
                onTriggered: layout.currentIndex = 2
            }
            MenuItem {
                text: qsTrId("general.shapedemo")
                onTriggered: rootWindow.openShapesDemo()
            }
            MenuItem {
                text: qsTrId("log.show")
                onTriggered: rootWindow.openLogs()
            }
        }
        Menu {
            title: qsTrId("general.help")

            MenuItem {
                text: qsTrId("general.about")
                onTriggered: rootWindow.openAbout()
            }
            MenuItem {
                text: qsTrId("general.settings")
                onTriggered: layout.currentIndex = 0
            }
            MenuItem {
                text: qsTrId("general.checkupdates")
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

        Loader {
            id: configEditorLoader
            // Create the editor with a visible viewport, not on a hidden page
            // during startup. Keep it alive afterwards to retain editor state.
            active: false
            readonly property bool pageReady: visible && width > 0 && height > 0
                                              && layout.currentIndex === 2
            function loadEditor() {
                if (pageReady)
                    active = true
            }
            onPageReadyChanged: {
                if (pageReady)
                    Qt.callLater(loadEditor)
            }
            sourceComponent: ConfigEditorView {
                id: configEditorViewId
            }
        }

        DetachableView {
            id: shapesDemoHost
            title: qsTrId("shapes.title")
            onDocked: {
                if (!rootWindow.shutdownInitiated)
                    layout.currentIndex = 3
            }
            viewComponent: Component {
                ShapesDemoView {
                    viewHost: shapesDemoHost
                }
            }
        }

        DetachableView {
            id: aboutHost
            title: qsTrId("about.window.title")
            windowWidth: 640
            windowHeight: 400
            onDocked: {
                if (!rootWindow.shutdownInitiated)
                    layout.currentIndex = 4
            }
            viewComponent: Component {
                AboutView {
                    viewHost: aboutHost
                }
            }
        }

        DetachableView {
            id: logHost
            title: qsTrId("log.application")
            windowWidth: 860
            windowHeight: 520
            onDocked: {
                if (!rootWindow.shutdownInitiated)
                    layout.currentIndex = 5
            }
            viewComponent: Component {
                LogView {
                    viewHost: logHost
                }
            }
        }
    }

    AddDomainView {
        id: addDomainView
    }

    MessageDialog {
        id: noDomainSelectedDialog
        title: qsTrId("general.alert");
        text: qsTrId("general.no.domain.selected");
        buttons: MessageDialog.Ok;
    }

    function showOperationError(message) {
        errorCenter.addError(message)
    }

    ErrorCenter {
        id: errorCenter
    }

    IdlDropArea {
        id: idlDropAreaId
    }

    QosSelector {
        id: readerTesterDialogId
        parent: rootWindow.contentItem
        model: datamodelRepoModel
    }

    function getDarkMode() {
        var isDarkModeVal = (Application.styleHints.colorScheme === Qt.ColorScheme.Dark)
        console.log("darkmode:", isDarkModeVal)
        return isDarkModeVal
    }

    Connections {
        target: datamodelRepoModel
        function onIsLoadingSignal(loading) {
            loadingViewId.visible = loading
        }
        function onOperationError(message) {
            rootWindow.showOperationError(message)
        }
    }

    Connections {
        target: testerModel
        function onOperationError(message) {
            rootWindow.showOperationError(message)
        }
    }

    Connections {
        target: qmlUtils
        function onOperationError(message) {
            rootWindow.showOperationError(message)
        }
    }

    LoadingView {
        id: loadingViewId
        visible: false
    }

    function shutdown() {
        if (!shutdownInitiated) {
            shutdownInitiated = true
            shapesDemoHost.shutdown()
            aboutHost.shutdown()
            logHost.shutdown()
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

    function openLogs() {
        layout.currentIndex = 5
        logHost.present()
    }

    function openAbout() {
        layout.currentIndex = 4
        aboutHost.present()
    }

    function openShapesDemo() {
        layout.currentIndex = 3
        shapesDemoHost.present()
    }

    FileDialog {
        id: exportDdsSystemFileDialog
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        title: qsTrId("export.dds.dialog")
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
