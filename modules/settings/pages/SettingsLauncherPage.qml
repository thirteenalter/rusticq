import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    id:root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    width:parent ? parent.width : 700
    spacing:14
    readonly property var previewEntries:DesktopEntries.applications.values.slice(0,6)
    SettingsSection {
        heading:"Launcher Studio"
        description:"Eleven frontends share one search engine. Legacy preferences stay available; Spotlight is recommended for a new setup."
        symbol:"\ue8b6"
        GridLayout {
            Layout.fillWidth:true;columns:width<560 ? 1 : 2;columnSpacing:10;rowSpacing:10
            Repeater {
                model:LauncherStyle.styles
                delegate:Rectangle {
                    id:card;required property var modelData
                    objectName:"launcherStyle_"+modelData.key
                    activeFocusOnTab:true
                    Accessible.role:Accessible.RadioButton;Accessible.name:modelData.name
                    Accessible.checked:SettingsStore.launcherLayoutMode===modelData.key
                    Accessible.onPressAction:SettingsStore.setLauncherValue("launcherLayoutMode",modelData.key,true)
                    Keys.onSpacePressed:SettingsStore.setLauncherValue("launcherLayoutMode",modelData.key,true)
                    Keys.onReturnPressed:SettingsStore.setLauncherValue("launcherLayoutMode",modelData.key,true)
                    Layout.fillWidth:true;Layout.preferredHeight:260
                    radius:root.settingsTheme.rowRadius;color:root.settingsTheme.glassColor("card",root.settingsTheme.background)
                    border.width:SettingsStore.launcherLayoutMode===modelData.key || activeFocus ? 1 : 0;border.color:root.settingsTheme.accent
                    ColumnLayout {
                        anchors.fill:parent;anchors.margins:10;spacing:7
                        LauncherStylePreview {Layout.fillWidth:true;Layout.preferredHeight:155;style:card.modelData.key;entries:root.previewEntries}
                        RowLayout {Layout.fillWidth:true
                            GlassLabel {Layout.fillWidth:true;text:card.modelData.name;color:root.settingsTheme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(12)}
                            Icon {visible:SettingsStore.launcherLayoutMode===card.modelData.key;icon:"\ue5ca";color:root.settingsTheme.accent;font.pixelSize:18}
                        }
                        GlassLabel {Layout.fillWidth:true;Layout.fillHeight:true;text:card.modelData.description;wrapMode:Text.WordWrap;color:root.settingsTheme.contentMuted;font.pixelSize: Fonts.scale(12)}
                    }
                    MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{card.forceActiveFocus();SettingsStore.setLauncherValue("launcherLayoutMode",card.modelData.key,true);}}
                }
            }
        }
        RowLayout {
            Layout.fillWidth:true
            ActionButton {objectName:"testLauncherButton";label:"Test Launcher";symbol:"\ue037";onClicked:Store.toggleLauncher(Store.settingsScreen || Store.launcherScreen)}
            ActionButton {label:"Reset dimensions";onClicked:SettingsStore.resetLauncherSize()}
            ActionButton {objectName:"resetLauncherAppearanceButton";label:"Reset Launcher Appearance";onClicked:SettingsStore.resetLauncherAppearance()}
        }
        GlassLabel {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:root.settingsTheme.contentMuted;font.pixelSize: Fonts.scale(12)
            text:"Calculator: =expression · Providers: :files, :folders, :notes, :settings, :windows, :workspaces, :emoji, :wallpaper, :color and :ocr. Right-click an application to pin it."}
    }
    SettingsSection {
        heading:"Layout"
        description:"Shared geometry and presentation. Style defaults adapt the geometry to the selected frontend."
        symbol:"\ue8b8"
        Repeater {
            model:([{"type":"bool","key":"launcherUseStyleDefaults","label":"Use recommended style geometry","styles":["spotlight","raycast","launchpad","fluent","minimal","classic","overview","command","detached"]},{"type":"range","key":"launcherWidth","label":"Window width","min":320,"max":1920,"suffix":" px","geometry":true},{"type":"range","key":"launcherHeight","label":"Maximum height","min":120,"max":1200,"suffix":" px","geometry":true},{"type":"range","key":"launcherSearchHeight","label":"Search field height","min":40,"max":100,"suffix":" px","geometry":true,"styles":["spotlight","raycast","launchpad","fluent","minimal","classic","overview","command"]},{"type":"range","key":"launcherSearchFontSize","label":"Search font size","min":12,"max":32,"suffix":" px","geometry":true,"styles":["spotlight","raycast","launchpad","fluent","minimal","classic","overview","command"]},{"type":"range","key":"launcherRowHeight","label":"Result row height","min":28,"max":96,"suffix":" px"},{"type":"range","key":"launcherIconSize","label":"List icon size","min":16,"max":96,"suffix":" px"},{"type":"range","key":"launcherGridIconSize","label":"Grid icon size","min":32,"max":128,"suffix":" px","styles":["launchpad","overview","fluent","detached"],"gridOnly":true},{"type":"range","key":"launcherGridColumns","label":"Maximum grid columns","min":2,"max":12,"styles":["launchpad","overview","fluent","detached"],"gridOnly":true},{"type":"range","key":"launcherFavoriteColumns","label":"Frequent apps per row","min":2,"max":8,"styles":["compact"]},{"type":"range","key":"launcherResultSpacing","label":"Result spacing","min":0,"max":24,"suffix":" px"},{"type":"range","key":"launcherPadding","label":"Internal padding","min":4,"max":40,"suffix":" px"},{"type":"bool","key":"launcherShowBranding","label":"Show launcher branding","styles":["spotlight","raycast","launchpad","fluent","minimal","classic","overview","command"]},{"type":"bool","key":"launcherShowCategories","label":"Show result categories","styles":["compact","raycast","launchpad","fluent","classic","overview","spotlight","detached"]},{"type":"bool","key":"launcherShowFavorites","label":"Show favorites"},{"type":"bool","key":"launcherShowRecent","label":"Show recent applications","styles":["raycast","launchpad","fluent","classic","overview"]},{"type":"bool","key":"launcherShowShortcutHints","label":"Show keyboard hints","excludeStyles":["detached"]},{"type":"bool","key":"launcherShowIcons","label":"Show list icons"},{"type":"bool","key":"launcherShowPreview","label":"Show result detail preview","styles":["raycast","spotlight","classic"]}])
            delegate:LauncherSettingRow {required property var modelData;spec:modelData;Layout.fillWidth:true}
        }
    }
    SettingsSection {
        heading:"Position"
        description:"Monitor-relative placement, clamped to the active screen. Follow bar uses its actual trigger when opened from the bar."
        symbol:"\ue8b8"
        Repeater {
            model:([{"type":"enum","key":"launcherPosition","label":"Launcher position"},{"type":"range","key":"launcherOffsetX","label":"Horizontal offset","min":-1000,"max":1000,"suffix":" px"},{"type":"range","key":"launcherOffsetY","label":"Vertical offset","min":-1000,"max":1000,"suffix":" px"},{"type":"range","key":"launcherCustomX","label":"Custom horizontal position","min":0,"max":100,"scale":100,"suffix":"%","whenKey":"launcherPosition","whenValue":"custom"},{"type":"range","key":"launcherCustomY","label":"Custom vertical position","min":0,"max":100,"scale":100,"suffix":"%","whenKey":"launcherPosition","whenValue":"custom"}])
            delegate:LauncherSettingRow {required property var modelData;spec:modelData;Layout.fillWidth:true}
        }
    }
    SettingsSection {
        heading:"Material"
        description:"One resolved RAGE material. Disabling launcher glass leaves the selected palette and other shell surfaces unchanged."
        symbol:"\ue8b8"
        Repeater {
            model:([{"type":"enum","key":"launcherMaterialMode","label":"Material source","choices":[{"key":"inherit","label":"Inherit global material"},{"key":"solid","label":"Solid material"}]},{"type":"bool","key":"launcherGlassmorphismEnabled","label":"Glassmorphism on launcher"},{"type":"inherit","key":"launcherOpacity","label":"Material opacity","min":15,"max":100,"scale":100,"suffix":"%","glassOnly":true},{"type":"inherit","key":"launcherCornerRadius","label":"Corner radius","min":0,"max":48,"suffix":" px","excludeStyles":["detached"]},{"type":"bool","key":"launcherBackgroundEnabled","label":"Show launcher background","excludeStyles":["detached"]},{"type":"bool","key":"launcherOutlineEnabled","label":"Show launcher outline","excludeStyles":["detached"]},{"type":"bool","key":"launcherHighlightsEnabled","label":"Glass edge highlights"}])
            delegate:LauncherSettingRow {required property var modelData;spec:modelData;Layout.fillWidth:true}
        }
    }
    SettingsSection {
        heading:"Desktop Backdrop"
        description:"None leaves the desktop outside the bounded launcher unchanged. Blur uses a separate compositor-owned surface only when explicitly requested."
        symbol:"\ue8b8"
        Repeater {
            model:([{"type":"enum","key":"launcherBackdropMode","label":"Backdrop mode","choices":[{"key":"auto","label":"Use style default"},{"key":"none","label":"None"},{"key":"dim","label":"Dim"},{"key":"blur","label":"Blur"},{"key":"dim-blur","label":"Dim and Blur"},{"key":"focus","label":"Focus (stronger dim)"}]},{"type":"range","key":"launcherBackdropOpacity","label":"Dim / fallback intensity","min":0,"max":85,"scale":100,"suffix":"%","dimOnly":true}])
            delegate:LauncherSettingRow {required property var modelData;spec:modelData;Layout.fillWidth:true}
        }
        GlassLabel {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:root.settingsTheme.contentMuted;font.pixelSize: Fonts.scale(12)
            text:Store.glassCompositorStatus+" Independent blur strength is not exposed by this backend. Performance/low-memory mode uses a dim fallback."}
    }
    SettingsSection {
        heading:"Animation"
        description:"Uses SurfaceMotion and respects Interface animations. None applies changes immediately."
        symbol:"\ue8b8"
        Repeater {
            model:([{"type":"enum","key":"launcherAnimationStyle","label":"Launcher animation"}])
            delegate:LauncherSettingRow {required property var modelData;spec:modelData;Layout.fillWidth:true}
        }
    }
    SettingsSection {
        heading:"Detached \u00b7 Search Input"
        description:"The input remains stationary while the separate results surface changes. Shared width and position are configured above."
        symbol:"\ue8b8"
        visible:SettingsStore.launcherLayoutMode==="detached"
        Repeater {
            model:([{"type":"range","key":"detachedLauncherInputHeight","label":"Input height","min":44,"max":96,"suffix":" px"},{"type":"range","key":"detachedLauncherInputFontSize","label":"Input font size","min":14,"max":32,"suffix":" px"},{"type":"range","key":"detachedLauncherInputRadius","label":"Input corner radius","min":0,"max":48,"suffix":" px"},{"type":"text","key":"detachedLauncherPlaceholder","label":"Search placeholder"},{"type":"bool","key":"detachedLauncherShowIcon","label":"Show search icon"},{"type":"bool","key":"detachedLauncherShowHint","label":"Show Escape hint"},{"type":"bool","key":"detachedLauncherInputGlassEnabled","label":"Glassmorphism on input"},{"type":"bool","key":"detachedLauncherInputBackgroundEnabled","label":"Show input background"},{"type":"bool","key":"detachedLauncherInputOutlineEnabled","label":"Show input outline"},{"type":"bool","key":"detachedLauncherInputHighlights","label":"Input edge highlights"},{"type":"bool","key":"detachedLauncherInputInheritMaterial","label":"Use global input opacity and shadow"},{"type":"range","key":"detachedLauncherInputOpacity","label":"Input opacity","min":15,"max":100,"scale":100,"suffix":"%","glassOnly":true,"whenKey":"detachedLauncherInputInheritMaterial","whenValue":false},{"type":"range","key":"detachedLauncherInputShadowIntensity","label":"Input shadow intensity","min":0,"max":60,"scale":100,"suffix":"%","glassOnly":true,"whenKey":"detachedLauncherInputInheritMaterial","whenValue":false}])
            delegate:LauncherSettingRow {required property var modelData;spec:modelData;Layout.fillWidth:true}
        }
    }
    SettingsSection {
        heading:"Detached \u00b7 Results Box"
        description:"Apps can use a list or grid. Files, settings, notes and commands stay lists; calculator results use a dedicated card."
        symbol:"\ue8b8"
        visible:SettingsStore.launcherLayoutMode==="detached"
        Repeater {
            model:([{"type":"enum","key":"detachedLauncherResultMode","label":"Result presentation"},{"type":"enum","key":"detachedLauncherAppLayout","label":"Adaptive application layout","whenKey":"detachedLauncherResultMode","whenValue":"adaptive"},{"type":"enum","key":"detachedLauncherResultWidthMode","label":"Results width"},{"type":"range","key":"detachedLauncherResultsWidth","label":"Custom results width","min":320,"max":1600,"suffix":" px","whenKey":"detachedLauncherResultWidthMode","whenValue":"custom"},{"type":"range","key":"detachedLauncherMaxResults","label":"Maximum results","min":1,"max":100},{"type":"range","key":"detachedLauncherResultsRadius","label":"Results corner radius","min":0,"max":48,"suffix":" px"},{"type":"bool","key":"detachedLauncherResultsGlassEnabled","label":"Glassmorphism on results"},{"type":"bool","key":"detachedLauncherResultsBackgroundEnabled","label":"Show results background"},{"type":"bool","key":"detachedLauncherResultsOutlineEnabled","label":"Show results outline"},{"type":"bool","key":"detachedLauncherResultsHighlights","label":"Results edge highlights"},{"type":"bool","key":"detachedLauncherResultsInheritMaterial","label":"Use global results opacity and shadow"},{"type":"range","key":"detachedLauncherResultsOpacity","label":"Results opacity","min":15,"max":100,"scale":100,"suffix":"%","glassOnly":true,"whenKey":"detachedLauncherResultsInheritMaterial","whenValue":false},{"type":"range","key":"detachedLauncherResultsShadowIntensity","label":"Results shadow intensity","min":0,"max":60,"scale":100,"suffix":"%","glassOnly":true,"whenKey":"detachedLauncherResultsInheritMaterial","whenValue":false}])
            delegate:LauncherSettingRow {required property var modelData;spec:modelData;Layout.fillWidth:true}
        }
    }
    SettingsSection {
        heading:"Detached \u00b7 Layout"
        description:"Both surfaces share one logical session, one native window, and one search input. The gap has no fill, outline or input region."
        symbol:"\ue8b8"
        visible:SettingsStore.launcherLayoutMode==="detached"
        Repeater {
            model:([{"type":"range","key":"detachedLauncherGap","label":"Gap between boxes","min":0,"max":32,"suffix":" px"},{"type":"enum","key":"detachedLauncherResultAlignment","label":"Results alignment"},{"type":"enum","key":"detachedLauncherExpansionDirection","label":"Expansion direction"},{"type":"bool","key":"detachedLauncherShowEmptyResults","label":"Show results for an empty query"}])
            delegate:LauncherSettingRow {required property var modelData;spec:modelData;Layout.fillWidth:true}
        }
        ActionButton {objectName:"resetDetachedLauncherButton";label:"Reset Detached Launcher Appearance";onClicked:SettingsStore.resetDetachedLauncherAppearance()}
    }
}
