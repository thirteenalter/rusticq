import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: 14
    SettingsSection {
        heading: "RusticQ · Alpha 3 RC5"
        description: "Arch Linux desktop shell · Quickshell 0.3.1"
        symbol: "\ue8b8"
        Text {
            Layout.fillWidth: true
            text: "This build separates Settings into independent QML pages to prevent section height and clipping regressions. The Gruvbox and Aether palette options remain available."
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
