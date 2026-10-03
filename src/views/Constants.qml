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
    property color lightHeaderBackground: "#ebebeb"
    property color lightOverviewBackground: "#f3f3f3"
    property color lightMainContentBackground: "lightgray"
    property color lightSelectionBackground: "black"
    property color lightMainContent: "white"
    property color lightSeparator: "#cccccc"
    property color lightDesignBorder: "#dddddd"
    property color lightSecondaryText: "#4f4f4f"
    property color lightMutedForeground: "#505050"

    // Dark mode
    property color darkPressedColor: "#262626"
    property color darkBorderColor: "black"
    property color darkCardBackgroundColor: "#323232"
    property color darkHeaderBackground: "#323233"
    property color darkOverviewBackground: "#252526"
    property color darkMainContentBackground: "#1e1e1e"
    property color darkSelectionBackground: "white"
    property color darkMainContent: "black"
    property color darkSeparator: "#555555"
    property color darkDesignBorder: "#464646"
    property color darkSecondaryText: "#c2c2c2"
    property color darkMutedForeground: "#d0d0d0"

    property color lightSplitHandle: "#d0d0d0"
    property color darkSplitHandle: "#404040"

    // Brand and semantic colors
    property color accentColor: "#274ff6"
    property color successColor: "#36a269"
    property color errorColor: "#d04a4a"
    property color warningColor: "#f4b83f"

    // Typography
    property int pageTitleFontSize: 20
    property int sectionTitleFontSize: 13
    property int bodyFontSize: 11
    property int captionFontSize: 10

    // Shape and spacing
    property int cardRadius: 8
    property int controlRadius: 6
    property int badgeRadius: 7
    property int pageMargin: 16

    // Theme-aware colors
    function mainContentColor(darkMode) {
        return darkMode ? darkMainContent : lightMainContent
    }

    function mainContentBackgroundColor(darkMode) {
        return darkMode
            ? darkMainContentBackground
            : lightMainContentBackground
    }

    function cardBackgroundColor(darkMode) {
        return darkMode
            ? darkCardBackgroundColor
            : lightCardBackgroundColor
    }

    function headerBackgroundColor(darkMode) {
        return darkMode ? darkHeaderBackground : lightHeaderBackground
    }

    function overviewBackgroundColor(darkMode) {
        return darkMode ? darkOverviewBackground : lightOverviewBackground
    }

    function borderColor(darkMode) {
        return darkMode ? darkBorderColor : lightBorderColor
    }

    function designBorderColor(darkMode) {
        return darkMode ? darkDesignBorder : lightDesignBorder
    }

    function secondaryTextColor(darkMode) {
        return darkMode ? darkSecondaryText : lightSecondaryText
    }

    function mutedForegroundColor(darkMode) {
        return darkMode ? darkMutedForeground : lightMutedForeground
    }

    function splitHandleColor(darkMode) {
        return darkMode ? darkSplitHandle : lightSplitHandle
    }

    function separatorColor(darkMode) {
        return darkMode ? darkSeparator : lightSeparator
    }

    function selectionBackgroundColor(darkMode) {
        return darkMode
            ? darkSelectionBackground
            : lightSelectionBackground
    }
}
