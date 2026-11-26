import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../../config"
import "../../../components/settings" as Suite
ColumnLayout {
    id:root
    property string target:"shared"
    readonly property var design:SettingsMaterial.forItem(root)
    readonly property var values:SettingsMaterial.preferences(target)
    readonly property bool editingEnabled:target==="shared" || SettingsStore.settingsWindowAppearance[target].enabled
    spacing:20
    Suite.SettingsGroup {
        design:root.design;title:"Appearance";description:"Both applications share these settings unless an individual override is enabled."
        Suite.SettingsDropdown {design:root.design;Layout.fillWidth:true;model:["Apply to both settings applications","Customize RusticQ Settings","Customize Hyprland Settings"];onActivated:root.target=["shared","rusticq","hyprland"][currentIndex]}
        Suite.SettingsToggle {visible:root.target!=="shared";design:root.design;text:"Enable per-app overrides";checked:root.target!=="shared" && SettingsStore.settingsWindowAppearance[root.target].enabled;onToggled:SettingsStore.setSettingsAppearance(root.target,"enabled",checked)}
        Suite.SettingsRow {
            enabled:root.editingEnabled
            design:root.design;label:"Theme mode";description:root.values.mode==="follow"?"Follows the active RusticQ palette, including Aether and RAGE.":"Uses an independent palette for the settings windows."
            Suite.SettingsDropdown {design:root.design;model:["Follow RusticQ Theme","RAGE Glass Dark","RAGE Glass Light","Neutral Dark","Neutral Light"];currentIndex:["follow","rage-dark","rage-light","neutral-dark","neutral-light"].indexOf(root.values.mode);onActivated:SettingsStore.setSettingsAppearance(root.target,"mode",["follow","rage-dark","rage-light","neutral-dark","neutral-light"][currentIndex])}
        }
    }
    Suite.SettingsGroup {
        design:root.design;title:"Glass material";enabled:root.editingEnabled;contentSpacing:0
        Repeater {
            model:[{key:"windowOpacity",label:"Window opacity",min:0.15,max:1,step:0.01,scale:100,unit:" %"},{key:"sidebarOpacity",label:"Sidebar material strength",min:0,max:1,step:0.01,scale:100,unit:" %"},{key:"groupOpacity",label:"Group material strength",min:0.01,max:0.5,step:0.005,scale:100,unit:" %"},{key:"popoverOpacity",label:"Popover opacity",min:0.8,max:1,step:0.01,scale:100,unit:" %"},{key:"outlineOpacity",label:"Outline opacity",min:0,max:0.5,step:0.01,scale:100,unit:" %"},{key:"outlineWidth",label:"Outline thickness",min:0,max:2,step:0.5,scale:1,unit:" px"}]
            delegate:Suite.SettingsRow {
                required property var modelData
                objectName:"settings-appearance-"+modelData.key
                design:root.design;label:modelData.label
                Suite.SettingsSlider {design:root.design;accessibleName:modelData.label;from:modelData.min;to:modelData.max;stepSize:modelData.step;displayScale:modelData.scale;suffix:modelData.unit;value:root.values[modelData.key];onEdited:value=>{SettingsStore.setSettingsAppearance(root.target,modelData.key,value,false);saveDebounce.restart();}}
            }
        }
        Suite.SettingsRow {design:root.design;label:"Window outline";Suite.SettingsToggle {design:root.design;checked:root.values.outline;onToggled:SettingsStore.setSettingsAppearance(root.target,"outline",checked)}}
        Suite.SettingsLabel {design:root.design;text:root.design.capabilityText;Layout.fillWidth:true;wrapMode:Text.WordWrap}
        Suite.SettingsLabel {visible:root.design.glassEnabled && !root.design.verifiedBlur;design:root.design;text:Store.glassCompositorStatus;color:design.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap;font.pixelSize:12}
    }
    Suite.SettingsGroup {
        design:root.design;title:"Layout & controls";enabled:root.editingEnabled;contentSpacing:0
        Repeater {
            model:[{key:"radius",label:"Window rounding",min:0,max:28},{key:"sidebarWidth",label:"Sidebar width",min:220,max:280}]
            delegate:Suite.SettingsRow {
                required property var modelData
                design:root.design;label:modelData.label
                Suite.SettingsSlider {design:root.design;accessibleName:modelData.label;from:modelData.min;to:modelData.max;suffix:" px";value:root.values[modelData.key];onEdited:value=>{SettingsStore.setSettingsAppearance(root.target,modelData.key,value,false);saveDebounce.restart();}}
            }
        }
        Suite.SettingsRow {design:root.design;label:"Accent color";description:root.values.mode==="follow"?"Uses the accent from RusticQ in Follow mode.":"Accent for the independent settings palette.";Suite.SettingsColorPicker {enabled:root.values.mode!=="follow";design:root.design;value:root.values.mode==="follow"?Theme.accent:root.values.accent;onEdited:value=>SettingsStore.setSettingsAppearance(root.target,"accent",value)}}
        Suite.SettingsRow {design:root.design;label:"Interface density";Suite.SettingsDropdown {design:root.design;model:["Comfortable","Compact"];currentIndex:root.values.density==="compact"?1:0;onActivated:SettingsStore.setSettingsAppearance(root.target,"density",currentIndex?"compact":"comfortable")}}
        Suite.SettingsRow {design:root.design;label:"Category icons";Suite.SettingsDropdown {design:root.design;model:["Colorful","Neutral"];currentIndex:root.values.iconStyle==="neutral"?1:0;onActivated:SettingsStore.setSettingsAppearance(root.target,"iconStyle",currentIndex?"neutral":"color")}}
        Suite.SettingsRow {design:root.design;label:"Animations";Suite.SettingsToggle {design:root.design;checked:root.values.animations;onToggled:SettingsStore.setSettingsAppearance(root.target,"animations",checked)}}
        Suite.SettingsButton {design:root.design;text:"Reset settings suite appearance";onClicked:SettingsStore.resetSettingsAppearance()}
    }
    SettingsSurfaceMaterials {Layout.fillWidth:true}
    Timer {id:saveDebounce;interval:300;onTriggered:SettingsStore.save()}
}
