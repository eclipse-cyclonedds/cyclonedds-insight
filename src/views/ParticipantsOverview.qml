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
import "qrc:/src/views/icons"
import "qrc:/src/views/selection_details"


TreeView {
    id: treeView
    clip: true
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.horizontal: ScrollBar {
        policy: ScrollBar.AlwaysOff
    }
    ScrollBar.vertical: ScrollBar {}
    selectionModel: ItemSelectionModel {
        id: treeSelectionParticipant
        onCurrentIndexChanged: {
            console.log("Selection changed to:", currentIndex);
            var domainId = participantModel.getDomain(currentIndex);
            var name = participantModel.getName(currentIndex);
            if (participantModel.getIsRowDomain(currentIndex)) {
                showDomainView(domainId)
            } else if (participantModel.getIsHost(currentIndex)) {
                showHostView(domainId, participantModel.getNodeSummary(currentIndex))
            } else if (participantModel.getIsProcess(currentIndex)) {
                showProcessView(domainId, participantModel.getNodeSummary(currentIndex))
            } else if (participantModel.getIsParticipant(currentIndex)) {
                name.slice(13)
                var vendorName = participantModel.getVendorName(currentIndex);
                showParticipantView(domainId, name, vendorName)
            } else if (participantModel.getIsTopic(currentIndex)) {
                showTopicEndpointView(domainId, name)
            } else if (participantModel.getIsEndpoint(currentIndex)) {
                showEndpointView(domainId, name, participantModel.getEndpointTopicName(currentIndex), participantModel.getIsWriter(currentIndex))
            } else {
                console.log("Nothing found, clear view.")
                clearView()
            }
        }
    }
    model: participantModel

    delegate: Item {
        implicitWidth: domainSplit.width
        implicitHeight: label.implicitHeight * 1.5

        readonly property real indentation: 20
        readonly property real padding: 5

        // Assigned to by TreeView:
        required property TreeView treeView
        required property bool isTreeNode
        required property bool expanded
        required property int hasChildren
        required property int depth
        required property int row
        required property int column
        required property bool current

        Rectangle {
            id: background
            height: parent.height
            width: parent.width - 10
            visible: row === treeView.currentRow
            color: Constants.selectionBackgroundColor(rootWindow.isDarkMode)
            opacity: 0.3
            radius: 5
        }

        ChevronIcon {
            id: indicator
            width: 14
            height: 14
            x: padding + (depth * indentation)
            anchors.verticalCenter: parent.verticalCenter
            visible: isTreeNode && hasChildren
            iconColor: Constants.mutedForegroundColor(rootWindow.isDarkMode)
            direction: expanded ? "down" : "right"

            TapHandler {
                onSingleTapped: {
                    let index = treeView.index(row, column)
                    treeView.selectionModel.setCurrentIndex(index, ItemSelectionModel.NoUpdate)
                    treeView.toggleExpanded(row)
                }
            }
        }
        DetailBadge {
            id: entityIcon
            x: padding + (isTreeNode ? (depth + 1) * indentation : 0)
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            color: "transparent"
            iconColor: label.color
            kind: model.is_domain ? "domain"
                  : model.is_host ? "host"
                  : model.is_process ? "process"
                  : model.is_participant ? "participant"
                  : model.is_topic ? "topic" : "endpoint"
        }

        Label {
            id: label
            x: entityIcon.x + entityIcon.width + 5
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - padding - x - 10)
            clip: true
            text: model.is_domain
                  ? qsTrId("entity.domain.value").arg(model.display)
                  : model.is_reader
                    ? qsTrId("entity.reader.label.value").arg(model.display)
                    : model.is_writer
                      ? qsTrId("entity.writer.label.value").arg(model.display)
                      : model.display
        }
    }

    function getCurrentIndex() {
        return treeSelectionParticipant.currentIndex
    }
}
