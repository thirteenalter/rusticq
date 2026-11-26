import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

SettingsSection {
    id: settingsPageRoot
    readonly property var settingsTheme: SettingsMaterial.forItem(settingsPageRoot)
    objectName:"quickControlSettings"
    heading:"Quick Control"
    description:"Classic keeps the original interface. Modular uses floating controls; Frameless always removes the panel background and outline."
    symbol:"\ue429"
    RowLayout {
        Layout.fillWidth:true;spacing:settingsPageRoot.settingsTheme.inlineGap
        Repeater {
            model:[{key:"classic",label:"Classic"},{key:"modular",label:"Modular"},{key:"frameless",label:"Frameless"}]
            ActionButton {required property var modelData;objectName:"quickLayout_"+modelData.key;Layout.fillWidth:true;label:modelData.label;selected:SettingsStore.quickControlLayout===modelData.key;onClicked:SettingsStore.setQuickControlSetting("quickControlLayout",modelData.key,true)}
        }
    }
    Repeater {
        model:[
            {key:"quickControlPanelBackground",label:"Show panel background",desc:"Used by Modular; Frameless keeps it transparent",icon:"\ue3b5"},
            {key:"quickControlPanelOutline",label:"Show panel outline",desc:"Used by Modular; Frameless keeps it hidden",icon:"\ue3c2"},
            {key:"quickControlComponentBackground",label:"Show component background",desc:"Independent surfaces behind actual controls",icon:"\ue1bd"},
            {key:"quickControlComponentOutline",label:"Show component outline",desc:"Optional control edges",icon:"\ue3c2"},
            {key:"quickControlComponentGlass",label:"Component glassmorphism",desc:"Use RAGE materials when enabled; transparent gaps stay clear",icon:"\ue40a"},
            {key:"quickControlAccentTint",label:"Component accent tint",desc:"Tint active controls with the current palette accent",icon:"\ue40a"},
            {key:"quickControlCompact",label:"Compact density",desc:"Smaller control and module heights",icon:"\ue5d2"},
            {key:"quickControlAnimations",label:"Animations",desc:"Follows global motion preference",icon:"\ue9d9"}
        ]
        SettingsToggle {objectName:modelData.key;enabled:SettingsStore.quickControlLayout!=="classic" && (!(modelData.key==="quickControlPanelBackground" || modelData.key==="quickControlPanelOutline") || SettingsStore.quickControlLayout!=="frameless")}
    }
    Repeater {
        model:[
            {key:"quickControlSurfaceOpacity",label:"Component surface opacity",percent:true},
            {key:"quickControlHoverOpacity",label:"Hover surface opacity",percent:true},
            {key:"quickControlPanelRadius",label:"Panel corner radius"},
            {key:"quickControlComponentRadius",label:"Component corner radius"},
            {key:"quickControlIconRadius",label:"Icon corner radius"},
            {key:"quickControlComponentSpacing",label:"Component spacing"},
            {key:"quickControlSectionSpacing",label:"Section spacing"},
            {key:"quickControlPanelWidth",label:"Panel width"}
        ]
        ColumnLayout {
            id:row
            required property var modelData
            Layout.fillWidth:true;spacing:settingsPageRoot.settingsTheme.compactGap
            readonly property real factor:modelData.percent ? 100 : 1
            RowLayout {Layout.fillWidth:true
                GlassLabel {Layout.fillWidth:true;text:row.modelData.label;color:settingsPageRoot.settingsTheme.foreground;font.family:Fonts.poppins.name;font.pixelSize: Fonts.scale(12)}
                GlassLabel {text:Math.round(SettingsStore[row.modelData.key]*row.factor)+(row.modelData.percent ? "%" : " px");color:settingsPageRoot.settingsTheme.contentMuted;font.family:Fonts.poppins.name;font.pixelSize: Fonts.scale(12)}
            }
            SettingRangeSlider {
                objectName:row.modelData.key+"Slider"
                Layout.fillWidth:true
                enabled:SettingsStore.quickControlLayout!=="classic"
                minimum:SettingsStore.quickControlLimits[row.modelData.key][0]*row.factor
                maximum:SettingsStore.quickControlLimits[row.modelData.key][1]*row.factor
                step:1
                value:SettingsStore[row.modelData.key]*row.factor
                onPreview:next=>SettingsStore.setQuickControlSetting(row.modelData.key,next/row.factor,false)
                onCommit:next=>SettingsStore.setQuickControlSetting(row.modelData.key,next/row.factor,true)
            }
        }
    }
    GlassLabel {Layout.fillWidth:true;text:"Component-local desktop blur is unavailable in this window. Frameless uses a clean translucent fallback; it never blurs the whole transparent panel or changes Hyprland configuration.";wrapMode:Text.Wrap;color:settingsPageRoot.settingsTheme.contentMuted;font.family:Fonts.poppins.name;font.pixelSize: Fonts.scale(12)}
    ActionButton {objectName:"resetQuickControl";label:"Reset Quick Control appearance";symbol:"\ue5d5";onClicked:SettingsStore.resetQuickControlSettings()}
}
