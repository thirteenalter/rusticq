import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"

// Centered app search on the monitor that opened it; no bar anchor dependency.
PanelWindow {
    id: overlay
    visible: Store.launcherVisible
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.background, 0.58)
        MouseArea {
            anchors.fill: parent
            onClicked: Store.launcherVisible = false
        }
    }
    Rectangle {
        id: launcherCard
        anchors.centerIn: parent
        width: Math.min(650, Math.max(320, parent.width - 48))
        height: Math.min(590, Math.max(320, parent.height - 80))
        radius: 20
        color: Theme.background
        border.width: 1
        border.color: Theme.borderaccent
        clip: true
        MiniLauncher {
            anchors.fill: parent
            anchors.margins: 8
            onLaunched: Store.launcherVisible = false
        }
    }
}
