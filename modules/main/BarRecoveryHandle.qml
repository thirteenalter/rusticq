import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"

// Tiny recoverability affordance on every monitor while the bar is hidden.
// Not exclusive and does not alter workspace geometry or switch monitors.
PanelWindow {
    WlrLayershell.namespace: "rusticq-recovery"
    id: handle
    visible: !SettingsStore.barVisible && SettingsStore.showBarRecoveryHandle
    implicitWidth: 46
    implicitHeight: 34
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    anchors {
        top: SettingsStore.barPosition !== "bottom"
        bottom: SettingsStore.barPosition === "bottom"
        left: SettingsStore.barPosition === "left"
        right: SettingsStore.barPosition !== "left"
    }
    margins { top: 5; bottom: 5; left: 5; right: 5 }
    GlassSurface {
        Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
        surfaceRole: "primary"
        anchors.fill: parent
        radius: Theme.glassRadius("primary", 12)
        color: Theme.glassColor("primary", Theme.background)
        border.width: Theme.glassBorderWidth("primary", 1)
        border.color: Theme.glassBorder("primary", Theme.borderaccent)
        Icon {
            anchors.centerIn: parent
            icon: "\ue5cf"
            color: Theme.accent
            font.pixelSize: Fonts.scale(21)
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: SettingsStore.setBarVisible(true)
        }
    }
}
