import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"

// An independent mapped surface keeps the Wayland inhibitor alive when bars
// auto-hide or are unloaded. It occupies no workspace space and takes no input.
PanelWindow {
    id: root
    screen: Quickshell.screens.length ? Quickshell.screens[0] : null
    visible: QuickModesService.keepAwake && Quickshell.screens.length > 0
    implicitWidth: 1
    implicitHeight: 1
    color: "#01000000"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rusticq-keep-awake"
    mask: Region {}
    IdleInhibitor { window: root; enabled: QuickModesService.keepAwake }
}
