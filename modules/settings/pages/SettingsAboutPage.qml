import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: 14
    SettingsSection {
        heading: "RusticQ · Alpha 4 RC2"
        description: "Arch Linux desktop shell · Quickshell 0.3.1"
        symbol: "\ue8b8"

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                radius: 22
                color: Qt.alpha(Theme.accent, 0.10)
                border.width: 1
                border.color: Theme.borderaccent
                Image {
                    anchors.centerIn: parent
                    width: 58
                    height: 58
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    source: "../../../assets/rusticq-about-icon.png"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Image {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    fillMode: Image.PreserveAspectFit
                    source: "../../../assets/rusticq-about-lockup.png"
                    smooth: true
                    mipmap: true
                }
                Text {
                    text: "RusticQ branding kit is now wired into the shell: SVG app icon for UI surfaces and PNG artwork inside About."
                    wrapMode: Text.WordWrap
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
                Text {
                    text: "Launcher search stays on the magnifying-glass icon, while the separate RusticQ brand icon can be enabled or disabled from settings."
                    wrapMode: Text.WordWrap
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: 10
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
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
