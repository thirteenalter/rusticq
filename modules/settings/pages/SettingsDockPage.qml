import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: 14
    SettingsSection {
        heading: "Dock behavior"
        description: "The dock appears along the lower edge and can collapse to a hover handle."
        symbol: "\ue429"
        Repeater {
            model: [
                {label:"Enable dock",desc:"Show application shortcuts",key:"showDock",icon:"\ue8b8"},
                {label:"Auto-hide dock",desc:"Reveal by hovering its bottom handle",key:"dockAutoHide",icon:"\ue8f4"},
                {label:"Show running apps",desc:"Only graphical applications with open Hyprland windows; click to focus",key:"dockRunningApps",icon:"\ue30b"}
            ]
            delegate: SettingsToggle {}
        }
    }
    SettingsSection {
        heading: "Dock shortcuts"
        description: "Pick the actions available from the dock."
        symbol: "\ue8b6"
        Repeater {
            model: [
                {label:"Files",desc:"Open home folder",key:"dockFiles",icon:"\ue2c7"},
                {label:"Browser",desc:"Open default browser",key:"dockBrowser",icon:"\ue80b"},
                {label:"Settings",desc:"Open RusticQ settings",key:"dockSettings",icon:"\ue8b8"},
                {label:"System Monitor",desc:"Open performance graphs and processes",key:"dockTaskView",icon:"\uf190"},
                {label:"AI",desc:"Cloud assistant sidebar",key:"dockAI",icon:"\ue8f4"}
            ]
            delegate: SettingsToggle {}
        }
    }
}
