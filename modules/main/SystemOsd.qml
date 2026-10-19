import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"

// Transient, noninteractive, nonexclusive Wayland popup on the focused screen.
// One visible OSD per shell, even on multi-monitor layouts.
PanelWindow {
    id: root
    visible: SettingsStore.osdEnabled && Store.osdVisible && root.screen !== null && Store.osdScreen !== null
             && Store.osdScreen.name === root.screen.name
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
    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Theme.background
        border.width: 1
        border.color: Theme.borderaccent
        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 13
            Rectangle {
                Layout.preferredWidth: 46; Layout.preferredHeight: 46
                radius: 14
                color: Qt.alpha(root.kind === "error" ? Theme.error : Theme.accent, 0.13)
                Icon { anchors.centerIn: parent; icon: root.glyph; color: root.kind === "error" ? Theme.error : Theme.accent; font.pixelSize: Fonts.scale(24) }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                Text {
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
                            Behavior on width { NumberAnimation { duration: 105 } }
                        }
                    }
                    Text { text: Store.osdMuted ? "MUTE" : Store.osdPercent + "%"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
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
                    Text {
                        text: Store.osdStage === 0 ? "OFF" : Store.osdStage + "/" + Store.osdStages
                        color: Store.osdStage === 0 ? Theme.muted : Theme.accent
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: Fonts.scale(10)
                    }
                }
                Text {
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
