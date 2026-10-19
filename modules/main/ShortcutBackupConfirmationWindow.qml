import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

FloatingWindow {
    id: root
    screen: Store.shortcutConfirmScreen
    visible: Store.shortcutConfirmVisible
    title: "RusticQ · Shortcut Backup Confirmation"
    implicitWidth: 550
    implicitHeight: 418
    minimumSize: Qt.size(485, 390)
    color: Theme.background
    property bool acceptedRecovery: false
    onVisibleChanged: {
        if (visible) { acceptedRecovery = false; arrangeTimer.restart(); Qt.callLater(function() { cancelButton.forceActiveFocus(); }); }
    }
    Keys.onEscapePressed: Store.cancelShortcutConfirmation()
    Timer { id: arrangeTimer; interval: 280; repeat: false
        onTriggered: if (root.visible && !arrangeProcess.running) arrangeProcess.running = true }
    Process { id: arrangeProcess
        command: ["python3", Quickshell.shellPath("scripts/rustiq-shortcut-confirmation-float.py")] }
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: Theme.sectionRadius
        border.width: 1
        border.color: Theme.borderaccent
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 13
            RowLayout { Layout.fillWidth: true; spacing: 12
                Rectangle { Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 12
                    color: Qt.alpha(Theme.accent, .15)
                    Icon { anchors.centerIn: parent; icon: "\ue8b8"; color: Theme.accent; font.pixelSize: Fonts.scale(23) } }
                ColumnLayout { Layout.fillWidth: true; spacing: 2
                    Text { text: "Back up before changing?"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(16) }
                    Text { text: "Omarchy defaults + your Hyprland / dotfiles"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 49; radius: 10; color: Theme.surface
                ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 1
                    Text { text: Store.shortcutConfirmTitle; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11); elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: Store.shortcutConfirmTarget; color: Theme.accent; font.pixelSize: Fonts.scale(10); elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "Before touching bindings.lua, RusticQ will snapshot ALL /usr/share/omarchy/default (once), then save ~/.config/hypr and related dotfiles (every change), and verify SHA-256 checksums. If backup fails, NO shortcut changes are applied."
                color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "Saved privately in ~/.local/state/rusticq/integration/backup/. Existing backups are never overwritten."
                color: Theme.muted; font.pixelSize: Fonts.scale(10) }
            RowLayout { visible: Store.shortcutConfirmRecovery; Layout.fillWidth: true; spacing: 10
                Rectangle { Layout.preferredWidth: 29; Layout.preferredHeight: 29; radius: 8
                    color: root.acceptedRecovery ? Qt.alpha(Theme.accent,.15) : Theme.surface
                    border.width: 1; border.color: root.acceptedRecovery ? Theme.accent : Theme.warning
                    Text { anchors.centerIn: parent; text: root.acceptedRecovery ? "✓" : "!"; color: root.acceptedRecovery ? Theme.accent : Theme.warning; font.pixelSize: 15 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.acceptedRecovery = !root.acceptedRecovery }
                }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "I understand: SUPER + ESCAPE/BACKSPACE may replace Omarchy's emergency recovery shortcut."
                    color: Theme.warning; font.pixelSize: Fonts.scale(10) }
            }
            Item { Layout.fillHeight: true }
            RowLayout { Layout.fillWidth: true; spacing: 9
                Rectangle { id: cancelButton; Layout.fillWidth: true; Layout.preferredHeight: 41; radius: 10; color: Theme.surface
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Store.cancelShortcutConfirmation() } }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 41; radius: 10
                    readonly property bool ready: !Store.shortcutConfirmRecovery || root.acceptedRecovery
                    color: ready ? Theme.accent : Theme.borderaccent
                    opacity: ready ? 1 : .55
                    Text { anchors.centerIn: parent; text: "Back up & continue"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; enabled: parent.ready; cursorShape: Qt.PointingHandCursor; onClicked: Store.approveShortcutConfirmation() }
                }
            }
        }
    }
}
