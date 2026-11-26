import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

FloatingWindow {
    id: root
    screen: Store.shortcutConfirmScreen
    readonly property bool presented: motion.presented
    visible: presented
    SurfaceMotion { id: motion; shown: Store.shortcutConfirmVisible; target: root.contentItem; closedScale: 0.995 }
    title: "RusticQ · Shortcut Backup Confirmation"
    implicitWidth: 550
    implicitHeight: 418
    minimumSize: Qt.size(485, 390)
    color: Theme.glassColor("window", Theme.background)
    property bool acceptedRecovery: false
    onVisibleChanged: {
        if (visible) { acceptedRecovery = false; arrangeTimer.restart(); Qt.callLater(function() { cancelButton.forceActiveFocus(); }); }
    }
    Timer { id: arrangeTimer; interval: 280; repeat: false
        onTriggered: if (root.visible && !arrangeProcess.running) arrangeProcess.running = true }
    Process { id: arrangeProcess
        command: ["python3", Quickshell.shellPath("scripts/rustiq-shortcut-confirmation-float.py"), "--parent-title", Store.shortcutConfirmWindowTitle] }
    GlassSurface {
        Keys.onEscapePressed: Store.cancelShortcutConfirmation()
        Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
        surfaceRole: "modal"
        anchors.fill: parent
        color: Theme.surfaceColor("dialogs","modal", Theme.background)
        radius: Theme.surfaceRadius("dialogs","modal", Theme.sectionRadius)
        border.width: Theme.surfaceBorderWidth("dialogs","modal", 1)
        border.color: Theme.surfaceBorder("dialogs","modal", Theme.borderaccent)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.dialogPadding
            spacing: 13
            RowLayout { Layout.fillWidth: true; spacing: 12
                Rectangle { Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: Theme.glassRadius("card", 12)
                    color: Theme.glassColor("card", Qt.alpha(Theme.accent, .15))
                    Icon { anchors.centerIn: parent; icon: "\ue8b8"; color: Theme.accent; font.pixelSize: Fonts.scale(23) } }
                ColumnLayout { Layout.fillWidth: true; spacing: 2
                    GlassLabel { text: "Back up before changing?"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(16) }
                    GlassLabel { text: "Omarchy defaults + your Hyprland / dotfiles"; color: Theme.contentMuted; font.pixelSize: Fonts.scale(10) }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 49; radius: Theme.glassRadius("card", 10); color: Theme.glassColor("card", Theme.surface)
                ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 1
                    GlassLabel { text: Store.shortcutConfirmTitle; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11); elide: Text.ElideRight; Layout.fillWidth: true }
                    GlassLabel { text: Store.shortcutConfirmTarget; color: Theme.accent; font.pixelSize: Fonts.scale(10); elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
            GlassLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "Before touching bindings.lua, RusticQ will snapshot ALL /usr/share/omarchy/default (once), then save ~/.config/hypr and related dotfiles (every change), and verify SHA-256 checksums. If backup fails, NO shortcut changes are applied."
                color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            GlassLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "Saved privately in ~/.local/state/rusticq/integration/backup/. Existing backups are never overwritten."
                color: Theme.contentMuted; font.pixelSize: Fonts.scale(10) }
            RowLayout { visible: Store.shortcutConfirmRecovery; Layout.fillWidth: true; spacing: 10
                Rectangle { Layout.preferredWidth: 29; Layout.preferredHeight: 29; radius: Theme.glassRadius("card", 8)
                    color: Theme.glassColor("card", root.acceptedRecovery ? Qt.alpha(Theme.accent,.15) : Theme.surface)
                    border.width: Theme.glassBorderWidth("card", 1); border.color: Theme.glassBorder("card", root.acceptedRecovery ? Theme.accent : Theme.warning)
                    GlassLabel { anchors.centerIn: parent; text: root.acceptedRecovery ? "✓" : "!"; color: root.acceptedRecovery ? Theme.accent : Theme.warning; font.pixelSize: 15 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.acceptedRecovery = !root.acceptedRecovery }
                }
                GlassLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "I understand: SUPER + ESCAPE/BACKSPACE may replace Omarchy's emergency recovery shortcut."
                    color: Theme.warning; font.pixelSize: Fonts.scale(10) }
            }
            Item { Layout.fillHeight: true }
            RowLayout { Layout.fillWidth: true; spacing: 9
                Rectangle { id: cancelButton; Layout.fillWidth: true; Layout.preferredHeight: 41; radius: Theme.glassRadius("card", 10); color: Theme.glassColor("card", Theme.surface)
                    GlassLabel { anchors.centerIn: parent; text: "Cancel"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Store.cancelShortcutConfirmation() } }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 41; radius: Theme.glassRadius("card", 10)
                    readonly property bool ready: !Store.shortcutConfirmRecovery || root.acceptedRecovery
                    color: Theme.glassColor("card", ready ? Theme.accent : Theme.borderaccent)
                    opacity: ready ? 1 : .55
                    GlassLabel { anchors.centerIn: parent; text: "Back up & continue"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; enabled: parent.ready; cursorShape: Qt.PointingHandCursor; onClicked: Store.approveShortcutConfirmation() }
                }
            }
        }
    }
}
