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

// Own one view for its entire lifetime, moving it between the page and a window.
Item {
    id: host
    required property Component viewComponent
    property string title: ""
    property int windowWidth: 800
    property int windowHeight: 490
    readonly property bool detached: state.detached
    readonly property Item viewItem: viewLoader.item
    signal aboutToMove()
    signal docked()

    QtObject {
        id: state
        property bool detached: false
        property bool shuttingDown: false
    }

    function detach() {
        if (state.shuttingDown || detached)
            return
        aboutToMove()
        state.detached = true
        floatingWindow.show()
        floatingWindow.raise()
        floatingWindow.requestActivate()
    }

    function dock() {
        if (state.shuttingDown || !detached)
            return
        aboutToMove()
        state.detached = false
        floatingWindow.hide()
        docked()
    }

    function present() {
        if (detached) {
            floatingWindow.show()
            floatingWindow.raise()
            floatingWindow.requestActivate()
        }
    }

    function shutdown() {
        state.shuttingDown = true
        floatingWindow.hide()
    }

    Item {
        id: embeddedContainer
        anchors.fill: parent
    }

    // Reparent the Loader, never reload the view or duplicate its model connections.
    Loader {
        id: viewLoader
        parent: host.detached ? floatingWindow.contentItem : embeddedContainer
        anchors.fill: parent
        sourceComponent: host.viewComponent
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - 32, 420))
        visible: host.detached
        spacing: 12

        Label {
            Layout.fillWidth: true
            text: qsTrId("view.detached.message").arg(host.title)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        Button {
            Layout.alignment: Qt.AlignHCenter
            text: qsTrId("view.detached.show")
            onClicked: host.present()
        }
        Button {
            Layout.alignment: Qt.AlignHCenter
            text: qsTrId("view.dock")
            onClicked: host.dock()
        }
    }

    SecondaryWindow {
        id: floatingWindow
        title: host.title
        width: host.windowWidth
        height: host.windowHeight
        minimumWidth: mobileWindow ? 0 : 400
        minimumHeight: mobileWindow ? 0 : 320
        transientParent: host.Window.window
        onClosing: function(close) {
            if (!state.shuttingDown)
                host.dock()
            close.accepted = true
        }
    }
}
