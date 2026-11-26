import QtQuick
import "../../config"
import "../../components/settings" as Suite
Suite.SettingsGroup {
    id:section
    property var appearance:null
    readonly property var controlTheme:appearance || SettingsMaterial.forItem(parent)
    property alias heading:section.title
    design:controlTheme
}
