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


TreeView {
    id: treeView
    visible: viewSelector.currentIndex === 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.leftMargin: 10
    clip: true
    ScrollBar.vertical: ScrollBar {}
    selectionModel: ItemSelectionModel {
        id: treeSelection
        onCurrentIndexChanged: {
            console.log("Selection changed to:", currentIndex);
            if (treeModelProxy.getIsRowDomain(currentIndex)) {
                showDomainView(treeModelProxy.getDomain(currentIndex))
            } else if (treeModelProxy.getIsRowTopic(currentIndex)) {
                showTopicEndpointView(treeModelProxy.getDomain(currentIndex), treeModelProxy.getName(currentIndex))
            } else {
                console.log("Nothing found, clear view.")
                clearView()
            }
        }
    }
    model: treeModelProxy

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

        // Rotate indicator when expanded by the user
        // (requires TreeView to have a selectionModel)
        property Animation indicatorAnimation: NumberAnimation {
            target: indicator
            property: "rotation"
            from: expanded ? 0 : 90
            to: expanded ? 90 : 0
            duration: 100
            easing.type: Easing.OutQuart
        }
        TableView.onPooled: indicatorAnimation.complete()
        TableView.onReused: if (current) indicatorAnimation.start()
        onExpandedChanged: {
            indicator.rotation = expanded ? 90 : 0
        }

        Rectangle {
            id: background
            anchors.fill: parent
            visible: row === treeView.currentRow
            color: rootWindow.isDarkMode ? Constants.darkSelectionBackground : Constants.lightSelectionBackground
            opacity: 0.3
        }

        Label {
            id: indicator
            x: padding + (depth * indentation)
            anchors.verticalCenter: parent.verticalCenter
            visible: isTreeNode && hasChildren
            text: "▶"

            TapHandler {
                onSingleTapped: {
                    let index = treeView.index(row, column)
                    treeView.selectionModel.setCurrentIndex(index, ItemSelectionModel.NoUpdate)
                    treeView.toggleExpanded(row)
                }
            }
        }
        Label {
            id: label
            x: padding + (isTreeNode ? (depth + 1) * indentation : 0)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - padding - x - 10
            clip: true
            text: model.is_domain ? "Domain " + model.display : model.display 
        }

        WarningTriangle {
            id: warning_triangle
            visible: model.has_qos_mismatch
            width: 15
            height: 15
            anchors.verticalCenter: label.verticalCenter
            anchors.right: model.is_domain ? label.right : label.left
            anchors.margins: 5
            enableTooltip: true
            tooltipText: "Qos mismatch detected."
        }
    }

    function getCurrentIndex() {
        return treeSelection.currentIndex
    }
}

