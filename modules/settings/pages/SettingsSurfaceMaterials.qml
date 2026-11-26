import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components/settings" as Suite
ColumnLayout {
    id:root
    readonly property var design:SettingsMaterial.forItem(root)
    property string surface:"dock"
    readonly property var value:Object.assign({inherit:true,glass:true,background:true,outline:true,opacity:0.6,radius:16},SettingsStore.surfaceMaterialOverrides[surface] || {})
    spacing:16
    Suite.SettingsGroup {
        design:root.design;title:"Per-surface materials";description:"Changing global glass does not erase individual surface choices. Bar, Launcher and Quick Control retain their dedicated editors.";contentSpacing:0
        Suite.SettingsDropdown {design:root.design;Layout.fillWidth:true;model:["Dock","Notification Center & toasts","Widgets","Popovers","Dialogs"];onActivated:root.surface=["dock","notifications","widgets","popovers","dialogs"][currentIndex]}
        Repeater {model:[{key:"inherit",label:"Inherit global material"},{key:"glass",label:"Enable glass"},{key:"background",label:"Show background"},{key:"outline",label:"Show outline"}]
            delegate:Suite.SettingsRow {required property var modelData;design:root.design;label:modelData.label;Suite.SettingsToggle {design:root.design;checked:root.value[modelData.key];onToggled:SettingsStore.setSurfaceMaterial(root.surface,modelData.key,checked)}}
        }
        Suite.SettingsRow {design:root.design;label:"Background opacity";Suite.SettingsSlider {design:root.design;displayScale:100;suffix:" %";from:0.15;to:1;stepSize:0.01;value:root.value.opacity;onEdited:value=>SettingsStore.setSurfaceMaterial(root.surface,"opacity",value)}}
        Suite.SettingsRow {design:root.design;label:"Corner radius";Suite.SettingsSlider {design:root.design;Layout.preferredWidth:280;from:0;to:32;value:root.value.radius;suffix:" px";onEdited:value=>SettingsStore.setSurfaceMaterial(root.surface,"radius",value)}}
    }
}
