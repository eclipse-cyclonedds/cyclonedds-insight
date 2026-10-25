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
import "selection_details"
import "elements"

import org.eclipse.cyclonedds.insight

Popup {
    id: discoveryPopup
    objectName: "domainDiscoveryPopup"
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    width: Math.min(480, rootWindow.width - 2 * Constants.pageMargin)
    height: Math.min(implicitHeight, rootWindow.height - 2 * Constants.pageMargin)
    padding: Constants.pageMargin
    onOpened: {
        if (treeModel.scanner.running || treeModel.joiningDomains)
            hideButton.forceActiveFocus()
        else
            startButton.forceActiveFocus()
    }

    background: Rectangle {
        color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
        radius: Constants.cardRadius
        border.width: 1
        border.color: Constants.designBorderColor(rootWindow.isDarkMode)
    }

    contentItem: ScrollView {
        id: scrollView
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        implicitHeight: content.implicitHeight
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            id: content
            width: scrollView.availableWidth
            spacing: 8

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTrId("domain.discover.automatically")
                font.bold: true
                font.pixelSize: Constants.sectionTitleFontSize
                color: Constants.secondaryTextColor(rootWindow.isDarkMode)
            }
            Label {
                visible: treeModel.joiningDomains || treeModel.scanner.state !== "idle"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Constants.captionFontSize
                color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                text: treeModel.joiningDomains
                      ? qsTrId("domain.scan.joining").arg(treeModel.pendingDomainIds.length)
                      : treeModel.scanner.running
                        ? qsTrId("domain.scan.quick")
                        : treeModel.scanner.state === "cancelled"
                          ? qsTrId("domain.scan.cancelled")
                          : treeModel.scanner.state === "incomplete"
                            ? qsTrId("domain.scan.incomplete") : qsTrId("domain.scan.complete")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ProgressBar {
                    objectName: "domainDiscoveryProgress"
                    Layout.fillWidth: true
                    from: 0
                    to: Math.max(1, treeModel.scanner.total)
                    value: treeModel.scanner.completed
                }
                Label {
                    objectName: "domainDiscoveryElapsed"
                    readonly property int minutes: Math.floor(treeModel.scanner.elapsedSeconds / 60)
                    readonly property int seconds: treeModel.scanner.elapsedSeconds % 60
                    text: (minutes < 10 ? "0" : "") + minutes + ":"
                          + (seconds < 10 ? "0" : "") + seconds
                    font.pixelSize: Constants.captionFontSize
                    color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                }
                IconActionButton {
                    objectName: "domainDiscoveryStopButton"
                    visible: treeModel.scanner.running
                    enabled: treeModel.scanner.state !== "cancelled"
                    opacity: enabled ? 1 : 0.5
                    icon: "stop"
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTrId("general.stop")
                    Accessible.onPressAction: clicked()
                    activeFocusOnTab: true
                    Keys.onSpacePressed: clicked()
                    Keys.onReturnPressed: clicked()
                    onClicked: treeModel.scanner.cancel()
                }
            }
            Label {
                objectName: "domainDiscoveryProgressLabel"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Constants.bodyFontSize
                color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                text: qsTrId("domain.scan.progress").arg(treeModel.scanner.completed)
                        .arg(treeModel.scanner.total).arg(treeModel.scanner.foundCount)
            }
            ListView {
                id: resultList
                objectName: "domainDiscoveryResults"
                visible: count > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 160)
                clip: true
                model: treeModel.scanner.candidateDomains
                ScrollBar.vertical: ScrollBar {
                    policy: resultList.contentHeight > resultList.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                }
                delegate: RowLayout {
                    required property var modelData
                    readonly property bool pending: treeModel.pendingDomainIds.indexOf(modelData) !== -1
                    width: resultList.width - 12
                    height: 36
                    spacing: 6
                    DetailBadge {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        color: "transparent"
                        iconColor: domainLabel.color
                        kind: "domain"
                    }
                    Label {
                        id: domainLabel
                        Layout.fillWidth: true
                        text: qsTrId("entity.domain.value").arg(modelData)
                        color: Constants.secondaryTextColor(rootWindow.isDarkMode)
                    }
                    Label {
                        visible: pending
                        text: qsTrId("domain.scan.joining.one")
                        color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                        font.pixelSize: Constants.captionFontSize
                    }
                    Button {
                        objectName: "domainDiscoveryJoin_" + modelData
                        visible: !pending
                        text: qsTrId("domain.scan.join.one")
                        Accessible.name: qsTrId("domain.scan.join").arg(modelData)
                        enabled: !treeModel.joiningDomains
                        onClicked: treeModel.joinDiscoveredDomains([modelData])
                    }
                }
            }
            Flow {
                visible: treeModel.scanner.candidateDomains.length > 0
                Layout.fillWidth: true
                spacing: 6
                Button {
                    objectName: "domainDiscoveryJoinAllButton"
                    text: qsTrId("domain.scan.join.all").arg(treeModel.scanner.candidateDomains.length)
                    enabled: !treeModel.joiningDomains
                    onClicked: treeModel.joinDiscoveredDomains(treeModel.scanner.candidateDomains)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Item { Layout.fillWidth: true }
                Button {
                    id: startButton
                    objectName: "domainDiscoveryStartButton"
                    visible: !treeModel.scanner.running
                    text: qsTrId("domain.scan.start")
                    highlighted: true
                    enabled: !treeModel.joiningDomains
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                    onClicked: treeModel.scanDomains()
                }
                Button {
                    id: hideButton
                    objectName: "domainDiscoveryHideButton"
                    text: qsTrId("general.hide")
                    onClicked: discoveryPopup.close()
                }
            }
        }
    }
}
