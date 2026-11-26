import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    width: parent ? parent.width : 680
    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || Quickshell.env("XDG_CURRENT_DESKTOP").toLowerCase().indexOf("hyprland") >= 0
    spacing: root.settingsTheme.sectionGap
    Loader {
        Layout.fillWidth: true
        active: !root.hyprland
        visible: active
        sourceComponent: LegacyCompositorPage {}
    }
    SettingsSection {
        visible: root.hyprland
        heading: "RusticQ Hyprland Settings"
        description: "Configure Hyprland in its independent configuration studio. RusticQ Settings can stay open alongside it."
        symbol: "\ue8b8"
        ActionButton { label: "Open Hyprland Settings"; onClicked: Store.openHyprSettings("overview", Store.settingsScreen) }
    }
}
