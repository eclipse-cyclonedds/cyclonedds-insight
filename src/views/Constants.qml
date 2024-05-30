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

pragma Singleton

import QtCore
import QtQuick

Item {
    // Light mode
    property color lightPressedColor: "lightgrey"
    property color lightBorderColor: "lightgray"
    property color lightCardBackgroundColor: "#f6f6f6"
    property color lightHeaderBackground: "#e5e5e5"
    property color lightOverviewBackground: "#f3f3f3"
    property color lightMainContentBackground: "lightgray"
    property color lightSelectionBackground: "black"
    property color lightMainContent: "white"

    // Dark mode
    property color darkPressedColor: "#262626"
    property color darkBorderColor: "black"
    property color darkCardBackgroundColor: "#323232"
    property color darkHeaderBackground: "#323233"
    property color darkOverviewBackground: "#252526"
    property color darkMainContentBackground: "#1e1e1e"
    property color darkSelectionBackground: "white"
    property color darkMainContent: "#1e1e1e"

    // Independent
    property color warningColor: "#f4b83f"
}
