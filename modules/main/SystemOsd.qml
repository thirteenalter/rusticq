import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"

// Transient, noninteractive, nonexclusive Wayland popup on the focused screen.
// One visible OSD per shell, even on multi-monitor layouts.
PanelWindow {
    WlrLayershell.namespace: "rusticq-osd"
    id: root
    property bool requested: false
    function syncRequested() {
        requested = SettingsStore.osdEnabled && Store.osdVisible && root.screen !== null && Store.osdScreen !== null
            && Store.osdScreen.name === root.screen.name;
    }
    // Native window mapping can update screen synchronously. Read it after
    // that update rather than from a visibility binding that remaps the window.
    Component.onCompleted: Qt.callLater(syncRequested)
    onScreenChanged: Qt.callLater(syncRequested)
    Connections {
        target: Store
        function onOsdVisibleChanged() { Qt.callLater(root.syncRequested); }
        function onOsdScreenChanged() { Qt.callLater(root.syncRequested); }
    }
    Connections {
        target: SettingsStore
        function onOsdEnabledChanged() { Qt.callLater(root.syncRequested); }
    }
    visible: motion.presented
    SurfaceMotion { id: motion; shown: root.requested; target: osdSurface; edge: "bottom" }
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { bottom: true }
    margins { bottom: 64 }
    implicitWidth: 304
    implicitHeight: 92
    readonly property bool muted: Store.osdMuted
    readonly property string kind: Store.osdKind
    readonly property string glyph: {
        if (kind === "volume") return muted ? "\ue04f" : Store.osdPercent > 60 ? "\ue050" : "\ue04d";
        if (kind === "microphone") return muted ? "\ue02b" : "\ue029";
        if (kind === "brightness") return "\ue3a6";
        if (kind === "keyboard") return "\ue312";
        if (kind === "touchpad") return muted ? "\ue8f5" : "\ue8f4";
        return "\ue000";
    }
    GlassSurface {
        Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
        surfaceRole: "popup"
        id: osdSurface
        anchors.fill: parent
        transform: Translate { x: motion.offsetX; y: motion.offsetY }
        radius: Theme.glassRadius("popup", 18)
        color: Theme.glassColor("popup", Theme.background)
        border.width: Theme.glassBorderWidth("popup", 1)
        border.color: Theme.glassBorder("popup", Theme.borderaccent)
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.panelPadding
            spacing: 13
            Rectangle {
                Layout.preferredWidth: 46; Layout.preferredHeight: 46
                radius: Theme.glassRadius("card", 14)
                color: Theme.glassColor("card", Qt.alpha(root.kind === "error" ? Theme.error : Theme.accent, 0.13))
                Icon { anchors.centerIn: parent; icon: root.glyph; color: root.kind === "error" ? Theme.error : Theme.accent; font.pixelSize: Fonts.scale(24) }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                GlassLabel {
                    Layout.fillWidth: true; text: Store.osdLabel
                    font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12)
                    color: Theme.foreground; elide: Text.ElideRight; textFormat: Text.PlainText
                }
                RowLayout {
                    Layout.fillWidth: true; visible: Store.osdHasLevel && root.kind !== "keyboard" && root.kind !== "microphone" && root.kind !== "touchpad"
                    spacing: 9
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 6
                        radius: 3; color: Theme.surface; clip: true
                        Rectangle {
                            height: parent.height
                            width: parent.width * (Store.osdMuted ? 0 : Store.osdPercent) / 100
                            radius: 3; color: Theme.accent
                            Behavior on width { enabled: Theme.motionEnabled; NumberAnimation { duration: Theme.motionFastDuration; easing.type: Easing.OutCubic } }
                        }
                    }
                    GlassLabel { text: Store.osdMuted ? "MUTE" : Store.osdPercent + "%"; color: Theme.contentMuted; font.pixelSize: Fonts.scale(10) }
                }
                // Three hardware brightness phases (+ Off) rather than a percent
                // bar. Devices with only one or two physical steps show only
                // their truthful number of available stages.
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.kind === "keyboard"
                    spacing: 7
                    Repeater {
                        model: Store.osdStages
                        delegate: Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 7
                            radius: 3
                            color: index < Store.osdStage ? Theme.accent : Theme.surface
                        }
                    }
                    GlassLabel {
                        text: Store.osdStage === 0 ? "OFF" : Store.osdStage + "/" + Store.osdStages
                        color: Store.osdStage === 0 ? Theme.muted : Theme.accent
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: Fonts.scale(10)
                    }
                }
                GlassLabel {
                    visible: root.kind === "microphone" || root.kind === "touchpad" || root.kind === "error"
                    text: root.kind === "error" ? "Unavailable"
                        : root.kind === "microphone" ? (Store.osdMuted ? "MUTED" : "ACTIVE")
                        : (Store.osdMuted ? "DISABLED" : "ENABLED")
                    color: Store.osdMuted || root.kind === "error" ? Theme.warning : Theme.accent
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(11)
                }
            }
        }
    }
}
