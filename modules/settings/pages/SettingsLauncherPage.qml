import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    width: parent ? parent.width : 700
    spacing: 14
    SettingsSection {
        heading: "App Launcher · size and layout"
        description: "Two layouts with the same single surface. Size and icon settings stay independent of the chosen mode."
        symbol: "\ue8b6"
        Text {
            text: "Launcher layout mode"
            color: Theme.foreground
            font.family: Fonts.poppinsSB.name
            font.pixelSize: 13
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 9
            Repeater {
                model: [
                    {key:"compact", label:"Compact", description:"App details and results visible immediately", icon:"\ue5d1"},
                    {key:"clean-hover", label:"Clean Compact Hover", description:"Simple header and search; results on hover or typing", icon:"\ue8f4"}
                ]
                delegate: Rectangle {
                    id: modeCard
                    required property var modelData
                    readonly property bool selected: SettingsStore.launcherLayoutMode === modelData.key
                    Layout.fillWidth: true
                    Layout.preferredHeight: 108
                    radius: 12
                    color: selected ? Qt.alpha(Theme.accent, .12) : Theme.background
                    border.width: selected ? 1 : 0
                    border.color: Theme.accent
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            Icon { icon: modeCard.modelData.icon; font.pixelSize: 18; color: Theme.accent }
                            Text { text: modeCard.modelData.label; Layout.fillWidth: true; font.family: Fonts.poppinsSB.name; color: Theme.foreground; font.pixelSize: 12 }
                            Icon { visible: modeCard.selected; icon: "\ue5ca"; font.pixelSize: 17; color: Theme.accent }
                        }
                        Text { Layout.fillWidth: true; text: modeCard.modelData.description; wrapMode: Text.WordWrap; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { SettingsStore.launcherLayoutMode = modeCard.modelData.key; SettingsStore.save(); }
                    }
                }
            }
        }
        Repeater {
            model: [
                { key: "launcherWidth", title: "Window width", minimum: 440, maximum: 1000, suffix: "px", desc: "Horizontal area for search and results" },
                { key: "launcherHeight", title: "Window height", minimum: 360, maximum: 850, suffix: "px", desc: "Maximum window height before clamping to monitor" },
                { key: "launcherIconSize", title: "App icon size", minimum: 20, maximum: 64, suffix: "px", desc: "Real desktop-entry icons in results and favorites" },
                { key: "launcherRowHeight", title: "Result row height", minimum: 50, maximum: 92, suffix: "px", desc: "Vertical space for each app result" },
                { key: "launcherFavoriteColumns", title: "Favorites per row", minimum: 2, maximum: 5, suffix: "", desc: "Pinned and frequently used app columns" }
            ]
            delegate: Rectangle {
                id: setting
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 91
                radius: 12
                color: Theme.background
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: setting.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12; Layout.fillWidth: true }
                        Text { text: SettingsStore[setting.modelData.key] + " " + setting.modelData.suffix; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                    }
                    SettingRangeSlider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        minimum: setting.modelData.minimum
                        maximum: setting.modelData.maximum
                        value: SettingsStore[setting.modelData.key]
                        onPreview: next => SettingsStore.updateLauncherSize(setting.modelData.key, next, false)
                        onCommit: next => SettingsStore.updateLauncherSize(setting.modelData.key, next, true)
                    }
                    Text { text: setting.modelData.desc; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10
            color: Theme.background
            RowLayout { anchors.centerIn: parent; spacing: 8
                Icon { icon: "\ue863"; color: Theme.accent; font.pixelSize: 17 }
                Text { text: "Reset launcher dimensions"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetLauncherSize() }
        }
    }
    SettingsSection {
        heading: "RusticQ launcher branding"
        description: "The launcher search trigger stays a magnifying-glass icon. Toggle the separate RusticQ brand icon independently."
        symbol: "\ue8b6"
        SettingsToggle {
            modelData: ({
                label: "Show RusticQ icon",
                desc: "Displays the separate RusticQ brand icon in the bar and launcher header.",
                key: "showRusticQIcon",
                icon: "\ue8b8"
            })
        }
    }

    SettingsSection {
        heading: "Responsive behavior"
        description: "The overlay remains centered on the selected screen. Requested dimensions are clamped on smaller monitors; aspect ratio is not forced."
        symbol: "\ue30b"
        Text {
            Layout.fillWidth: true
            text: "The launcher keeps original app icons and search ranking. Changing icon size does not change the installed desktop entries."
            wrapMode: Text.WordWrap
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: 11
        }
    }
}
