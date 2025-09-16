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
import QtCharts
import QtQuick.Controls
import org.eclipse.cyclonedds.insight
import "qrc:/src/views"


Item {
    id: root
    property var chart
    property var axisX
    property double time: 0
    property string text: ""

    // normalize everything to ms
    function toMs(v) {
        if (v === undefined || v === null) return NaN;
        if (typeof v === "number") return v < 1e12 ? v * 1000 : v; // sec → ms
        if (v instanceof Date) return v.getTime();
        return Date.parse(v);
    }

    property real xPos: {
        if (!chart || !axisX) return 0;
        var minMs = toMs(axisX.min);
        var maxMs = toMs(axisX.max);
        var tMs   = toMs(time);
        if (!isFinite(minMs) || !isFinite(maxMs) || !isFinite(tMs)) return 0;
        var ratio = (tMs - minMs) / (maxMs - minMs);
        return chart.plotArea.x + ratio * chart.plotArea.width;
    }

    Rectangle {
        width: 2
        color: "red"
        x: root.xPos
        y: chart.plotArea.y
        height: chart.plotArea.height
    }

    Label {
        id: label
        text: root.text
        color: "red"
        font.pixelSize: 12
        x: root.xPos - width / 2
        y: chart.plotArea.y - height - 4
    }
}
