import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: 14
    SettingsSection {
        heading: "RusticQ · Alpha 4 RC1"
        description: "Arch Linux desktop shell · Quickshell 0.3.1"
        symbol: "\ue8b8"
        Text {
            Layout.fillWidth: true
            text: "Settings now includes OS information, hardware, pacman packages, storage diagnostics and an opt-in Arch Updater. Gruvbox and Follow Aether remain available."
            wrapMode: Text.WordWrap; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 12
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
        Text {
            Layout.fillWidth: true
            text: "Settings: user-settings.json\nTheme: config/Theme.qml\nMonitor: Hyprland / nwg-displays\nAI: OpenAI / Anthropic / Gemini using Linux Secret Service"
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 11; lineHeight: 1.6
        }
    }
}
