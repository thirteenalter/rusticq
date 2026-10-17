import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: 14
    SettingsSection {
        heading: "Current layout · " + SettingsStore.barMode
        description: "Bar icon switches below are saved only for this layout mode. Switch layouts in Settings → Bar to edit another profile. Notification delivery and quick-mode auto-hide remain global."
        symbol: "\ue429"
    }
    SettingsSection {
        heading: "Layout profile tools · " + SettingsStore.barMode
        description: "Every bar mode stores its own visible icons. Reset, copy or simplify only the active mode."
        symbol: "\ue429"
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: [{label:"Minimal", action:"minimal"}, {label:"Reset active mode",action:"reset"}]
                delegate: Rectangle {
                    id: presetButton
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 37; radius: 9; color: Theme.background
                    Text { anchors.centerIn: parent; text: presetButton.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                        if (presetButton.modelData.action === "minimal") SettingsStore.useMinimalModePreset();
                        else SettingsStore.resetModeVisibility();
                    } }
                }
            }
        }
        Text { text: "Copy this mode's icon setup from:"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
        Flow {
            Layout.fillWidth: true; spacing: 7
            Repeater {
                model: SettingsStore.spacingModes.filter(m => m !== SettingsStore.barMode)
                delegate: Rectangle {
                    id: profileSource
                    required property string modelData
                    width: sourceLabel.implicitWidth + 24; height: 31; radius: 8; color: Theme.background
                    Text { id: sourceLabel; anchors.centerIn: parent; text: profileSource.modelData === "clean-compact" ? "Clean Compact" : profileSource.modelData[0].toUpperCase() + profileSource.modelData.slice(1); color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.copyVisibilityFromMode(profileSource.modelData) }
                }
            }
        }
    }
    SettingsSection {
        heading: "Launchers & bar components"
        description: "Show or hide icons independently for the active layout mode."
        symbol: "\ue8b6"
        Repeater {
            model: [
                {label:"RusticQ brand icon",desc:"Dedicated brand icon on the bar",key:"showRusticQIcon",icon:"\ue8b8"},
                {label:"App launcher",desc:"Search installed applications",key:"showLauncher",icon:"\ue8b6"},
                {label:"Arch / AI launcher",desc:"Assistant sidebar",key:"showArch",icon:"\uf371"},
                {label:"Workspace switcher",desc:"Hyprland workspaces",key:"showWorkspaces",icon:"\ue30b"},
                {label:"Quick Control",desc:"Full quick settings panel",key:"showQuickControl",icon:"\ue69b"},
                {label:"Task View",desc:"CPU, RAM and process details",key:"showTaskView",icon:"\ue322"},
                {label:"Notification center",desc:"Toast and notification history",key:"showNotifications",icon:"\ue7f4"}
            ]
            delegate: SettingsToggle { perBarMode: modelData.key !== "showNotifications" && modelData.key !== "quickModesAutoHide" }
        }
    }
    SettingsSection {
        heading: "Status indicators"
        description: "Visible status icons are saved separately in each bar layout."
        symbol: "\ue429"
        Repeater {
            model: [
                {label:"Weather",desc:"Conditions and temperature",key:"showWeather",icon:"\ue430"},
                {label:"Clock",desc:"Time indicator",key:"showTime",icon:"\ue8b5"},
                {label:"Calendar",desc:"Date and weekday",key:"showDate",icon:"\uebcc"},
                {label:"Wi-Fi",desc:"Wireless network",key:"showWifi",icon:"\ue63e"},
                {label:"Bluetooth",desc:"Wireless devices",key:"showBluetooth",icon:"\ue1a7"},
                {label:"Battery",desc:"Charging status",key:"showBattery",icon:"\uf304"},
                {label:"Audio",desc:"Output volume",key:"showAudio",icon:"\ue050"},
                {label:"Microphone status",desc:"Input microphone on / muted",key:"showMicrophoneStatus",icon:"\ue029"},
                {label:"Download speed",desc:"Network receive rate · live",key:"showDownloadSpeed",icon:"\ue5db"},
                {label:"Upload speed",desc:"Network transmit rate · live",key:"showUploadSpeed",icon:"\ue5d8"},
                {label:"System indicators",desc:"Master toggle for network, battery and audio",key:"showIndicators",icon:"\ue8b8"}
            ]
            delegate: SettingsToggle { perBarMode: modelData.key !== "showNotifications" && modelData.key !== "quickModesAutoHide" }
        }
    }
    SettingsSection {
        heading: "Menu bar"
        description: "Each layout remembers its own File, Edit, View, Share, Shell and Tools menus."
        symbol: "\ue5d2"
        Repeater {
            model: [
                {label:"Show menu bar",desc:"Place menus beside the launcher",key:"showMenuBar",icon:"\ue5d2"},
                {label:"File",desc:"Folders and configuration",key:"showMenuFile",icon:"\ue2c7"},
                {label:"Edit",desc:"RusticQ settings shortcuts",key:"showMenuEdit",icon:"\ue3c9"},
                {label:"View",desc:"Switch bar layouts",key:"showMenuView",icon:"\ue8f4"},
                {label:"Share",desc:"Local screenshots",key:"showMenuShare",icon:"\ue3c2"},
                {label:"Shell",desc:"Terminal and system monitoring",key:"showMenuShell",icon:"\uf371"},
                {label:"Tools",desc:"Settings and capture shortcuts",key:"showMenuTools",icon:"\ue8b8"}
            ]
            delegate: SettingsToggle { perBarMode: modelData.key !== "showNotifications" && modelData.key !== "quickModesAutoHide" }
        }
    }
    SettingsSection {
        heading: "Quick modes"
        description: "Choose Quick Modes buttons for this layout; auto-hide behaviour remains global."
        symbol: "\ue429"
        Repeater {
            model: [
                {label:"Show quick modes",desc:"Master toggle",key:"showQuickModes",icon:"\ue429"},
                {label:"Auto-hide quick modes",desc:"Reveal the shortcuts on hover",key:"quickModesAutoHide",icon:"\ue8f4"},
                {label:"Keep Awake",desc:"Prevent sleep",key:"showKeepAwake",icon:"\ue541"},
                {label:"Silent",desc:"Do Not Disturb",key:"showSilent",icon:"\ue7f6"},
                {label:"Gaming Mode",desc:"Performance power profile",key:"showGamingMode",icon:"\ue30f"},
                {label:"Night Mode",desc:"Warm screen temperature",key:"showNightMode",icon:"\ue51c"},
                {label:"Mute Microphone",desc:"Microphone mute",key:"showMicMute",icon:"\ue02b"}
            ]
            delegate: SettingsToggle { perBarMode: modelData.key !== "showNotifications" && modelData.key !== "quickModesAutoHide" }
        }
    }
}
