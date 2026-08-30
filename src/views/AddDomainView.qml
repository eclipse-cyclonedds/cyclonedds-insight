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


Popup {
    id: addDomainPopup
    anchors.centerIn: parent
    modal: true
    width: 340
    padding: Constants.pageMargin
    onOpened: {
        domainIdTextField.text = ""
        domainIdTextField.lastValidText = ""
        domainIdTextField.forceActiveFocus()
    }

    background: Rectangle {
        color: Constants.cardBackgroundColor(rootWindow.isDarkMode)
        radius: Constants.cardRadius
        border.width: 1
        border.color: Constants.designBorderColor(rootWindow.isDarkMode)
    }

    function isEditableDomainList(text) {
        var values = text.split(",")
        for (var i = 0; i < values.length; ++i) {
            var value = values[i].trim()
            if (value !== "" && (!/^\d+$/.test(value)
                                 || Number(value) > 232))
                return false
        }
        return true
    }

    function domainIds() {
        var values = domainIdTextField.text.split(",")
        var result = []

        for (var i = 0; i < values.length; ++i) {
            var value = values[i].trim()
            if (!/^\d+$/.test(value))
                return []

            var domainId = Number(value)
            if (domainId < 0 || domainId > 232)
                return []

            if (result.indexOf(domainId) === -1)
                result.push(domainId)
        }

        return result
    }

    function addDomains() {
        var ids = domainIds()
        if (ids.length === 0)
            return

        for (var i = 0; i < ids.length; ++i)
            treeModel.addDomainRequest(ids[i])

        close()
    }

    contentItem: ColumnLayout {
        spacing: 8

        Label {
            text: qsTrId("domain.add")
            font.bold: true
            font.pixelSize: Constants.sectionTitleFontSize
            color: Constants.secondaryTextColor(rootWindow.isDarkMode)
            Layout.fillWidth: true
        }

        TextField {
            id: domainIdTextField
            property string lastValidText: ""

            text: ""
            placeholderText: "0, 1, 2"
            focus: true
            selectByMouse: true
            Layout.fillWidth: true
            onTextEdited: {
                if (addDomainPopup.isEditableDomainList(text)) {
                    lastValidText = text
                } else {
                    text = lastValidText
                    cursorPosition = text.length
                }
            }
            onAccepted: addDomainPopup.addDomains()
        }

        Label {
            text: qsTrId("domain.allowed.range")
            color: Constants.mutedForegroundColor(rootWindow.isDarkMode)
            font.pixelSize: Constants.captionFontSize
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Item {
                Layout.fillWidth: true
            }
            Button {
                id: addButton
                text: qsTrId("general.add")
                highlighted: true
                enabled: addDomainPopup.domainIds().length > 0
                onClicked: addDomainPopup.addDomains()
            }
            Button {
                text: qsTrId("general.cancel")
                onClicked: addDomainPopup.close()
            }
        }
    }
}
