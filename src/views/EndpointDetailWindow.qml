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
import "qrc:/src/views/selection_details"


SecondaryWindow {
    id: detailWindow

    property alias endpointText: details.endpointText
    property alias structured: details.structured
    property alias isWriter: details.isWriter
    property alias endpointKey: details.endpointKey
    property alias participantKey: details.participantKey
    property alias instanceHandle: details.instanceHandle
    property alias topicName: details.topicName
    property alias topicType: details.topicType
    property alias typeId: details.typeId
    property alias hostname: details.hostname
    property alias processId: details.processId
    property alias processName: details.processName
    property alias addresses: details.addresses
    property alias qos: details.qos
    property alias hasQosMismatch: details.hasQosMismatch
    property alias qosMismatchText: details.qosMismatchText

    visible: false
    width: 680
    minimumWidth: mobileWindow ? 0 : 500
    height: 520
    minimumHeight: mobileWindow ? 0 : 380
    flags: mobileWindow ? Qt.Window : (Qt.Dialog | Qt.WindowStaysOnTopHint | Qt.WindowTitleHint)
           | Qt.WindowCloseButtonHint
    color: Constants.mainContentColor(rootWindow.isDarkMode)

    EndpointDetailsView {
        id: details
        anchors.fill: parent
    }
}
