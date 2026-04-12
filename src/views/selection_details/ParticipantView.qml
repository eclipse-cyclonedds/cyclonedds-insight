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
    property string participantKey
    property string vendorName

    ParticipantDetailsModel {
        id: participantModel
    }

    Component.onCompleted: {
        participantModel.start(domainId, participantKey)
    }

    Connections {
        target: participantModel
        function onUpdateQosSignal(qos) {
            qosTextField.text = qos
        }
    }

    ColumnLayout  {
        anchors.fill: parent
        anchors.margins: 10

        Label {
            text: qsTrId("Participant")
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignLeft
            Layout.alignment: Qt.AlignLeft
        }
        Label {
            text: qsTrId("Domain ID: ") + participantViewId.domainId
        }

        Label {
            id: pkeyLabelId
            text: qsTrId("Participant-Key: ") + participantViewId.participantKey
        }

        Label {
            text: qsTrId("Vendor: ") + participantViewId.vendorName
        }

        TextEdit {
            id: qosTextField
            text: ""
            readOnly: true
            wrapMode: Text.WordWrap
            selectByMouse: true
            color: pkeyLabelId.color
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

    }

}
