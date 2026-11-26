import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

SettingsSection {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    objectName:"barSurfaceSettings"
    heading:"Surface Styling"
    description:"Customize the visibility of bar backgrounds, outlines, and decorative surfaces independently."
    symbol:"\ue3ab"
    GlassLabel { text:"Live Bar Preview";color:root.settingsTheme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(12) }
    BarSurfacePreview { Layout.fillWidth:true }
    GlassLabel {
        Layout.fillWidth:true
        text:"Preview follows the live bar tokens. Floating group surfaces belong to Separated layout. Hover, selection and keyboard focus remain available with decorations hidden."
        color:root.settingsTheme.muted;font.family:Fonts.poppins.name;font.pixelSize: Fonts.scale(12);wrapMode:Text.WordWrap
    }
    GridLayout {
        Layout.fillWidth:true
        columns:width<460 ? 2 : 3
        columnSpacing:8;rowSpacing:8
        Repeater {
            model:[{key:"original",label:"Original"},{key:"rail",label:"Glass Rail"},{key:"borderless",label:"Borderless Glass"},
                {key:"floating",label:"Floating Segments"},{key:"outline",label:"Outline Only"},{key:"naked",label:"Naked Bar"}]
            delegate:ActionButton {
                required property var modelData
                objectName:"barSurfacePreset_"+modelData.key
                Layout.fillWidth:true
                label:modelData.label
                onClicked:SettingsStore.setBarSurfacePreset(modelData.key)
            }
        }
    }
    Repeater {
        model:[{label:"Bar Container",bg:"barBackgroundEnabled",outline:"barOutlineEnabled",name:"Bar"},
            {label:"Bar Segments",bg:"barSegmentBackgroundEnabled",outline:"barSegmentOutlineEnabled",name:"Segment"},
            {label:"Individual Modules",bg:"barModuleBackgroundEnabled",outline:"barModuleOutlineEnabled",name:"Module"}]
        delegate:ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth:true
            GlassLabel { text:group.modelData.label;color:root.settingsTheme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(12) }
            SettingsToggle {
                objectName:group.modelData.bg+"Toggle"
                modelData:({key:group.modelData.bg,label:"Show "+group.modelData.name+" Background",desc:"Decorative fill and background shading",icon:"\ue3ab"})
            }
            SettingsToggle {
                objectName:group.modelData.outline+"Toggle"
                modelData:({key:group.modelData.outline,label:"Show "+group.modelData.name+" Outline",desc:"Decorative border and specular edges",icon:"\ue3ab"})
            }
        }
    }
    SettingsToggle {
        objectName:"barGlassEnabledToggle"
        modelData:({key:"barGlassEnabled",label:"Glassmorphism on Bar",desc:"Use global RAGE materials in every layout; other panels stay independent",icon:"\ue3ab"})
    }
    SettingsToggle {
        objectName:"barRailFillEnabledToggle"
        modelData:({key:"barRailFillEnabled",label:"Fill outer rail in Separated",desc:"Optional enclosing rail; disabled by default to preserve floating segments",icon:"\ue3ab"})
    }
    SettingsToggle {
        objectName:"barCapsuleGeometryToggle"
        modelData:({key:"barCapsuleGeometry",label:"Capsule geometry",desc:"Round segments and modules to half their short edge; keep stored custom radii",icon:"\ue3ab"})
    }
    Repeater {
        model:[{key:"barOpacity",label:"Bar surface opacity",min:10,max:100,scale:100,suffix:"% of material"},
            {key:"barCornerRadius",label:"Bar corner radius",min:-1,max:64,scale:1,suffix:" px"},
            {key:"barSegmentRadius",label:"Bar segment radius",min:-1,max:64,scale:1,suffix:" px"},
            {key:"barModuleRadius",label:"Bar module radius",min:-1,max:64,scale:1,suffix:" px"}]
        delegate:ColumnLayout {
            id: range
            required property var modelData
            Layout.fillWidth:true
            RowLayout {
                Layout.fillWidth:true
                GlassLabel { Layout.fillWidth:true;text:range.modelData.label;color:root.settingsTheme.foreground;font.family:Fonts.poppins.name;font.pixelSize: Fonts.scale(12) }
                GlassLabel { text:SettingsStore[range.modelData.key]<0 ? "Follow layout" : Math.round(SettingsStore[range.modelData.key]*range.modelData.scale)+range.modelData.suffix;color:root.settingsTheme.accent;font.pixelSize: Fonts.scale(12) }
            }
            SettingRangeSlider {
                objectName:range.modelData.key+"Slider"
                Layout.fillWidth:true
                minimum:range.modelData.min;maximum:range.modelData.max
                value:Math.round(SettingsStore[range.modelData.key]*range.modelData.scale)
                activeFocusOnTab:true
                Accessible.name:range.modelData.label
                onPreview:next => SettingsStore.setBarSurfaceValue(range.modelData.key,next/range.modelData.scale,false)
                onCommit:next => SettingsStore.setBarSurfaceValue(range.modelData.key,next/range.modelData.scale,true)
                Keys.onLeftPressed:SettingsStore.setBarSurfaceValue(range.modelData.key,(value-1)/range.modelData.scale)
                Keys.onRightPressed:SettingsStore.setBarSurfaceValue(range.modelData.key,(value+1)/range.modelData.scale)
            }
        }
    }
    GlassLabel { Layout.fillWidth:true;text:"Visibility never changes bar spacing or input. Without alpha-aware compositor blur, RAGE uses the readable tinted fallback. A radius of −1 follows layout geometry.";color:root.settingsTheme.muted;font.pixelSize: Fonts.scale(12);wrapMode:Text.WordWrap }
    ActionButton { objectName:"barSurfaceReset";label:"Reset surface settings";onClicked:SettingsStore.resetBarSurfaceSettings() }
}
