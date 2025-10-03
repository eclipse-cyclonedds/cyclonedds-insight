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


SplitView {
    orientation: Qt.Horizontal

    property var childView

    SplitView {
        orientation: Qt.Vertical

        implicitWidth: 350
        SplitView.minimumWidth: 50
        
        Rectangle {
            id: domainSplit
            color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

            SplitView.minimumHeight: 50
            SplitView.fillHeight: true

            SideView {}
        }

        Rectangle {
            id: datamodelSplit
            color: rootWindow.isDarkMode ? Constants.darkOverviewBackground : Constants.lightOverviewBackground

            SplitView.minimumHeight: 50
            SplitView.preferredHeight: parent.height / 3

            DataModelOverview {}
        }
    }

    Rectangle {
        id: centerItem
        SplitView.minimumWidth: 50
        SplitView.fillWidth: true
        color: rootWindow.isDarkMode ? Constants.darkMainContentBackground : Constants.lightMainContentBackground

        Column {
            anchors.fill: parent

            TabBar {
                id: bar
                width: parent.width

                TabButton {
                    text: qsTr("Details")
                    width: implicitWidth + 20
                }
                TabButton {
                    text: qsTr("Statistics")
                    width: implicitWidth + 20
                }
                TabButton {
                    text: qsTr("Tester")
                    width: implicitWidth + 20
                }
                TabButton {
                    text: qsTr("Listener")
                    width: implicitWidth + 20
                }
            }
            StackLayout {
                id: mainLayoutId
                width: parent.width
                height: parent.height - bar.height
                currentIndex: bar.currentIndex
                Item {
                    id: inspectTab

                    Label {
                        text: "Nothing Selected"
                        anchors.centerIn: parent
                    }

                    StackView {
                        id: stackView
                        anchors.fill: parent
                    }
                }
                Item {
                    id: statisticsTab

                    StatisticsWindow {
                        id: statisticsWindow
                    }
                }
                Item {
                    id: testerTab

                    TesterView {}
                }
                Item {
                    id: listenerTab

                    ListenerView {}
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

    function showParticipantView(domainId, pkey) {
        showView("selection_details/ParticipantView.qml", {
                            domainId: domainId,
                            participantKey: pkey
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

    function switchToTab(targetIndex) {
        mainLayoutId.currentIndex = targetIndex
        bar.currentIndex = targetIndex
    }

}
