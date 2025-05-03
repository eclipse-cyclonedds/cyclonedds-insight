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

    function showView(name, data) {
        stackView.clear()
        if (childView) {
            childView.destroy()
        }
        console.log("Create component " + name)
        var childComponent = Qt.createComponent("qrc:/src/views/" + name)
        if (childComponent.status === Component.Ready) {
            childView = childComponent.createObject(stackView, data);
            stackView.replace(childView);
        } else {
            console.log("Failed to create component " + name)
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

    function showParticipantView(domainId) {
        showView("selection_details/ParticipantView.qml", {
                            domainId: domainId
                        })
    }

    function showTopicEndpointView(domainId, topicName) {
        showView("selection_details/TopicEndpointView.qml", {
                            domainId: domainId,
                            topicName: topicName
                        })
    }

    function showEndpointView(domainId) {
        showView("selection_details/EndpointView.qml", {
                            domainId: domainId
                        })
    }

    function aboutToClose() {
        if (childView) {
            childView.destroy()
        }
        if (stackView) {
            stackView.clear()
        }
    }
}
