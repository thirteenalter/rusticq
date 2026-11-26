import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components/settings" as Suite
ColumnLayout {
    id:root
    property string group:"home"
    property var catalog:[]
    property var systemPages:[]
    signal navigateRequested(string tab)
    readonly property var design:SettingsMaterial.forItem(root)
    readonly property var shownPages:catalog.filter(p=>["home","ui","system"].indexOf(p.key)<0)
    spacing:20
    Suite.SettingsGroup {
        design:root.design;title:"Personalize your desktop";description:"Settings save automatically. Compositor changes use the independent Hyprland studio."
        Repeater {model:root.shownPages
            delegate:Suite.SettingsRow {
                required property var modelData
                design:root.design;label:modelData.label;description:modelData.detail;symbol:modelData.symbol
                Suite.SettingsButton {design:root.design;text:"›";Accessible.name:"Open "+modelData.label;onClicked:root.navigateRequested(modelData.key)}
            }
        }
    }
}
