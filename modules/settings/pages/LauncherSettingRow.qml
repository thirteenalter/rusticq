import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../../config"
import "../../../components"

ColumnLayout {
    id:root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    required property var spec
    readonly property string settingKey:spec.key
    readonly property var current:SettingsStore[settingKey]
    readonly property bool automatic:spec.geometry===true && SettingsStore.launcherUseStyleDefaults
        && ["compact","clean-hover"].indexOf(SettingsStore.launcherLayoutMode)<0
    visible:(!spec.styles || spec.styles.indexOf(SettingsStore.launcherLayoutMode)>=0)
        && (!spec.dimOnly || ["dim","dim-blur","focus"].indexOf(LauncherStyle.backdrop(SettingsStore.launcherLayoutMode))>=0)
        && (!spec.excludeStyles || spec.excludeStyles.indexOf(SettingsStore.launcherLayoutMode)<0)
        && (!spec.gridOnly || SettingsStore.launcherLayoutMode!=="detached" || SettingsStore.detachedLauncherResultMode!=="list")
        && (!spec.whenKey || SettingsStore[spec.whenKey]===spec.whenValue)
    spacing:5
    function update(value,persist){SettingsStore.setLauncherValue(settingKey,value,persist);}
    RowLayout {
        visible:root.spec.type!=="bool"
        Layout.fillWidth:true
        GlassLabel {Layout.fillWidth:true;text:root.spec.label;color:root.settingsTheme.foreground;font.family:Fonts.poppins.name;font.pixelSize: Fonts.scale(12)}
        GlassLabel {visible:root.spec.type==="range" || root.spec.type==="inherit"
            text:root.automatic ? "Style default" : root.current<0 && root.spec.type==="inherit" ? "Global" : Math.round(root.current*(root.spec.scale || 1))+(root.spec.suffix || "")
            color:root.settingsTheme.contentMuted;font.pixelSize: Fonts.scale(12)}
        ActionButton {visible:root.spec.type==="inherit";label:root.current<0 ? "Customize" : "Use global";implicitHeight:27
            onClicked:root.update(root.current<0 ? (root.spec.scale===100 ? .5 : SettingsStore.glassCornerRadius) : -1,true)}
    }
    Loader {
        Layout.fillWidth:true
        active:root.visible
        enabled:!root.automatic && (!root.spec.glassOnly || Theme.glassEnabled && SettingsStore.launcherGlassmorphismEnabled && SettingsStore.launcherMaterialMode!=="solid")
            && (!root.spec.type || root.spec.type!=="inherit" || root.current>=0)
        sourceComponent:root.spec.type==="bool" ? boolEditor : root.spec.type==="enum" ? enumEditor : root.spec.type==="text" ? textEditor : rangeEditor
    }
    Component {id:boolEditor
        SettingsToggle {objectName:root.settingKey+"Toggle";implicitHeight:59;modelData:({key:root.settingKey,label:root.spec.label,desc:root.spec.description || "",icon:"\ue8b8"})}
    }
    Component {id:enumEditor
        ComboBox {
            id:choice
            objectName:root.settingKey+"Choice"
            palette:ControlPalette { anchorItem:root }
            model:root.spec.choices || SettingsStore.launcherEnums[root.settingKey].map(value=>({key:value,label:value.replace(/-/g," ")}))
            textRole:"label";valueRole:"key"
            currentIndex:model.findIndex(value=>value.key===root.current)
            onActivated:index=>root.update(model[index].key,true)
            Accessible.name:root.spec.label
            font.family:Fonts.poppins.name;font.pixelSize: Fonts.scale(12)
        }
    }
    Component {id:textEditor
        TextField {
            objectName:root.settingKey+"Input";palette:ControlPalette { anchorItem:root }
            text:String(root.current);color:root.settingsTheme.foreground;selectByMouse:true
            font.family:Fonts.poppins.name;font.pixelSize:Fonts.scale(12)
            onEditingFinished:{if(!SettingsStore.setLauncherValue(root.settingKey,text,true))text=String(SettingsStore[root.settingKey]);}
            Accessible.name:root.spec.label
        }
    }
    Component {id:rangeEditor
        SettingRangeSlider {
            objectName:root.settingKey+"Slider"
            minimum:root.spec.min;maximum:root.spec.max;step:1
            value:Math.round(root.current*(root.spec.scale || 1))
            activeFocusOnTab:true;Accessible.name:root.spec.label
            onPreview:next=>root.update(next/(root.spec.scale || 1),false)
            onCommit:next=>root.update(next/(root.spec.scale || 1),true)
            Keys.onLeftPressed:root.update((value-1)/(root.spec.scale || 1),true)
            Keys.onRightPressed:root.update((value+1)/(root.spec.scale || 1),true)
        }
    }
}
