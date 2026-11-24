import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"

// Centered app search on the monitor that opened it; no bar anchor dependency.
PanelWindow {
    id: overlay
    readonly property bool presented: motion.presented
    visible: presented
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: Store.launcherVisible
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"

    SurfaceMotion { id: motion; shown: Store.launcherVisible; target: launcherSurface; closedScale: 0.97 }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.background, 0.58)
        opacity: motion.progress
        MouseArea {
            anchors.fill: parent
            onClicked: Store.launcherVisible = false
        }
    }
    // One visual surface only: MiniLauncher owns the sole frame, not a nested card.
    MiniLauncher {
        id: launcherSurface
        anchors.centerIn: parent
        anchors.verticalCenterOffset: motion.offsetY
        width: Math.min(SettingsStore.launcherWidth, Math.max(320, parent.width - 48))
        height: SettingsStore.launcherLayoutMode === "clean-hover" && !launcherSurface.showResults
            ? 124 : Math.min(SettingsStore.launcherHeight, Math.max(340, parent.height - 80))
        onLaunched: Store.launcherVisible = false
    }
}
