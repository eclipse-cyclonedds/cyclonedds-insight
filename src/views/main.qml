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


ApplicationWindow {
    id: rootWindow
    width: 1100
    height: 650
    visible: true
    title: "CycloneDDS Insight"

    property bool isDarkMode: false

    header: HeaderToolBar {}

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

    ReaderTester {
        id: readerTesterDialogId
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

}
