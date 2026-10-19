import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"

// Tiny recoverability affordance on every monitor while the bar is hidden.
// Not exclusive and does not alter workspace geometry or switch monitors.
PanelWindow {
    id: handle
    visible: !SettingsStore.barVisible
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
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.background
        border.width: 1
        border.color: Theme.borderaccent
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
