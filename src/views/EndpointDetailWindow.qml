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
import QtCharts 2.15

import org.eclipse.cyclonedds.insight


Window {
    id: endpointDetailWindow
    property string endpointText

    visible: false
    width: 650
    height: 450
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint

    Rectangle {
        anchors.fill: parent
        color: rootWindow.isDarkMode ? Constants.darkMainContent : Constants.lightMainContent
    }

    Label {
        id: colorLabel
        visible: false
    }

    ScrollView {
        anchors.fill: parent

        ColumnLayout {
            width: parent.width

            TextEdit {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: endpointText
                readOnly: true
                wrapMode: Text.WordWrap
                selectByMouse: true
                padding: 10
                color: colorLabel.color
            }

            Rectangle {
                Layout.preferredHeight: 500
                Layout.preferredWidth: endpointDetailWindow.width
                color: "red"
                ChartView {
                    anchors.fill: parent
                    title: "Hello Qt Charts"
                    antialiasing: true

                    LineSeries {
                        name: "Example Data"
                        XYPoint { x: 0; y: 10 }
                        XYPoint { x: 1; y: 20 }
                        XYPoint { x: 2; y: 15 }
                        XYPoint { x: 3; y: 30 }
                    }
                }
            }
        }
    }

}
