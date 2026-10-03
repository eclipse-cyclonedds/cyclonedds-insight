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
import org.eclipse.cyclonedds.insight

EndpointDetailsView {
    id: endpointView
    property int domainId
    property var endpointData: ({})
    structured: true

    EndpointModel {
        id: endpointModel
    }
    function refreshDetails() {
        endpointData = endpointModel.getEndpointDetails(endpointKey)
    }
    Component.onCompleted: endpointModel.setDomainId(domainId, topicName, isWriter ? 4 : 3)
    Connections {
        target: endpointModel
        function onTotalEndpointsSignal(count) { endpointView.refreshDetails() }
        function onDataChanged() { endpointView.refreshDetails() }
    }
    participantKey: endpointData.endpoint_participant_key || ""
    instanceHandle: endpointData.endpoint_participant_instance_handle || ""
    topicType: endpointData.endpoint_topic_type || ""
    typeId: endpointData.endpoint_type_id || ""
    hostname: endpointData.endpoint_hostname || ""
    processId: endpointData.endpoint_process_id || ""
    processName: endpointData.endpoint_process_name || ""
    addresses: endpointData.addresses || ""
    qos: endpointData.endpoint_qos || ""
    hasQosMismatch: endpointData.endpoint_has_qos_mismatch || false
    qosMismatchText: endpointData.endpoint_qos_mismatch_text || ""
}
