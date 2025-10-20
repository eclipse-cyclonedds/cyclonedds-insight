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
import QtQuick.Dialogs
import QtQuick.Layouts
import QtCharts
import Qt.labs.qmlmodels

import "qrc:/src/views"


ApplicationWindow {
    id: rootWindow
    width: 300
    height: 300
    visible: true
    title: "CycloneDDS Insight Updater"
    flags: Qt.Window | Qt.WindowTitleHint | Qt.CustomizeWindowHint
    maximumWidth: width
    maximumHeight: height
    minimumWidth: width
    minimumHeight: height

    property bool isDarkMode: false
    property bool shutdownInitiated: false

    Component.onCompleted: {
        rootWindow.isDarkMode = getDarkMode()
        rootWindow.startUpdate()
    }

    function startUpdate() {
        console.info("Target app dir:", APPDIR)
        updaterView.startUpdate(ORGANIZATION, PROJECT, NEWBUILDID, APPDIR)
    }

    function getDarkMode() {
        var isDarkModeVal = (mySysPalette.windowText.hsvValue > mySysPalette.window.hsvValue)
        console.log("darkmode:", isDarkModeVal)
        return isDarkModeVal
    }

    SystemPalette {
        id: mySysPalette
        onDarkChanged: {
            rootWindow.isDarkMode = getDarkMode()
        }
    }

    UpdaterView {
        id: updaterView
        visible: true
    }

    ProxyAuthWindow {
        id: proxyAuthWindowUpdater
        resultHandler: updaterView
        visible: false
    }

}