import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
                            width: parent ? parent.width : 680
                            Layout.fillWidth: true
                            spacing: 12
                            Text { text: "Live theme preview"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                radius: 12
                                color: Qt.alpha(Theme.foreground, 0.045)
                                border.color: Theme.borderaccent
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 13
                                    spacing: 10
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        radius: 10
                                        color: Theme.background
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12; anchors.rightMargin: 12
                                            Icon { icon: "\ue5ca"; font.pixelSize: 17; color: Theme.accent }
                                            Text { text: "Workspaces"; color: Theme.foreground; font.pixelSize: 11; font.family: Fonts.poppins.name }
                                            Item { Layout.fillWidth: true }
                                            Icon { icon: "\ue63e"; font.pixelSize: 18; color: Theme.accent }
                                            Text { text: "100%"; color: Theme.foreground; font.pixelSize: 11; font.family: Fonts.poppinsSB.name }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 65
                                            radius: 10
                                            color: Theme.surface
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 9
                                                Icon { icon: "\ue8b8"; font.pixelSize: 22; color: Theme.accent }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text { text: "Quick Control"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                                                    Text { text: Theme.useAether ? "Aether live colors" : "Gruvbox accents"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            Layout.preferredWidth: 61
                                            Layout.preferredHeight: 65
                                            radius: 10
                                            color: Qt.alpha(Theme.accent, 0.20)
                                            Icon { anchors.centerIn: parent; icon: "\ue40a"; font.pixelSize: 24; color: Theme.accent }
                                        }
                                    }
                                }
                            }
                            Text { text: "Color source"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Text {
                                Layout.fillWidth: true
                                text: "Choose independent Gruvbox or follow Aether's last applied wallpaper palette."
                                color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                            Repeater {
                                model: [
                                    { key: "gruvbox", title: "Independent Gruvbox", info: "Fixed Gruvbox Dark; select an accent below" },
                                    { key: "aether", title: "Follow Aether", info: "Watch ~/.config/aether/theme/colors.toml" }
                                ]
                                delegate: Rectangle {
                                    id: sourceRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    radius: 11
                                    color: SettingsStore.colorSource === modelData.key ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                                    border.width: SettingsStore.colorSource === modelData.key ? 1 : 0
                                    border.color: Theme.accent
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 12; spacing: 10
                                        Icon { icon: sourceRow.modelData.key === "aether" ? "\ue40a" : "\ue8b8"; font.pixelSize: 21; color: Theme.accent }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Text { text: sourceRow.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                                            Text { text: sourceRow.modelData.info; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                                        }
                                        Icon { visible: SettingsStore.colorSource === sourceRow.modelData.key; icon: "\ue5ca"; font.pixelSize: 17; color: Theme.accent }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { SettingsStore.colorSource = sourceRow.modelData.key; SettingsStore.save(); }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: SettingsStore.colorSource === "aether"
                                text: Theme.aetherAvailable ? "Aether palette detected · Live sync enabled" : "Aether palette not detected · Using Gruvbox fallback until Aether applies a theme"
                                color: Theme.aetherAvailable ? Theme.success : Theme.warning
                                font.family: Fonts.poppins.name; font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                            Text { text: "Gruvbox accent color"; visible: SettingsStore.colorSource === "gruvbox"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Repeater {
                                model: [
                                    {name: "orange", label: "Gruvbox Orange", hex: "#d65d0e"},
                                    {name: "green", label: "Gruvbox Green", hex: "#b8bb26"},
                                    {name: "blue", label: "Gruvbox Aqua", hex: "#83a598"},
                                    {name: "purple", label: "Gruvbox Purple", hex: "#d3869b"}
                                ]
                                delegate: Rectangle {
                                    id: accentRow
                                    visible: SettingsStore.colorSource === "gruvbox"
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: 11
                                    color: SettingsStore.accentName === accentRow.modelData.name ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                                    border.width: SettingsStore.accentName === accentRow.modelData.name ? 1 : 0
                                    border.color: Theme.accent
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 12
                                        spacing: 10
                                        Rectangle { Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 7; color: accentRow.modelData.hex }
                                        Text {
                                            Layout.fillWidth: true
                                            text: accentRow.modelData.label
                                            color: Theme.foreground
                                            font.family: Fonts.poppins.name
                                            font.pixelSize: 12
                                        }
                                        Icon {
                                            icon: "\ue5ca"
                                            font.pixelSize: 18
                                            color: Theme.accent
                                            visible: SettingsStore.accentName === accentRow.modelData.name
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { SettingsStore.accentName = accentRow.modelData.name; SettingsStore.save(); }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: SettingsStore.colorSource === "aether" ? "Aether source: " + Theme.aetherPath : "Base palette #282828 / #3c3836 / #ebdbb2 · Poppins and Material Symbols"
                                wrapMode: Text.WordWrap
                                color: Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: 10
                            }
                        }
