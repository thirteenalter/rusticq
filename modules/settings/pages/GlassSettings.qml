import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import "../../../services"
import ".."

SettingsSection {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    objectName: "glassSettingsSection"
    heading: "Glassmorphism"
    description: "Customize translucent surfaces, background blur, and glass effects across the RusticQ desktop."
    symbol: "\ue3ab"
    function update(key, value, persist) {
        if (SettingsStore.glassmorphismEnabled) SettingsStore.setGlassValue(key, value, persist);
    }
    GlassLabel { text: "Theme provider"; color: root.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: [{key:"adaptive",label:"Adaptive"},{key:"exclusive",label:"RAGE Exclusive"}]
            delegate: ActionButton {
                required property var modelData
                objectName: "rageMode_" + modelData.key
                Layout.fillWidth: true
                label: modelData.label
                selected: SettingsStore.rageMode === modelData.key
                onClicked: SettingsStore.setGlassValue("rageMode",modelData.key,true)
            }
        }
    }
    GlassLabel {
        Layout.fillWidth: true
        text: Theme.rageExclusive ? "RAGE Native supplies every color, including solid surfaces. External theme preferences are preserved. Glass can be enabled independently."
            : "Adaptive uses the saved Gruvbox or Aether palette. Choose Exclusive for independent neutral RAGE materials."
        wrapMode: Text.WordWrap; color: root.settingsTheme.secondaryForeground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
    }
    GridLayout {
        visible: Theme.rageExclusive
        Layout.fillWidth: true
        columns: width < 440 ? 2 : 4
        Repeater {
            model: [{key:"obsidian",label:"Obsidian"},{key:"pearl",label:"Pearl"},
                {key:"pure-crystal",label:"Pure Crystal"},{key:"graphite-frost",label:"Graphite Frost"}]
            delegate: ActionButton {
                required property var modelData
                objectName: "ragePalette_" + modelData.key
                Layout.fillWidth: true
                label: modelData.label
                selected: SettingsStore.ragePalette === modelData.key
                onClicked: SettingsStore.setGlassValue("ragePalette",modelData.key,true)
            }
        }
    }
    SettingsToggle {
        objectName: "glassMasterToggle"
        modelData: ({key:"glassmorphismEnabled", label:"Enable Glassmorphism",
            desc:"RAGE · RUSTIQ ADAPTIVE GLASS ENGINE", icon:"\ue3ab"})
    }
    GlassPreview { Layout.fillWidth: true }
    GlassLabel {
        Layout.fillWidth: true
        text: "Live preview uses the current palette. Desktop background blur is rendered by the compositor."
        color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        wrapMode: Text.WordWrap
    }
    ColumnLayout {
        id: controls
        objectName: "glassCustomizationControls"
        Layout.fillWidth: true
        enabled: SettingsStore.glassmorphismEnabled
        spacing: root.settingsTheme.sectionGap
        RowLayout {
            Layout.fillWidth: true
            GlassLabel { Layout.fillWidth: true; text:"Glass Style"; color:root.settingsTheme.foreground; font.family:Fonts.poppinsSB.name; font.pixelSize:Fonts.scale(12) }
            ActionButton { objectName:"glassResetButton"; label:"Reset Glass Settings"; onClicked:SettingsStore.resetGlassSettings() }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: width < 440 ? 1 : 3
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: [{key:"frosted",label:"Frosted Glass"}, {key:"crystal",label:"Crystal Glass"}, {key:"tinted",label:"Tinted Glass"}]
                delegate: ActionButton {
                    required property var modelData
                    objectName: "glassPreset_" + modelData.key
                    Layout.fillWidth: true
                    label: modelData.label
                    selected: SettingsStore.glassStyle === modelData.key
                    onClicked: SettingsStore.setGlassPreset(modelData.key)
                }
            }
        }
        GlassLabel {
            Layout.fillWidth: true
            text: SettingsStore.glassStyle === "crystal"
                ? "Clearer glass with refined highlights. This is a glass-inspired style, without backdrop refraction."
                : SettingsStore.glassStyle === "tinted" ? (Theme.rageExclusive ? "Neutral native tint with additional readability." : "A restrained tint follows the resolved Gruvbox or Aether palette.")
                : "Soft frosted surfaces, restrained highlights and thin luminous edges."
            wrapMode: Text.WordWrap; color:root.settingsTheme.muted; font.family:Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
        Repeater {
            model: [{key:"glassOpacity",label:"Surface Opacity",min:15,max:100,scale:100,suffix:"%"},
                {key:"glassTintStrength",label:"Glass Tint Strength",min:0,max:50,scale:100,suffix:"%"},
                {key:"glassCornerRadius",label:"Corner Radius",min:0,max:32,scale:1,suffix:" px"},
                {key:"glassBorderOpacity",label:"Border Intensity",min:0,max:60,scale:100,suffix:"%"},
                {key:"glassShadowIntensity",label:"Shadow Intensity",min:0,max:60,scale:100,suffix:"%"}]
            delegate: ColumnLayout {
                id: sliderRow
                required property var modelData
                Layout.fillWidth: true
                enabled: modelData.key !== "glassShadowIntensity" || SettingsStore.glassShadowEnabled
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    GlassLabel { Layout.fillWidth:true; text:sliderRow.modelData.label; color:root.settingsTheme.foreground; font.family:Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
                    GlassLabel { text:Math.round(SettingsStore[sliderRow.modelData.key]*sliderRow.modelData.scale)+sliderRow.modelData.suffix; color:root.settingsTheme.accent; font.family:Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                }
                SettingRangeSlider {
                    objectName: sliderRow.modelData.key + "Slider"
                    Layout.fillWidth: true
                    minimum: sliderRow.modelData.min; maximum: sliderRow.modelData.max; step:1
                    value: Math.round(SettingsStore[sliderRow.modelData.key]*sliderRow.modelData.scale)
                    activeFocusOnTab:true
                    Accessible.name:sliderRow.modelData.label
                    onPreview: next => root.update(sliderRow.modelData.key, next/sliderRow.modelData.scale, false)
                    onCommit: next => root.update(sliderRow.modelData.key, next/sliderRow.modelData.scale, true)
                    Keys.onLeftPressed: root.update(sliderRow.modelData.key, (value-1)/sliderRow.modelData.scale, true)
                    Keys.onRightPressed: root.update(sliderRow.modelData.key, (value+1)/sliderRow.modelData.scale, true)
                }
            }
        }
        SettingsToggle {
            objectName:"glassReflectionEnabledToggle"
            modelData:({key:"glassReflectionEnabled",label:"Specular Highlights",desc:"Restrained static reflections along the glass edge",icon:"\ue3ab"})
        }
        SettingsToggle {
            objectName:"glassShadowEnabledToggle"
            modelData:({key:"glassShadowEnabled",label:"Soft Shadows",desc:"Bounded soft contact shading; compositor decorations stay independent",icon:"\ue3ab"})
        }
        GlassLabel { text:"Background blur"; color:root.settingsTheme.foreground; font.family:Fonts.poppinsSB.name; font.pixelSize:Fonts.scale(12) }
        SettingsToggle {
            objectName:"glassBlurEnabledToggle"
            modelData:({key:"glassBlurEnabled",label:"Enable Background Blur",desc:"Use compositor-native blur when a safe adapter is available",icon:"\ue3ab"})
        }
        GlassLabel {
            objectName:"glassCompositorStatus"
            Layout.fillWidth:true
            text:Store.glassCompositorStatus
            wrapMode:Text.WordWrap; color:Store.glassBlurActive ? root.settingsTheme.success : root.settingsTheme.muted
            font.family:Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
        SettingRangeSlider {
            objectName:"glassBlurRadiusSlider"
            visible:Store.glassBlurStrengthEditable
            Layout.fillWidth:true
            minimum:0;maximum:64;value:SettingsStore.glassBlurRadius
            onPreview: next => root.update("glassBlurRadius",next,false)
            onCommit: next => root.update("glassBlurRadius",next,true)
            Accessible.name:"Independent background blur strength"
        }
        GlassLabel {
            Layout.fillWidth:true
            visible:!Store.glassBlurStrengthEditable
            text:"Blur strength is compositor-owned on this backend. RAGE does not change global blur. Without blur, opacity adapts to at least 86% for readability."
            wrapMode:Text.WordWrap; color:root.settingsTheme.muted; font.family:Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
        ActionButton { objectName:"glassRefreshSupport"; label:"Refresh compositor support"; symbol:"\ue5d5"; onClicked:{GlassService.initialize();GlassService.refresh();} }
        GlassLabel { text:"Performance"; color:root.settingsTheme.foreground; font.family:Fonts.poppinsSB.name; font.pixelSize:Fonts.scale(12) }
        SettingsToggle {
            objectName:"glassPerformanceModeToggle"
            modelData:({key:"glassPerformanceMode",label:"Glass Performance Mode",desc:"Keep basic glass; suspend blur, reflections and soft shading",icon:"\ue322"})
        }
        GlassLabel {
            Layout.fillWidth:true
            text:SettingsStore.lowMemoryShellMode ? "Low-memory shell mode also suspends costly glass effects without changing saved glass preferences."
                : "RAGE uses one translucent material, subtle edge lighting and compositor blur. No screen capture, refraction or continuous animation."
            wrapMode:Text.WordWrap; color:root.settingsTheme.muted; font.family:Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
    }
}
