/*
 * Copyright(c) 2026 Sven Trittler
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

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"
import "qrc:/src/views/icons"
import "qrc:/src/views/elements"

Item {
    id: errorCenter
    anchors.fill: parent
    z: 1000

    readonly property int count: unacknowledgedCount
    readonly property int totalCount: errorModel.count
    property int unacknowledgedCount: 0
    property string latestMessage: ""

    function addError(message) {
        const text = String(message || qsTrId("errors.unknown"))
        errorModel.append({
            "message": text,
            "timestamp": Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss"),
            "acknowledged": false
        })
        unacknowledgedCount++
        latestMessage = text
        notification.visible = true
        dismissAnimation.stop()
        dismissProgress = 1.0
        dismissAnimation.start()
    }

    function openProblems() {
        dismissAnimation.stop()
        notification.visible = false
        errorsDialog.show()
        errorsDialog.raise()
        errorsDialog.requestActivate()
    }

    function clear() {
        errorModel.clear()
        unacknowledgedCount = 0
        latestMessage = ""
        dismissAnimation.stop()
        notification.visible = false
    }

    function acknowledge(index) {
        if (index < 0 || index >= errorModel.count)
            return
        if (!errorModel.get(index).acknowledged) {
            errorModel.setProperty(index, "acknowledged", true)
            unacknowledgedCount = Math.max(0, unacknowledgedCount - 1)
        }
        if (unacknowledgedCount === 0) {
            latestMessage = ""
            dismissAnimation.stop()
            notification.visible = false
        }
    }

    function removeError(index) {
        if (index < 0 || index >= errorModel.count)
            return
        if (!errorModel.get(index).acknowledged)
            unacknowledgedCount = Math.max(0, unacknowledgedCount - 1)
        errorModel.remove(index)
        if (unacknowledgedCount === 0) {
            latestMessage = ""
            dismissAnimation.stop()
            notification.visible = false
        }
    }

    function acknowledgeAll() {
        if (unacknowledgedCount === 0)
            return
        for (let index = 0; index < errorModel.count; ++index)
            errorModel.setProperty(index, "acknowledged", true)
        unacknowledgedCount = 0
        latestMessage = ""
        dismissAnimation.stop()
        notification.visible = false
    }

    ListModel {
        id: errorModel
    }

    property real dismissProgress: 1.0

    NumberAnimation {
        id: dismissAnimation
        target: errorCenter
        property: "dismissProgress"
        from: 1.0
        to: 0.0
        duration: 6000
        easing.type: Easing.Linear
        onFinished: notification.visible = false
    }

    Rectangle {
        id: notification
        visible: false
        width: Math.min(440, parent.width - 32)
        implicitHeight: notificationContent.implicitHeight + 20
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        radius: Constants.cardRadius
        color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
        border.width: 1
        border.color: Constants.designBorderColor(rootWindow.isDarkMode)

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: Math.max(0, (parent.width - 2) * errorCenter.dismissProgress)
            height: 3
            radius: 1.5
            color: Constants.errorColor
            opacity: 0.85
        }

        RowLayout {
            id: notificationContent
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            WarningTriangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                warningColor: Constants.errorColor
            }

            Label {
                Layout.fillWidth: true
                text: errorCenter.latestMessage
                maximumLineCount: 2
                elide: Text.ElideRight
                wrapMode: Text.Wrap
            }

            Rectangle {
                implicitWidth: detailsLabel.implicitWidth + 18
                implicitHeight: 28
                radius: Constants.controlRadius
                color: detailsMouse.containsMouse
                       ? (rootWindow.isDarkMode ? "#3b3b3b" : "#e7e7e7")
                       : "transparent"
                border.width: 1
                border.color: Constants.designBorderColor(rootWindow.isDarkMode)

                Behavior on color { ColorAnimation { duration: 100 } }

                Label {
                    id: detailsLabel
                    anchors.centerIn: parent
                    text: errorCenter.count === 1
                          ? qsTrId("errors.view.details")
                          : qsTrId("errors.view.count").arg(errorCenter.count)
                    font.bold: true
                }

                MouseArea {
                    id: detailsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: errorCenter.openProblems()
                }
            }

            IconActionButton {
                icon: "close"
                tooltipText: qsTrId("errors.notification.dismiss")
                onClicked: {
                    dismissAnimation.stop()
                    notification.visible = false
                }
            }
        }
    }

    ErrorsDialog {
        id: errorsDialog
        errorModel: errorModel
        activeCount: errorCenter.count
        totalCount: errorCenter.totalCount
        onAcknowledgeRequested: (index) => errorCenter.acknowledge(index)
        onRemoveRequested: (index) => errorCenter.removeError(index)
        onAcknowledgeAllRequested: errorCenter.acknowledgeAll()
        onClearRequested: errorCenter.clear()
    }
}
