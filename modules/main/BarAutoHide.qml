import QtQuick
import Quickshell
import Quickshell.Wayland

// Each monitor owns its reveal state. The invisible edge never reserves space.
Scope {
    id: root
    property bool enabled: false
    property bool hovered: false
    property bool heldOpen: false
    property bool revealed: false
    property string position: "top"
    property var screen: null
    readonly property bool shown: !enabled || revealed || heldOpen
    readonly property bool vertical: position === "left" || position === "right"
    readonly property var edgeWindow: revealEdge
    onEnabledChanged: revealed = false
    onPositionChanged: revealed = false
    onHoveredChanged: if (hovered) revealed = true
    onHeldOpenChanged: if (heldOpen) revealed = true

    Timer {
        interval: 450
        running: root.enabled && root.revealed && !root.hovered && !root.heldOpen
        onTriggered: root.revealed = false
    }
    PanelWindow {
        id: revealEdge
        objectName: "barRevealEdge"
        screen: root.screen
        visible: root.enabled && !root.shown
        color: "transparent"
        implicitWidth: root.vertical ? 2 : 0
        implicitHeight: root.vertical ? 0 : 2
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        anchors {
            top: root.position !== "bottom"
            bottom: root.position !== "top"
            left: root.position !== "right"
            right: root.position !== "left"
        }
        HoverHandler { onHoveredChanged: if (hovered) root.revealed = true }
    }
}
