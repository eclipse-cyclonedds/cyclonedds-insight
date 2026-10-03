import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: secondaryWindow
    readonly property bool mobileWindow: (Qt.platform.os === "android" || Qt.platform.os === "ios")

    // Fill the available screen without hiding Android's system bars.
    // Apply on every opening, including callers that only set visible = true.
    onVisibleChanged: {
        if (mobileWindow && visible)
            showMaximized()
    }

    // An explicit in-app title bar also works without native window decorations.
    header: Rectangle {
        id: closeToolBar
        visible: secondaryWindow.mobileWindow
        readonly property real topInset: SafeArea.margins.top
        height: visible ? 56 + topInset : 0
        color: Constants.mainContentColor(rootWindow.isDarkMode)
        z: 100

        RowLayout {
            anchors.fill: parent
            anchors.topMargin: closeToolBar.topInset
            anchors.leftMargin: 12 + closeToolBar.SafeArea.margins.left
            anchors.rightMargin: 12 + closeToolBar.SafeArea.margins.right
            spacing: 12

            Label {
                text: secondaryWindow.title
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
            Button {
                objectName: "mobileCloseButton"
                text: qsTrId("general.close")
                Layout.minimumWidth: 96
                Layout.minimumHeight: 48
                Accessible.name: text
                onClicked: secondaryWindow.close()
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: secondaryWindow.palette.mid
        }
    }

    Shortcut {
        sequence: "Back"
        enabled: secondaryWindow.mobileWindow && secondaryWindow.visible
        onActivated: secondaryWindow.close()
    }
}
