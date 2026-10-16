import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: 14
    SettingsSection {
        heading: "Launchers & bar components"
        description: "Each icon can be shown or hidden independently."
        symbol: "\ue8b6"
        Repeater {
            model: [
                {label:"App launcher",desc:"Search installed applications",key:"showLauncher",icon:"\ue8b6"},
                {label:"Arch / AI launcher",desc:"Assistant sidebar",key:"showArch",icon:"\ueb8e"},
                {label:"Workspace switcher",desc:"Hyprland workspaces",key:"showWorkspaces",icon:"\ue30b"},
                {label:"Quick Control",desc:"Full quick settings panel",key:"showQuickControl",icon:"\ue69b"},
                {label:"Task View",desc:"CPU, RAM and process details",key:"showTaskView",icon:"\uf190"},
                {label:"Notification center",desc:"Toast and notification history",key:"showNotifications",icon:"\ue7f4"}
            ]
            delegate: SettingsToggle {}
        }
    }
    SettingsSection {
        heading: "Status indicators"
        description: "Choose which information appears on the bar."
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
                {label:"System indicators",desc:"Master toggle for network, battery and audio",key:"showIndicators",icon:"\ue8b8"}
            ]
            delegate: SettingsToggle {}
        }
    }
    SettingsSection {
        heading: "Menu bar"
        description: "Enable optional File, Edit, View, Share, Shell and Tools menus."
        symbol: "\ue5d2"
        Repeater {
            model: [
                {label:"Show menu bar",desc:"Place menus beside the launcher",key:"showMenuBar",icon:"\ue5d2"},
                {label:"File",desc:"Folders and configuration",key:"showMenuFile",icon:"\ue2c7"},
                {label:"Edit",desc:"RusticQ settings shortcuts",key:"showMenuEdit",icon:"\ue3c9"},
                {label:"View",desc:"Switch bar layouts",key:"showMenuView",icon:"\ue8f4"},
                {label:"Share",desc:"Local screenshots",key:"showMenuShare",icon:"\ue3c2"},
                {label:"Shell",desc:"Terminal and system monitoring",key:"showMenuShell",icon:"\ueb8e"},
                {label:"Tools",desc:"Settings and capture shortcuts",key:"showMenuTools",icon:"\ue8b8"}
            ]
            delegate: SettingsToggle {}
        }
    }
    SettingsSection {
        heading: "Quick modes"
        description: "Manage the bar's compact system shortcuts."
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
            delegate: SettingsToggle {}
        }
    }
}
