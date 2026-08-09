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
import "qrc:/src/views/statistics"
import "qrc:/src/views/elements"
import "qrc:/src/views/icons"
import "qrc:/src/views/selection_details"


SplitView {
    id: overviewRoot
    orientation: Qt.Horizontal

    property var childView
    property bool splitDetails: false
    property bool splitStatistics: false
    property bool splitTester: false
    property bool splitListener: false
    property bool splitModeActive: false
    property bool sidebarCollapsed: false
    property int sidebarExpandedWidth: 350
    readonly property int sidebarCollapsedWidth: 30
    readonly property int splitViewCount:
        (splitDetails ? 1 : 0)
        + (splitStatistics ? 1 : 0)
        + (splitTester ? 1 : 0)
        + (splitListener ? 1 : 0)
    readonly property bool multiViewEnabled: splitModeActive

    Item {
        id: sidebarPane
        implicitWidth: overviewRoot.sidebarExpandedWidth
        SplitView.minimumWidth: overviewRoot.sidebarCollapsed
                                ? overviewRoot.sidebarCollapsedWidth
                                : 180
        SplitView.maximumWidth: overviewRoot.sidebarCollapsed
                                ? overviewRoot.sidebarCollapsedWidth
                                : 100000
        SplitView.preferredWidth: overviewRoot.sidebarCollapsed
                                  ? overviewRoot.sidebarCollapsedWidth
                                  : overviewRoot.sidebarExpandedWidth

        onWidthChanged: {
            if (!overviewRoot.sidebarCollapsed && width > 180) {
                overviewRoot.sidebarExpandedWidth = width
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Constants.overviewBackgroundColor(rootWindow.isDarkMode)
        }

        SplitView {
            id: sidebarContent
            anchors.fill: parent
            orientation: Qt.Vertical
            visible: !overviewRoot.sidebarCollapsed

            Rectangle {
                id: domainSplit
                color: Constants.overviewBackgroundColor(rootWindow.isDarkMode)

                SplitView.minimumHeight: 50
                SplitView.fillHeight: true

                SideView {}
            }

            Rectangle {
                id: datamodelSplit
                color: Constants.overviewBackgroundColor(rootWindow.isDarkMode)

                SplitView.minimumHeight: 50
                SplitView.preferredHeight: parent.height / 3

                DataModelOverview {}
            }
        }

        Rectangle {
            id: sidebarCollapseButton
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 42
            radius: Constants.controlRadius
            color: sidebarCollapseMouseArea.containsMouse
                   ? rootWindow.isDarkMode ? "#383838" : "#e9e9e9"
                   : Constants.cardBackgroundColor(rootWindow.isDarkMode)
            border.width: 1
            border.color: Constants.designBorderColor(rootWindow.isDarkMode)
            z: 2

            ArrowIcon {
                anchors.centerIn: parent
                width: 14
                height: 14
                direction: overviewRoot.sidebarCollapsed ? "right" : "left"
                iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
                lineWidth: 2
            }

            MouseArea {
                id: sidebarCollapseMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: overviewRoot.toggleSidebar()
            }

            ToolTip {
                id: sidebarCollapseTooltip
                parent: sidebarCollapseButton
                visible: sidebarCollapseMouseArea.containsMouse
                delay: 500
                text: overviewRoot.sidebarCollapsed
                      ? qsTrId("sidebar.show")
                      : qsTrId("sidebar.hide")
                contentItem: Label {
                    text: sidebarCollapseTooltip.text
                }
                background: Rectangle {
                    border.width: 1
                    border.color: Constants.borderColor(rootWindow.isDarkMode)
                    color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
                }
            }
        }
    }

    Rectangle {
        id: centerItem
        SplitView.minimumWidth: 50
        SplitView.fillWidth: true
        color: Constants.mainContentColor(rootWindow.isDarkMode)

        Column {
            anchors.fill: parent

            Item {
                id: bar
                property int currentIndex: 0

                width: parent.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    color: Constants.headerBackgroundColor(rootWindow.isDarkMode)
                }

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 4
                    spacing: 0

                    InsightTabButton {
                        tabText: qsTrId("tab.details")
                        checked: overviewRoot.multiViewEnabled
                                 ? overviewRoot.splitDetails
                                 : bar.currentIndex === 0
                        paneToggleMode: overviewRoot.multiViewEnabled
                        paneIncluded: overviewRoot.splitDetails
                        paneToggleToolTip:
                            overviewRoot.tabToggleToolTip(0)
                        onClicked: overviewRoot.activateView(0)
                        height: parent.height
                        width: 150
                    }
                    InsightTabButton {
                        tabText: qsTrId("tab.statistics")
                        checked: overviewRoot.multiViewEnabled
                                 ? overviewRoot.splitStatistics
                                 : bar.currentIndex === 1
                        paneToggleMode: overviewRoot.multiViewEnabled
                        paneIncluded: overviewRoot.splitStatistics
                        paneToggleToolTip:
                            overviewRoot.tabToggleToolTip(1)
                        showLeftSeparator: overviewRoot.multiViewEnabled
                                           ? !overviewRoot.splitDetails
                                             && !overviewRoot.splitStatistics
                                           : bar.currentIndex !== 0
                                             && bar.currentIndex !== 1
                        onClicked: overviewRoot.activateView(1)
                        height: parent.height
                        width: 150
                    }
                    InsightTabButton {
                        tabText: qsTrId("tab.tester")
                        checked: overviewRoot.multiViewEnabled
                                 ? overviewRoot.splitTester
                                 : bar.currentIndex === 2
                        paneToggleMode: overviewRoot.multiViewEnabled
                        paneIncluded: overviewRoot.splitTester
                        paneToggleToolTip:
                            overviewRoot.tabToggleToolTip(2)
                        showLeftSeparator: overviewRoot.multiViewEnabled
                                           ? !overviewRoot.splitStatistics
                                             && !overviewRoot.splitTester
                                           : bar.currentIndex !== 1
                                             && bar.currentIndex !== 2
                        onClicked: overviewRoot.activateView(2)
                        height: parent.height
                        width: 150
                    }
                    InsightTabButton {
                        tabText: qsTrId("tab.listener")
                        checked: overviewRoot.multiViewEnabled
                                 ? overviewRoot.splitListener
                                 : bar.currentIndex === 3
                        paneToggleMode: overviewRoot.multiViewEnabled
                        paneIncluded: overviewRoot.splitListener
                        paneToggleToolTip:
                            overviewRoot.tabToggleToolTip(3)
                        showLeftSeparator: overviewRoot.multiViewEnabled
                                           ? !overviewRoot.splitTester
                                             && !overviewRoot.splitListener
                                           : bar.currentIndex !== 2
                                             && bar.currentIndex !== 3
                        onClicked: overviewRoot.activateView(3)
                        height: parent.height
                        width: 150
                    }
                }

                Rectangle {
                    visible: overviewRoot.multiViewEnabled
                    anchors.right: sideBySideButton.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: splitViewStatusLabel.implicitWidth + 16
                    height: 22
                    radius: 11
                    color: rootWindow.isDarkMode ? "#26345f" : "#e7ebff"
                    border.width: 1
                    border.color: Constants.accentColor

                    Label {
                        id: splitViewStatusLabel
                        anchors.centerIn: parent
                        text: qsTrId("tab.side-by-side.status").arg(
                                  overviewRoot.splitViewCount)
                        color: rootWindow.isDarkMode ? "#dce3ff" : "#17338f"
                        font.pixelSize: Constants.captionFontSize
                        font.bold: true
                    }
                }

                Rectangle {
                    id: sideBySideButton
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 28
                    radius: Constants.controlRadius
                    color: overviewRoot.splitModeActive
                           ? Constants.mainContentColor(rootWindow.isDarkMode)
                           : sideBySideMouseArea.containsMouse
                             ? rootWindow.isDarkMode ? "#454545" : "#c9c7c7"
                             : "transparent"
                    border.width: 1
                    border.color: overviewRoot.splitModeActive
                                  ? Constants.accentColor
                                  : sideBySideMouseArea.containsMouse
                                    ? Constants.designBorderColor(
                                          rootWindow.isDarkMode)
                                    : "transparent"

                    SplitViewIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 16
                        iconColor: overviewRoot.splitModeActive
                                   ? Constants.accentColor
                                   : Constants.mutedForegroundColor(
                                         rootWindow.isDarkMode)
                    }

                    MouseArea {
                        id: sideBySideMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overviewRoot.toggleSplitMode()
                    }

                    ToolTip {
                        id: sideBySideTooltip
                        parent: sideBySideButton
                        visible: sideBySideMouseArea.containsMouse
                        delay: 500
                        text: overviewRoot.splitModeActive
                              ? qsTrId("tab.side-by-side.disable")
                              : qsTrId("tab.side-by-side.enable")
                        contentItem: Label {
                            text: sideBySideTooltip.text
                        }
                        background: Rectangle {
                            border.width: 1
                            border.color: Constants.borderColor(
                                              rootWindow.isDarkMode)
                            color: Constants.cardBackgroundColor(
                                       rootWindow.isDarkMode)
                        }
                    }

                }
            }
            SplitView {
                id: mainLayoutId
                width: parent.width
                height: parent.height - bar.height
                orientation: Qt.Horizontal

                Item {
                    id: inspectTab
                    visible: overviewRoot.isViewVisible(0)
                    SplitView.minimumWidth: 160
                    SplitView.preferredWidth:
                        mainLayoutId.width / overviewRoot.visibleViewCount()

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(380, Math.max(220, parent.width - 48))
                        spacing: 8

                        DetailBadge {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: 13
                            kind: "selection"
                            iconScale: 1.45
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            text: qsTrId("general.nothing.selected")
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Constants.pageTitleFontSize
                            font.bold: true
                        }

                        Label {
                            Layout.fillWidth: true
                            text: qsTrId("details.selection.hint")
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            color: rootWindow.isDarkMode
                                   ? "#b8b8b8" : "#5c5c5c"
                        }
                    }

                    StackView {
                        id: stackView
                        anchors.fill: parent
                    }
                }
                Item {
                    id: statisticsTab
                    visible: overviewRoot.isViewVisible(1)
                    SplitView.minimumWidth: 160
                    SplitView.preferredWidth:
                        mainLayoutId.width / overviewRoot.visibleViewCount()

                    StatisticsWindow {
                        id: statisticsWindow
                    }
                }
                Item {
                    id: testerTab
                    visible: overviewRoot.isViewVisible(2)
                    SplitView.minimumWidth: 160
                    SplitView.preferredWidth:
                        mainLayoutId.width / overviewRoot.visibleViewCount()

                    TesterView {
                        id: testerView
                    }
                }
                Item {
                    id: listenerTab
                    visible: overviewRoot.isViewVisible(3)
                    SplitView.minimumWidth: 160
                    SplitView.preferredWidth:
                        mainLayoutId.width / overviewRoot.visibleViewCount()
                    SplitView.fillWidth: true

                    ListenerView {
                        id: listenerView
                    }
                }
            }
        }
    }

    function clearView() {
        if (stackView) {
            stackView.clear()
        }
        if (childView) {
            childView.destroy()
        }    
    }

    function toggleSidebar() {
        if (sidebarCollapsed) {
            sidebarCollapsed = false
            sidebarPane.SplitView.preferredWidth = sidebarExpandedWidth
        } else {
            if (sidebarPane.width > 180) {
                sidebarExpandedWidth = sidebarPane.width
            }
            sidebarCollapsed = true
            sidebarPane.SplitView.preferredWidth = sidebarCollapsedWidth
        }
    }

    function showView(name, data) {
        clearView()
        console.log("Create component " + name)
        var childComponent = Qt.createComponent("qrc:/src/views/" + name)
        if (childComponent.status === Component.Ready) {
            childView = childComponent.createObject(stackView, data);
            stackView.replace(childView);
        } else {
            console.log("Failed to create component " + name, childComponent.errorString())
        }
    }

    function showDomainView(domainId) {
        showView("selection_details/DomainView.qml", {
                            domainId: domainId
                        })
    }

    function showHostView(domainId) {
        showView("selection_details/HostView.qml", {
                            domainId: domainId
                        })
    }

    function showProcessView(domainId) {
        showView("selection_details/ProcessView.qml", {
                            domainId: domainId
                        })
    }

    function showParticipantView(domainId, pkey, vendorName) {
        showView("selection_details/ParticipantView.qml", {
                            domainId: domainId,
                            participantKey: pkey,
                            vendorName: vendorName
                        })
    }

    function showTopicEndpointView(domainId, topicName) {
        showView("selection_details/TopicEndpointView.qml", {
                            domainId: domainId,
                            topicName: topicName
                        })
    }

    function showEndpointView(domainId, endpKey) {
        showView("selection_details/EndpointView.qml", {
                            domainId: domainId,
                            endpointKey: endpKey
                        })
    }

    function aboutToClose() {
        statisticsWindow.aboutToClose()
        if (childView && typeof childView.aboutToClose === "function") {
            childView.aboutToClose()
        }
        clearView()
    }

    Shortcut {
        sequences: [ StandardKey.New ]
        sequence: "Ctrl+1"
        onActivated: {
            console.log("Ctrl+1 pressed!")
            switchToTab(0)
        }
    }

    Shortcut {
        sequences: [ StandardKey.New ]
        sequence: "Ctrl+2"
        onActivated: {
            console.debug("Ctrl+2 pressed!")
            switchToTab(1)
        }
    }

    Shortcut {
        sequences: [ StandardKey.New ]
        sequence: "Ctrl+3"
        onActivated: {
            console.debug("Ctrl+3 pressed!")
            switchToTab(2)
        }
    }

    Shortcut {
        sequences: [ StandardKey.New ]
        sequence: "Ctrl+4"
        onActivated: {
            console.debug("Ctrl+4 pressed!")
            switchToTab(3)
        }
    }

    Shortcut {
        sequence: "Ctrl+5"
        onActivated: {
            console.debug("Ctrl+5 pressed!")
            overviewRoot.toggleSplitMode()
        }
    }

    function isSplitViewSelected(index) {
        if (index === 0)
            return splitDetails
        if (index === 1)
            return splitStatistics
        if (index === 2)
            return splitTester
        return splitListener
    }

    function setSplitViewSelected(index, selected) {
        if (index === 0)
            splitDetails = selected
        else if (index === 1)
            splitStatistics = selected
        else if (index === 2)
            splitTester = selected
        else
            splitListener = selected
    }

    function toggleSplitView(index) {
        if (splitModeActive
                && isSplitViewSelected(index)
                && splitViewCount === 1) {
            return
        }
        setSplitViewSelected(index, !isSplitViewSelected(index))
        resetSplitViewWidths()
    }

    function toggleSplitMode() {
        if (splitModeActive) {
            exitSplitMode()
            return
        }

        clearSplitViews()
        setSplitViewSelected(bar.currentIndex, true)
        splitModeActive = true
        resetSplitViewWidths()
    }

    function exitSplitMode() {
        for (let i = 0; i < 4; ++i) {
            if (isSplitViewSelected(i)) {
                bar.currentIndex = i
                break
            }
        }
        splitModeActive = false
        splitDetails = false
        splitStatistics = false
        splitTester = false
        splitListener = false
    }

    function clearSplitViews() {
        splitDetails = false
        splitStatistics = false
        splitTester = false
        splitListener = false
        resetSplitViewWidths()
    }

    function isViewVisible(index) {
        return multiViewEnabled
                ? isSplitViewSelected(index)
                : bar.currentIndex === index
    }

    function visibleViewCount() {
        return multiViewEnabled ? Math.max(1, splitViewCount) : 1
    }

    function resetSplitViewWidths() {
        Qt.callLater(function() {
            const paneWidth = mainLayoutId.width / visibleViewCount()
            inspectTab.SplitView.preferredWidth = paneWidth
            statisticsTab.SplitView.preferredWidth = paneWidth
            testerTab.SplitView.preferredWidth = paneWidth
            listenerTab.SplitView.preferredWidth = paneWidth
        })
    }

    function activateView(index) {
        if (multiViewEnabled) {
            toggleSplitView(index)
        } else {
            bar.currentIndex = index
        }
    }

    function tabToggleToolTip(index) {
        if (splitModeActive
                && isSplitViewSelected(index)
                && splitViewCount === 1) {
            return qsTrId("tab.side-by-side.last-pane")
        }
        return isSplitViewSelected(index)
                ? qsTrId("tab.side-by-side.remove")
                : qsTrId("tab.side-by-side.add")
    }

    function switchToTab(targetIndex) {
        activateView(targetIndex)
    }

}
