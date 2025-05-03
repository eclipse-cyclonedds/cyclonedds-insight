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

import org.eclipse.cyclonedds.insight
import "qrc:/src/views"


Rectangle {
    id: participantViewId
    color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent

    property int domainId

    ColumnLayout  {
        anchors.fill: parent
        anchors.margins: 10

        Label {
            text: qsTr("Participant View")
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignLeft
            Layout.alignment: Qt.AlignLeft
        }
        Label {
            text: qsTr("Domain ID: ") + participantViewId.domainId
        }
    
        Button {
            text: statisticsView.visible ? qsTr("Hide Statistics") : qsTr("Show Statistics")
            onClicked: {
                statisticsView.visible = !statisticsView.visible
                if (statisticsView.visible) {
                    statisticsView.startStatistics()
                } else {
                    statisticsView.stopStatistics()
                }
            }
        }

        StatisticsModel {
            id: statisticModelDomainView
            Component.onDestruction: {
                console.log("DomainView with domainId " + participantViewId.domainId + " is being destroyed.")
                statisticModelDomainView.stop()
            }
        }

        StatisticsView {
            id: statisticsView
            statisticModel: statisticModelDomainView
            domainId: participantViewId.domainId
            visible: false
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Item {
            visible: !statisticsView.visible
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

    }

}
