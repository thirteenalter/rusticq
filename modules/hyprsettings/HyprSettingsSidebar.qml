import QtQuick
import Quickshell
import "../../services"
import "../../components/settings" as Suite
Suite.SettingsSidebar {
    required property var palette
    design:palette
    applicationTitle:"RusticQ Hyprland"
    applicationIcon:Quickshell.shellPath("assets/rusticq-hypr-settings.svg")
    version:HyprlandConfigService.state.info.version || "Configuration Studio"
    categories:HyprlandConfigService.state.categories || []
}
