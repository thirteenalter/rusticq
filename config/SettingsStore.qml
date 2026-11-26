pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Small persistent, non-secret UI settings. Never store API keys here.
Singleton {
    id: root
    property bool settingsLoaded: false
    property string settingsSnapshot: ""
    property string accentName: "orange"
    // Explicit opt-in: keep original Gruvbox when Aether is unavailable.
    property string colorSource: "gruvbox"
    property string barMode: "separated"
    property bool barVisible: true
    property bool barAutoHide: false
    property bool barPopupsOnHover: false
    property bool showBarRecoveryHandle: true
    readonly property string barVisibilityMode: barVisible ? (barAutoHide ? "auto" : "show") : (showBarRecoveryHandle ? "hide" : "hidden")
    property bool showBarToggleIcon: true
    function setBarVisibilityMode(mode) {
        if (["show", "auto", "hide", "hidden"].indexOf(mode) < 0) return;
        barAutoHide = mode === "auto";
        showBarRecoveryHandle = mode !== "hidden";
        barVisible = mode === "show" || mode === "auto";
        save();
    }
    function setBarVisible(enabled) {
        if (typeof enabled !== "boolean") return;
        setBarVisibilityMode(enabled ? "show" : "hide");
    }
    function toggleBar() { setBarVisible(!barVisible); }
    function toggleBarCompletely() { setBarVisibilityMode(barVisible ? "hidden" : "show"); }
    property string barPosition: "top"
    property bool absoluteCenter: true
    property int centerOffsetX: 0
    property string uiFontFamily: "poppins"
    property string uiCustomFont: ""
    property real uiFontScale: 1.0
    property string uiDensity: "comfortable"
    // -1 follows density; zero is a valid manual inset. These affect content,
    // never the bar's custom geometry or the launcher's independent padding.
    property int surfacePanelPadding: -1
    property int surfaceCardPadding: -1
    property int surfaceControlPadding: -1
    property int surfaceContentGap: -1
    property int surfaceInlineGap: -1
    readonly property var surfaceSpacingDefaults: ({surfacePanelPadding:-1, surfaceCardPadding:-1,
        surfaceControlPadding:-1, surfaceContentGap:-1, surfaceInlineGap:-1})
    readonly property var surfaceSpacingMaximums: ({surfacePanelPadding:32, surfaceCardPadding:24,
        surfaceControlPadding:20, surfaceContentGap:24, surfaceInlineGap:16})
    function setSurfaceSpacing(key, value, persist) {
        if (!Object.prototype.hasOwnProperty.call(surfaceSpacingDefaults,key)
            || !Number.isInteger(value) || value < -1 || value > surfaceSpacingMaximums[key]) return false;
        root[key] = value;
        if (persist !== false) save();
        return true;
    }
    function applySurfaceSpacingSettings(data) {
        if (!data || typeof data !== "object" || Array.isArray(data)) return;
        for (const key of Object.keys(surfaceSpacingDefaults))
            if (Object.prototype.hasOwnProperty.call(data,key)) setSurfaceSpacing(key,data[key],false);
    }
    function resetSurfaceSpacing() { applySurfaceSpacingSettings(surfaceSpacingDefaults); save(); }
    property bool animationsEnabled: true
    // Existing installations stay Classic until the user selects a new layout.
    property var surfaceMaterialOverrides: ({})
    function loadSurfaceMaterials(data) {
        const next={};const source=data.surfaceMaterialOverrides;
        if (!source || typeof source!=="object" || Array.isArray(source))return;
        for(const key of ["dock","notifications","widgets","popovers","dialogs"]) {
            const v=source[key];if(!v || typeof v!=="object")continue;
            next[key]={inherit:v.inherit!==false,glass:v.glass!==false,background:v.background!==false,outline:v.outline!==false,
                opacity:typeof v.opacity==="number" && Number.isFinite(v.opacity)?Math.max(0.15,Math.min(1,v.opacity)):0.6,
                radius:typeof v.radius==="number" && Number.isFinite(v.radius)?Math.max(0,Math.min(32,Math.round(v.radius))):16};
        }
        surfaceMaterialOverrides=next;
    }
    function setSurfaceMaterial(surface,key,value) {
        const next=JSON.parse(JSON.stringify(surfaceMaterialOverrides));
        next[surface]=Object.assign({},next[surface] || {},{[key]:value});loadSurfaceMaterials({surfaceMaterialOverrides:next});save();
    }
    property var settingsWindowAppearance: ({shared:{},rusticq:{enabled:false,values:{}},hyprland:{enabled:false,values:{}}})
    property int rusticSettingsWidth: 1100
    property int rusticSettingsHeight: 760
    function validSettingsAppearance(values) {
        const result={};
        if (!values || typeof values!=="object" || Array.isArray(values)) return result;
        const ranges={windowOpacity:[0.15,1],sidebarOpacity:[0,1],groupOpacity:[0.01,0.5],popoverOpacity:[0.8,1],outlineOpacity:[0,0.5],outlineWidth:[0,2],radius:[0,28],sidebarWidth:[220,280],shadow:[0,0.3]};
        const choices={mode:["follow","rage-dark","rage-light","neutral-dark","neutral-light"],density:["compact","comfortable"],iconStyle:["color","neutral"]};
        for (const key of Object.keys(values)) {
            const value=values[key];
            if (ranges[key] && typeof value==="number" && Number.isFinite(value)) result[key]=["radius","sidebarWidth"].indexOf(key)>=0?Math.round(Math.max(ranges[key][0],Math.min(ranges[key][1],value))):Math.max(ranges[key][0],Math.min(ranges[key][1],value));
            else if (choices[key] && choices[key].indexOf(value)>=0) result[key]=value;
            else if (["outline","animations"].indexOf(key)>=0 && typeof value==="boolean") result[key]=value;
            else if (key==="accent" && typeof value==="string" && /^#[0-9a-fA-F]{6}$/.test(value)) result[key]=value;
        }
        return result;
    }
    function loadSettingsAppearance(data) {
        if (Number.isFinite(data.rusticSettingsWidth)) rusticSettingsWidth=Math.round(Math.max(800,Math.min(2400,data.rusticSettingsWidth)));
        if (Number.isFinite(data.rusticSettingsHeight)) rusticSettingsHeight=Math.round(Math.max(560,Math.min(1800,data.rusticSettingsHeight)));
        const value=data.settingsWindowAppearance;
        if (!value || typeof value!=="object" || Array.isArray(value)) {
            if (data.hyprSettingsGlass===true || ["light","follow"].indexOf(data.hyprSettingsTheme)>=0) {
                const mode=data.hyprSettingsTheme==="follow"?"follow":(data.hyprSettingsGlass?"rage-":"neutral-")+(data.hyprSettingsTheme==="light"?"light":"dark");
                settingsWindowAppearance={shared:{},rusticq:{enabled:false,values:{}},hyprland:{enabled:true,values:{mode:mode}}};
            }
            return;
        }
        const next={shared:validSettingsAppearance(value.shared)};
        for (const app of ["rusticq","hyprland"]) next[app]={enabled:!!value[app] && value[app].enabled===true,values:validSettingsAppearance(value[app] && value[app].values)};
        settingsWindowAppearance=next;
    }
    function setSettingsAppearance(app,key,value,persist) {
        if (["shared","rusticq","hyprland"].indexOf(app)<0) return;
        const next=JSON.parse(JSON.stringify(settingsWindowAppearance));
        if (app!=="shared" && key==="enabled") next[app].enabled=value===true;
        else {
            const validated=validSettingsAppearance({[key]:value});
            if (!Object.prototype.hasOwnProperty.call(validated,key)) return;
            if(app==="shared") next.shared=Object.assign({},next.shared,validated);
            else next[app].values=Object.assign({},next[app].values,validated);
        }
        settingsWindowAppearance=next;if(persist!==false)save();
    }
    function resetSettingsAppearance() { settingsWindowAppearance={shared:{},rusticq:{enabled:false,values:{}},hyprland:{enabled:false,values:{}}};save(); }
    property int hyprSettingsWidth: 1100
    property int hyprSettingsHeight: 760
    property string hyprSettingsTheme: "dark"
    property bool hyprSettingsGlass: false
    property bool hyprSettingsShowUnsupported: true
    readonly property var hyprSettingsDefaults: ({hyprSettingsWidth:1100,hyprSettingsHeight:760,
        hyprSettingsTheme:"dark",hyprSettingsGlass:false,hyprSettingsShowUnsupported:true})
    function loadHyprSettingsPreferences(data) {
        if (Number.isFinite(data.hyprSettingsWidth)) hyprSettingsWidth = Math.max(800, Math.min(2400, Math.round(data.hyprSettingsWidth)));
        if (Number.isFinite(data.hyprSettingsHeight)) hyprSettingsHeight = Math.max(560, Math.min(1800, Math.round(data.hyprSettingsHeight)));
        if (["follow", "dark", "light"].indexOf(data.hyprSettingsTheme) >= 0) hyprSettingsTheme = data.hyprSettingsTheme;
        if (typeof data.hyprSettingsGlass === "boolean") hyprSettingsGlass = data.hyprSettingsGlass;
        if (typeof data.hyprSettingsShowUnsupported === "boolean") hyprSettingsShowUnsupported = data.hyprSettingsShowUnsupported;
    }
    function resetHyprSettingsPreferences() {
        loadHyprSettingsPreferences(hyprSettingsDefaults); save();
    }
    property string quickControlLayout: "classic"
    property bool quickControlPanelBackground: false
    property bool quickControlPanelOutline: false
    property bool quickControlComponentBackground: true
    property bool quickControlComponentOutline: false
    property bool quickControlComponentGlass: true
    property bool quickControlAccentTint: false
    property real quickControlSurfaceOpacity: 0.94
    property real quickControlHoverOpacity: 0.98
    property int quickControlPanelRadius: 20
    property int quickControlComponentRadius: 16
    property int quickControlIconRadius: 12
    property int quickControlComponentSpacing: 8
    property int quickControlSectionSpacing: 20
    property int quickControlPanelWidth: 400
    property bool quickControlCompact: false
    property bool quickControlAnimations: true
    readonly property var quickControlDefaults: ({quickControlLayout:"classic", quickControlPanelBackground:false,
        quickControlPanelOutline:false, quickControlComponentBackground:true, quickControlComponentOutline:false,
        quickControlComponentGlass:true, quickControlAccentTint:false, quickControlSurfaceOpacity:0.94,
        quickControlHoverOpacity:0.98, quickControlPanelRadius:20, quickControlComponentRadius:16,
        quickControlIconRadius:12, quickControlComponentSpacing:8, quickControlSectionSpacing:20,
        quickControlPanelWidth:400, quickControlCompact:false, quickControlAnimations:true})
    readonly property var quickControlLimits: ({quickControlSurfaceOpacity:[0,1], quickControlHoverOpacity:[0,1],
        quickControlPanelRadius:[0,40], quickControlComponentRadius:[0,32], quickControlIconRadius:[0,28],
        quickControlComponentSpacing:[0,24], quickControlSectionSpacing:[0,40], quickControlPanelWidth:[320,560]})
    function setQuickControlSetting(key, value, persist) {
        if (!Object.prototype.hasOwnProperty.call(quickControlDefaults,key)) return false;
        if (key === "quickControlLayout") {
            if (["classic","modular","frameless"].indexOf(value) < 0) return false;
        } else if (typeof quickControlDefaults[key] === "boolean") {
            if (typeof value !== "boolean") return false;
        } else {
            if (typeof value !== "number" || !Number.isFinite(value)) return false;
            value = Math.max(quickControlLimits[key][0],Math.min(quickControlLimits[key][1],value));
            if (key !== "quickControlSurfaceOpacity" && key !== "quickControlHoverOpacity") value = Math.round(value);
        }
        root[key] = value;
        if (persist !== false) save();
        return true;
    }
    function applyQuickControlSettings(data) {
        if (!data || typeof data !== "object" || Array.isArray(data)) return;
        for (const key of Object.keys(quickControlDefaults))
            if (Object.prototype.hasOwnProperty.call(data,key)) setQuickControlSetting(key,data[key],false);
    }
    function resetQuickControlSettings() { applyQuickControlSettings(quickControlDefaults); save(); }
    property bool showSpeedTestPanel: true
    property bool showSpeedometerGauge: true
    property bool speedTestGaugeAnimation: true
    property bool speedTestGaugeGlow: false
    property bool showSpeedTestTime: true
    property string speedTestPanelStyle: "classic"
    readonly property var networkPanelDefaults: ({showSpeedTestPanel:true, showSpeedometerGauge:true,
        speedTestGaugeAnimation:true, speedTestGaugeGlow:false, showSpeedTestTime:true, speedTestPanelStyle:"classic"})
    function setNetworkPanelSetting(key, value, persist) {
        if (!Object.prototype.hasOwnProperty.call(networkPanelDefaults,key)) return false;
        if (key === "speedTestPanelStyle") {
            if (["classic", "modern", "compact"].indexOf(value) < 0) return false;
        } else if (typeof value !== "boolean") return false;
        root[key] = value;
        if (persist !== false) save();
        return true;
    }
    function applyNetworkPanelSettings(data) {
        if (!data || typeof data !== "object" || Array.isArray(data)) return;
        for (const key of Object.keys(networkPanelDefaults))
            if (Object.prototype.hasOwnProperty.call(data,key)) setNetworkPanelSetting(key,data[key],false);
    }
    // RAGE — RUSTIQ ADAPTIVE GLASS ENGINE. Old settings remain Standard UI.
    property bool glassmorphismEnabled: false
    property string rageMode: "adaptive"
    property string ragePalette: "obsidian"
    property string glassStyle: "frosted"
    property real glassOpacity: 0.44
    property bool glassBlurEnabled: true
    property int glassBlurRadius: 24 // Retained preference; backend must advertise independent strength.
    property real glassBorderOpacity: 0.16
    property int glassCornerRadius: 20
    property bool glassReflectionEnabled: true
    property bool glassShadowEnabled: true
    property real glassShadowIntensity: 0.14
    property real glassTintStrength: 0.10
    property bool glassPerformanceMode: false
    // Bar decoration is independent of palette, material and layout geometry.
    property bool barBackgroundEnabled: true
    property bool barOutlineEnabled: true
    property bool barSegmentBackgroundEnabled: true
    property bool barSegmentOutlineEnabled: true
    property bool barModuleBackgroundEnabled: true
    property bool barModuleOutlineEnabled: true
    property bool barGlassEnabled: true
    property bool barRailFillEnabled: false
    property real barOpacity: 1.0
    property int barCornerRadius: -1
    property int barSegmentRadius: -1
    property int barModuleRadius: -1
    property bool barCapsuleGeometry: false
    readonly property var barSurfaceDefaults: ({barBackgroundEnabled:true,barOutlineEnabled:true,
        barSegmentBackgroundEnabled:true,barSegmentOutlineEnabled:true,barModuleBackgroundEnabled:true,
        barModuleOutlineEnabled:true,barGlassEnabled:true,barRailFillEnabled:false,barOpacity:1.0,barCornerRadius:-1,
        barSegmentRadius:-1,barModuleRadius:-1,barCapsuleGeometry:false})
    function applyBarSurfaceSettings(data) {
        if (!data || typeof data !== "object" || Array.isArray(data)) return;
        for (const key of Object.keys(barSurfaceDefaults)) {
            const value=data[key];
            if (typeof barSurfaceDefaults[key] === "boolean") {
                if (typeof value === "boolean") root[key]=value;
            } else if (key === "barOpacity") {
                if (typeof value === "number" && Number.isFinite(value) && value>=.1 && value<=1) root[key]=value;
            } else if (Number.isInteger(value) && value>=-1 && value<=64) root[key]=value;
        }
    }
    function setBarSurfaceValue(key,value,persist) {
        if (!Object.prototype.hasOwnProperty.call(barSurfaceDefaults,key)) return false;
        if (typeof barSurfaceDefaults[key] === "boolean") {
            if (typeof value !== "boolean") return false;
        } else {
            if (typeof value !== "number" || !Number.isFinite(value)) return false;
            value=key === "barOpacity" ? Math.max(.1,Math.min(1,value)) : Math.round(Math.max(-1,Math.min(64,value)));
        }
        root[key]=value;
        if (persist !== false) save();
        return true;
    }
    function setBarSurfacePreset(preset) {
        const presets={original:[true,true,true,true,true,true],rail:[true,true,true,true,true,true],
            borderless:[true,false,true,false,true,false],floating:[false,false,true,false,false,false],
            outline:[false,true,false,false,false,false],naked:[false,false,false,false,false,false]};
        if (!Object.prototype.hasOwnProperty.call(presets,preset)) return false;
        const keys=["barBackgroundEnabled","barOutlineEnabled","barSegmentBackgroundEnabled",
            "barSegmentOutlineEnabled","barModuleBackgroundEnabled","barModuleOutlineEnabled"];
        keys.forEach((key,index) => root[key]=presets[preset][index]);
        if (preset === "rail" || preset === "borderless") barGlassEnabled=true;
        if (["original","rail","borderless","floating"].indexOf(preset)>=0)
            barRailFillEnabled=preset === "rail" || preset === "borderless";
        save();
        return true;
    }
    function resetBarSurfaceSettings() { applyBarSurfaceSettings(barSurfaceDefaults); save(); }
    readonly property var glassDefaults: ({glassmorphismEnabled:false, rageMode:"adaptive", ragePalette:"obsidian", glassStyle:"frosted", glassOpacity:0.44,
        glassBlurEnabled:true, glassBlurRadius:24, glassBorderOpacity:0.16, glassCornerRadius:20,
        glassReflectionEnabled:true, glassShadowEnabled:true, glassShadowIntensity:0.14,
        glassTintStrength:0.10, glassPerformanceMode:false})
    readonly property var glassLimits: ({glassOpacity:[0.15,1], glassBlurRadius:[0,64],
        glassBorderOpacity:[0,0.6], glassCornerRadius:[0,32], glassShadowIntensity:[0,0.6], glassTintStrength:[0,0.5]})
    function applyGlassSettings(data) {
        if (!data || typeof data !== "object" || Array.isArray(data)) return;
        for (const key of Object.keys(glassDefaults)) {
            const value = data[key];
            if (typeof glassDefaults[key] === "boolean") {
                if (typeof value === "boolean") root[key] = value;
            } else if (key === "rageMode") {
                if (["adaptive", "exclusive"].indexOf(value) >= 0) rageMode = value;
            } else if (key === "ragePalette") {
                if (["obsidian", "pearl", "pure-crystal", "graphite-frost"].indexOf(value) >= 0) ragePalette = value;
            } else if (key === "glassStyle") {
                if (["frosted", "crystal", "tinted"].indexOf(value) >= 0) glassStyle = value;
            } else if (typeof value === "number" && Number.isFinite(value)
                       && value >= glassLimits[key][0] && value <= glassLimits[key][1]) {
                if (key === "glassBlurRadius" || key === "glassCornerRadius") {
                    if (Number.isInteger(value)) root[key] = value;
                } else root[key] = value;
            }
        }
    }
    function setGlassValue(key, value, persist) {
        if (!Object.prototype.hasOwnProperty.call(glassDefaults, key)) return false;
        if (typeof glassDefaults[key] === "boolean") {
            if (typeof value !== "boolean") return false;
        } else if (key === "rageMode" || key === "ragePalette") {
            const choices = key === "rageMode" ? ["adaptive", "exclusive"] : ["obsidian", "pearl", "pure-crystal", "graphite-frost"];
            if (choices.indexOf(value) < 0) return false;
        } else if (key === "glassStyle") return setGlassPreset(value);
        else {
            if (typeof value !== "number" || !Number.isFinite(value)) return false;
            value = Math.max(glassLimits[key][0], Math.min(glassLimits[key][1], value));
            if (key === "glassBlurRadius" || key === "glassCornerRadius") value = Math.round(value);
        }
        root[key] = value;
        if (persist !== false) save();
        return true;
    }
    function setGlassPreset(style) {
        const presets = {
            frosted: {glassOpacity:0.44, glassTintStrength:0.10, glassBorderOpacity:0.16,
                glassShadowIntensity:0.14, glassReflectionEnabled:true, glassShadowEnabled:true},
            crystal: {glassOpacity:0.24, glassTintStrength:0.05, glassBorderOpacity:0.14,
                glassShadowIntensity:0.10, glassReflectionEnabled:true, glassShadowEnabled:true},
            tinted: {glassOpacity:0.50, glassTintStrength:0.30, glassBorderOpacity:0.16,
                glassShadowIntensity:0.14, glassReflectionEnabled:true, glassShadowEnabled:true}
        };
        if (!Object.prototype.hasOwnProperty.call(presets, style)) return false;
        applyGlassSettings(presets[style]);
        glassStyle = style;
        save();
        return true;
    }
    function resetGlassSettings() {
        const mode = rageMode, palette = ragePalette;
        applyGlassSettings(glassDefaults);
        rageMode = mode; ragePalette = palette;
        save();
    }
    property string animationStyle: "float"
    property string barAnimationStyle: "float"
    readonly property var animationStyles: ["float", "fade", "slide", "zoom", "spring"]
    function setAnimationStyle(key, value) {
        if (["animationStyle", "barAnimationStyle"].indexOf(key) < 0 || animationStyles.indexOf(value) < 0) return false;
        root[key] = value;
        save();
        return true;
    }
    property int barIconSize: 16
    function setBarIconSize(value, persist) {
        if (!Number.isFinite(value)) return false;
        barIconSize = Math.max(12, Math.min(32, Math.round(value)));
        if (persist !== false) save();
        return true;
    }
    // Desktop-level presets intentionally do not force privileged power profiles,
    // lock/idle settings, wallpaper services, or third-party theme agents.
    property string desktopProfile: "custom"
    property var desktopProfilePrevious: ({})
    readonly property var desktopProfileKeys: ["barMode", "showNotifications", "desktopSystem", "showDock", "uiDensity", "launcherLayoutMode"]
    readonly property var desktopProfilePresets: ({
        coding: {barMode:"compact", showNotifications:true, desktopSystem:true, showDock:true, uiDensity:"compact", launcherLayoutMode:"compact"},
        gaming: {barMode:"simple", showNotifications:false, desktopSystem:false, showDock:false, uiDensity:"compact", launcherLayoutMode:"compact"},
        battery: {barMode:"simple", showNotifications:true, desktopSystem:false, showDock:false, uiDensity:"compact", launcherLayoutMode:"clean-hover"},
        presentation: {barMode:"clean-compact", showNotifications:false, desktopSystem:false, showDock:false, uiDensity:"comfortable", launcherLayoutMode:"clean-hover"}
    })
    function applyDesktopProfile(profile) {
        if (!Object.prototype.hasOwnProperty.call(desktopProfilePresets, profile)) return false;
        const previous = {};
        for (const key of desktopProfileKeys) previous[key] = root[key];
        // Snapshot only when entering a preset from a non-preset state.
        if (desktopProfile === "custom" || !desktopProfilePrevious || !Object.keys(desktopProfilePrevious).length)
            desktopProfilePrevious = previous;
        const data = desktopProfilePresets[profile];
        for (const key of desktopProfileKeys) root[key] = data[key];
        desktopProfile = profile;
        save();
        return true;
    }
    function restoreDesktopProfile() {
        if (desktopProfile === "custom") return;
        if (desktopProfilePrevious && Object.keys(desktopProfilePrevious).length) {
            for (const key of desktopProfileKeys) {
                const value = desktopProfilePrevious[key];
                if (key === "barMode" && spacingModes.indexOf(value) < 0) continue;
                if (key === "uiDensity" && ["compact", "comfortable"].indexOf(value) < 0) continue;
                if (key === "launcherLayoutMode" && launcherEnums.launcherLayoutMode.indexOf(value) < 0) continue;
                if (typeof value === "boolean" || typeof value === "string") root[key] = value;
            }
        }
        desktopProfile = "custom";
        desktopProfilePrevious = ({});
        save();
    }
    property string wallpaperPath: ""
    property string wallpaperBackend: "swaybg" // Only fresh settings; saved backend is retained.
    property bool lowMemoryShellMode: false
    property bool osdEnabled: true
    property bool recordingIndicatorEnabled: true
    property bool recordingIndicatorBlink: true
    property string recordingIndicatorCorner: "top-right"
    property int recordingIndicatorSize: 12
    property int recordingIndicatorOffsetX: 24
    property int recordingIndicatorOffsetY: 64
    readonly property var recordingIndicatorCorners: ["top-right", "top-left", "bottom-right", "bottom-left"]
    function setRecordingIndicatorCorner(corner) {
        if (recordingIndicatorCorners.indexOf(corner) < 0) return false;
        recordingIndicatorCorner = corner;
        save();
        return true;
    }
    function updateRecordingIndicator(key, value, persist) {
        const limits = {
            recordingIndicatorSize: [8, 24],
            recordingIndicatorOffsetX: [0, 200],
            recordingIndicatorOffsetY: [0, 200]
        };
        if (!Object.prototype.hasOwnProperty.call(limits, key) || !Number.isFinite(value)) return false;
        root[key] = Math.max(limits[key][0], Math.min(limits[key][1], Math.round(value)));
        if (persist !== false) save();
        return true;
    }
    property bool wallpaperAutoRestore: false
    property bool wallpaperReplaceOnRestore: false
    property string wallpaperFitMode: "fill"
    // RusticQ Native Lock uses WlSessionLock/PAM; the original Omarchy lock/idle
    // configuration stays untouched. Solid is safest for privacy by default.
    property string lockscreenBackground: "solid" // solid | wallpaper
    property bool showNotifications: true
    property bool showLauncher: true
    property bool showRusticQIcon: true
    // Launcher Studio: one style selector, one validated persistent contract.
    property bool launcherUseStyleDefaults: true
    property string launcherLayoutMode: "spotlight"
    property int launcherWidth: 660
    property int launcherHeight: 520
    property int launcherIconSize: 30
    property int launcherRowHeight: 48
    property int launcherFavoriteColumns: 3
    property string launcherPosition: "auto"
    property int launcherOffsetX: 0
    property int launcherOffsetY: 0
    property real launcherCustomX: 0.5
    property real launcherCustomY: 0.2
    property string launcherBackdropMode: "auto"
    property real launcherBackdropOpacity: 0.25
    property bool launcherGlassmorphismEnabled: true
    property string launcherMaterialMode: "inherit"
    property real launcherOpacity: -1.0
    property int launcherCornerRadius: -1
    property bool launcherBackgroundEnabled: true
    property bool launcherOutlineEnabled: true
    property bool launcherHighlightsEnabled: true
    property bool launcherShowBranding: false
    property bool launcherShowCategories: true
    property bool launcherShowFavorites: true
    property bool launcherShowRecent: true
    property bool launcherShowShortcutHints: true
    property bool launcherShowPreview: false
    property bool launcherShowIcons: true
    property int launcherGridColumns: 6
    property int launcherGridIconSize: 64
    property int launcherResultSpacing: 6
    property int launcherPadding: 16
    property int launcherSearchHeight: 68
    property int launcherSearchFontSize: 22
    property string launcherAnimationStyle: "inherit"
    property int detachedLauncherGap: 10
    property int detachedLauncherInputHeight: 64
    property int detachedLauncherInputFontSize: 21
    property int detachedLauncherInputRadius: 18
    property int detachedLauncherResultsRadius: 16
    property string detachedLauncherPlaceholder: "Search applications, files, notes\u2026"
    property bool detachedLauncherShowIcon: true
    property bool detachedLauncherShowHint: true
    property string detachedLauncherResultMode: "adaptive"
    property string detachedLauncherAppLayout: "grid"
    property string detachedLauncherResultWidthMode: "match-input"
    property int detachedLauncherResultsWidth: 660
    property string detachedLauncherExpansionDirection: "auto"
    property string detachedLauncherResultAlignment: "center"
    property int detachedLauncherMaxResults: 24
    property bool detachedLauncherShowEmptyResults: false
    property bool detachedLauncherInputGlassEnabled: true
    property bool detachedLauncherResultsGlassEnabled: true
    property bool detachedLauncherInputBackgroundEnabled: true
    property bool detachedLauncherResultsBackgroundEnabled: true
    property bool detachedLauncherInputOutlineEnabled: true
    property bool detachedLauncherResultsOutlineEnabled: true
    property bool detachedLauncherInputInheritMaterial: true
    property bool detachedLauncherResultsInheritMaterial: true
    property real detachedLauncherInputOpacity: 0.4
    property real detachedLauncherResultsOpacity: 0.5
    property bool detachedLauncherInputHighlights: true
    property bool detachedLauncherResultsHighlights: true
    property real detachedLauncherInputShadowIntensity: 0.14
    property real detachedLauncherResultsShadowIntensity: 0.14
    readonly property var launcherAppearanceDefaults: ({"launcherLayoutMode":"spotlight","launcherWidth":660,"launcherHeight":520,"launcherIconSize":30,"launcherRowHeight":48,"launcherFavoriteColumns":3,"launcherPosition":"auto","launcherOffsetX":0,"launcherOffsetY":0,"launcherCustomX":0.5,"launcherCustomY":0.2,"launcherBackdropMode":"auto","launcherBackdropOpacity":0.25,"launcherGlassmorphismEnabled":true,"launcherMaterialMode":"inherit","launcherOpacity":-1.0,"launcherCornerRadius":-1,"launcherBackgroundEnabled":true,"launcherOutlineEnabled":true,"launcherHighlightsEnabled":true,"launcherShowBranding":false,"launcherShowCategories":true,"launcherShowFavorites":true,"launcherShowRecent":true,"launcherShowShortcutHints":true,"launcherShowPreview":false,"launcherShowIcons":true,"launcherGridColumns":6,"launcherGridIconSize":64,"launcherResultSpacing":6,"launcherPadding":16,"launcherSearchHeight":68,"launcherSearchFontSize":22,"launcherAnimationStyle":"inherit","detachedLauncherGap":10,"detachedLauncherInputHeight":64,"detachedLauncherInputFontSize":21,"detachedLauncherInputRadius":18,"detachedLauncherResultsRadius":16,"detachedLauncherPlaceholder":"Search applications, files, notes\u2026","detachedLauncherShowIcon":true,"detachedLauncherShowHint":true,"detachedLauncherResultMode":"adaptive","detachedLauncherAppLayout":"grid","detachedLauncherResultWidthMode":"match-input","detachedLauncherResultsWidth":660,"detachedLauncherExpansionDirection":"auto","detachedLauncherResultAlignment":"center","detachedLauncherMaxResults":24,"detachedLauncherShowEmptyResults":false,"detachedLauncherInputGlassEnabled":true,"detachedLauncherResultsGlassEnabled":true,"detachedLauncherInputBackgroundEnabled":true,"detachedLauncherResultsBackgroundEnabled":true,"detachedLauncherInputOutlineEnabled":true,"detachedLauncherResultsOutlineEnabled":true,"detachedLauncherInputInheritMaterial":true,"detachedLauncherResultsInheritMaterial":true,"detachedLauncherInputOpacity":0.4,"detachedLauncherResultsOpacity":0.5,"detachedLauncherInputHighlights":true,"detachedLauncherResultsHighlights":true,"detachedLauncherInputShadowIntensity":0.14,"detachedLauncherResultsShadowIntensity":0.14,"launcherUseStyleDefaults":true})
    readonly property var launcherEnums: ({"launcherLayoutMode":["compact","clean-hover","spotlight","raycast","launchpad","fluent","minimal","classic","overview","command","detached"],"launcherPosition":["auto","center","upper-center","lower-center","top-left","top-right","bottom-left","bottom-right","follow-bar","custom"],"launcherBackdropMode":["auto","none","dim","blur","dim-blur","focus"],"launcherMaterialMode":["inherit","solid"],"launcherAnimationStyle":["inherit","none","fade","scale","slide","float","spring"],"detachedLauncherResultMode":["list","grid","adaptive"],"detachedLauncherAppLayout":["list","grid"],"detachedLauncherResultWidthMode":["match-input","custom"],"detachedLauncherExpansionDirection":["auto","down","up"],"detachedLauncherResultAlignment":["left","center","right"]})
    readonly property var launcherLimits: ({"launcherWidth":[320,1920],"launcherHeight":[120,1200],"launcherIconSize":[16,96],"launcherRowHeight":[28,96],"launcherFavoriteColumns":[2,8],"launcherOffsetX":[-1000,1000],"launcherOffsetY":[-1000,1000],"launcherCustomX":[0,1],"launcherCustomY":[0,1],"launcherBackdropOpacity":[0,0.85],"launcherOpacity":[-1,1],"launcherCornerRadius":[-1,48],"launcherGridColumns":[2,12],"launcherGridIconSize":[32,128],"launcherResultSpacing":[0,24],"launcherPadding":[4,40],"launcherSearchHeight":[40,100],"launcherSearchFontSize":[12,32],"detachedLauncherGap":[0,32],"detachedLauncherInputHeight":[44,96],"detachedLauncherInputFontSize":[14,32],"detachedLauncherInputRadius":[0,48],"detachedLauncherResultsRadius":[0,48],"detachedLauncherResultsWidth":[320,1600],"detachedLauncherMaxResults":[1,100],"detachedLauncherInputOpacity":[0.15,1],"detachedLauncherResultsOpacity":[0.15,1],"detachedLauncherInputShadowIntensity":[0,0.6],"detachedLauncherResultsShadowIntensity":[0,0.6]})
    function validLauncherValue(key,value) {
        if (!Object.prototype.hasOwnProperty.call(launcherAppearanceDefaults,key)) return false;
        const initial=launcherAppearanceDefaults[key];
        if (typeof initial === "boolean") return typeof value === "boolean";
        if (launcherEnums[key]) return typeof value === "string" && launcherEnums[key].indexOf(value)>=0;
        if (typeof initial === "string") return typeof value === "string" && value.length<=160 && !/[\x00-\x1f]/.test(value);
        const bounds=launcherLimits[key];
        if (typeof value!=="number" || !Number.isFinite(value) || !bounds || value<bounds[0] || value>bounds[1]) return false;
        if (key === "launcherOpacity" && value<0 && value!==-1) return false;
        return ["launcherCustomX","launcherCustomY","launcherBackdropOpacity","launcherOpacity","detachedLauncherInputOpacity","detachedLauncherResultsOpacity","detachedLauncherInputShadowIntensity","detachedLauncherResultsShadowIntensity"].indexOf(key)>=0 || Number.isInteger(value);
    }
    function applyLauncherSettings(data) {
        if (!data || typeof data!=="object" || Array.isArray(data)) return;
        for(const key of Object.keys(launcherAppearanceDefaults)) if(validLauncherValue(key,data[key])) root[key]=data[key];
    }
    function loadLauncherSettings(data) {
        applyLauncherSettings(launcherAppearanceDefaults);
        if (!data || typeof data!=="object" || Array.isArray(data)) return;
        // Existing installations retain their legacy geometry, including files
        // written before the layout selector or size controls were introduced.
        if (Object.keys(data).length && data.launcherUseStyleDefaults === undefined
                && (data.launcherLayoutMode === undefined || ["compact","clean-hover"].indexOf(data.launcherLayoutMode)>=0)) {
            launcherLayoutMode="compact";
            launcherHeight=605;
            launcherRowHeight=56;
        }
        applyLauncherSettings(data);
    }
    function setLauncherValue(key,value,persist) {
        if (!Object.prototype.hasOwnProperty.call(launcherAppearanceDefaults,key)) return false;
        if (typeof value === "number" && Number.isFinite(value) && launcherLimits[key]) {
            const limits=launcherLimits[key];value=Math.max(limits[0],Math.min(limits[1],value));
            if (Number.isInteger(launcherAppearanceDefaults[key]) && ["launcherCustomX","launcherCustomY","launcherBackdropOpacity","launcherOpacity"].indexOf(key)<0) value=Math.round(value);
        }
        if (!validLauncherValue(key,value)) return false;
        root[key]=value;
        if (["launcherWidth","launcherHeight","launcherSearchHeight","launcherSearchFontSize"].indexOf(key)>=0) launcherUseStyleDefaults=false;
        if (persist!==false) save();
        return true;
    }
    function launcherSnapshot() {
        const data={};for(const key of Object.keys(launcherAppearanceDefaults)) data[key]=root[key];return data;
    }
    function updateLauncherSize(key,value,persist) { return setLauncherValue(key,value,persist); }
    function resetLauncherSize() {
        for(const key of ["launcherWidth","launcherHeight","launcherIconSize","launcherRowHeight","launcherFavoriteColumns"]) root[key]=launcherAppearanceDefaults[key];
        if (["compact","clean-hover"].indexOf(launcherLayoutMode)>=0) { launcherHeight=605;launcherRowHeight=56; }
        launcherUseStyleDefaults=true;
        save();
    }
    function resetLauncherAppearance() {
        const style=launcherLayoutMode;applyLauncherSettings(launcherAppearanceDefaults);launcherLayoutMode=style;save();
    }
    function resetDetachedLauncherAppearance() {
        for(const key of Object.keys(launcherAppearanceDefaults)) if(key.startsWith("detachedLauncher")) root[key]=launcherAppearanceDefaults[key];save();
    }

    property bool showTaskView: true
    property bool desktopCalendar: false
    property bool desktopSystem: false
    property bool desktopClock: false
    property bool desktopMedia: false
    property bool desktopWeather: false
    property bool desktopNotes: false
    property bool desktopKanban: false
    property bool desktopRandomImage: false
    property string widgetImageFolder: "" // Empty: user Pictures folder, nothing fetched online.
    property int widgetImageRotateSeconds: 0 // 0 = manual only; 60 / 300 / 900 allowed
    property bool desktopConnectivity: false
    // Per-monitor widget positions in normalized available screen space (0..1).
    // Opt-in per-workspace visibility. Widget windows remain on the Bottom
    // layer; they are hidden on every nonselected workspace of their monitor.
    // Default WS1 for freshly activated interactive widgets.
    property var widgetWorkspaceScopes: ({notes:[1], kanban:[1], randomImage:[1]})
    function widgetAllowedOnWorkspace(kind, workspace) {
        if (!Number.isInteger(workspace) || workspace < 1) return false;
        const scope = widgetWorkspaceScopes[kind];
        return Array.isArray(scope) && scope.indexOf(workspace) !== -1;
    }
    function setWidgetWorkspace(kind, workspace, show) {
        if (["notes", "kanban", "randomImage"].indexOf(kind) < 0 ||
            !Number.isInteger(workspace) || workspace < 1 || workspace > 10) return;
        const next = Object.assign({}, widgetWorkspaceScopes);
        const arr = Array.isArray(next[kind]) ? next[kind].slice() : [1];
        const at = arr.indexOf(workspace);
        if (show && at < 0) arr.push(workspace);
        if (!show && at >= 0) arr.splice(at, 1);
        next[kind] = arr.sort((a,b)=>a-b);
        widgetWorkspaceScopes = next;
        save();
    }
    // A plain-text scratchpad per monitor/workspace, independent of the task
    // board backend. Stored locally with the normal existing settings file.
    property var workspaceNotes: ({})
    function workspaceNoteKey(monitor, workspace) {
        return String(monitor || "default") + ":" + String(workspace);
    }
    function workspaceNote(monitor, workspace) {
        return workspaceNotes[workspaceNoteKey(monitor, workspace)] || "";
    }
    function setWorkspaceNote(monitor, workspace, text) {
        if (!Number.isInteger(workspace) || workspace < 1 || workspace > 10 ||
            typeof text !== "string") return;
        const key = workspaceNoteKey(monitor, workspace);
        const all = Object.assign({}, workspaceNotes);
        all[key] = text.slice(0, 30000);
        workspaceNotes = all;
        save();
    }
    property var widgetSizes: ({})
    function widgetSize(kind, monitor, workspace) {
        return widgetSizes[widgetKey(kind, monitor) + ":" + String(workspace)] || null;
    }
    function setWidgetSize(kind, monitor, workspace, width, height) {
        if (["notes", "kanban", "randomImage"].indexOf(kind) < 0 ||
            !Number.isInteger(workspace) || workspace < 1 || workspace > 10 ||
            !Number.isFinite(width) || !Number.isFinite(height)) return;
        const all = Object.assign({}, widgetSizes);
        all[widgetKey(kind, monitor) + ":" + String(workspace)] = {
            width: Math.round(Math.max(250, Math.min(1050, width))),
            height: Math.round(Math.max(145, Math.min(800, height)))
        };
        widgetSizes = all;
        save();
    }
    property var widgetPositions: ({})
    function widgetKey(kind, monitor) { return String(monitor || "default") + ":" + kind; }
    function widgetPosition(kind, monitor, workspace) {
        const base = widgetKey(kind, monitor);
        if (Number.isInteger(workspace) && workspace > 0 && ["notes","kanban","randomImage"].indexOf(kind) >= 0)
            return widgetPositions[base + ":" + String(workspace)] || widgetPositions[base] || null;
        return widgetPositions[base] || null;
    }
    function setWidgetPosition(kind, monitor, x, y, workspace) {
        if (["clock", "calendar", "system", "media", "weather", "connectivity", "notes", "kanban", "randomImage"].indexOf(kind) < 0) return;
        if (!Number.isFinite(x) || !Number.isFinite(y)) return;
        const copy = Object.assign({}, widgetPositions);
        const perWorkspace = Number.isInteger(workspace) && workspace > 0 && ["notes","kanban","randomImage"].indexOf(kind) >= 0;
        const key = widgetKey(kind, monitor) + (perWorkspace ? ":" + String(workspace) : "");
        copy[key] = {x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y))};
        widgetPositions = copy;
        save();
    }
    function resetWidgetPositions() { widgetPositions = ({}); save(); }
    property bool showDock: false
    property bool dockFiles: true
    property bool dockBrowser: true
    property bool dockSettings: true
    property bool dockTaskView: true
    property bool dockAI: true
    property bool dockRunningApps: false
    // User-controlled Quick Control card order, stored independently of layout modes.
    readonly property var defaultQuickOrder: ["wifi", "bluetooth", "battery", "system", "notifications"]
    property var quickControlOrder: ["wifi", "bluetooth", "battery", "system", "notifications"]
    function validQuickOrder(input) {
        if (!Array.isArray(input) || input.length !== defaultQuickOrder.length) return false;
        return input.every((v, i) => defaultQuickOrder.indexOf(v) >= 0 && input.indexOf(v) === i);
    }
    function moveQuickCard(kind, beforeIndex) {
        const order = quickControlOrder.slice();
        const from = order.indexOf(kind);
        const to = Math.max(0, Math.min(order.length - 1, Math.floor(beforeIndex)));
        if (from < 0 || from === to) return;
        order.splice(from, 1);
        order.splice(to, 0, kind);
        quickControlOrder = order;
        save();
    }
    function resetQuickOrder() { quickControlOrder = defaultQuickOrder.slice(); save(); }
    property bool dockAutoHide: true
    property bool showMenuBar: false // Optional RusticQ contextual menu; off by default
    // Edit, View and Share remain the default menu sections when enabled.
    property bool showMenuEdit: true
    property bool showMenuView: true
    property bool showMenuShare: true
    property bool showMenuFile: false
    property bool showMenuShell: false
    property bool showMenuTools: false
    // Clean Compact: optional detail labels only for the right-hand group.
    // Battery and volume values are always retained.
    property bool cleanRightDetails: true // RC2 migration compatibility
    // clean-compact labels: icons, details, or reveal all on group hover
    property string cleanRightMode: "details"
    // Per-mode edge margins. Empty means keep the original mode defaults.
    property var marginOverrides: ({})
    property var barPaddingOverrides: ({})
    readonly property var barPaddingDefaults: ({
        compact: {horizontal: {top: 2, bottom: 2, left: 4, right: 4}, vertical: {top: 8, bottom: 8, left: 10, right: 10}},
        "clean-compact": {horizontal: {top: 2, bottom: 2, left: 4, right: 4}, vertical: {top: 8, bottom: 8, left: 6, right: 6}},
        separated: {horizontal: {top: 0, bottom: 0, left: 4, right: 4}, vertical: {top: 8, bottom: 8, left: 10, right: 10}},
        professional: {horizontal: {top: 6, bottom: 6, left: 14, right: 14}, vertical: {top: 12, bottom: 12, left: 14, right: 14}},
        simple: {horizontal: {top: 3, bottom: 3, left: 4, right: 4}, vertical: {top: 8, bottom: 8, left: 8, right: 8}}
    })
    function paddingFor(edge) {
        if (["top", "bottom", "left", "right"].indexOf(edge) < 0) return 0;
        const value = (barPaddingOverrides[barMode] || {})[edge];
        if (Number.isInteger(value)) return value;
        const orientation = barPosition === "left" || barPosition === "right" ? "vertical" : "horizontal";
        return barPaddingDefaults[barMode][orientation][edge];
    }
    function setBarPadding(edge, value, persist) {
        if (["top", "bottom", "left", "right"].indexOf(edge) < 0 || !Number.isFinite(value)) return false;
        const all = Object.assign({}, barPaddingOverrides);
        const current = Object.assign({}, all[barMode] || {});
        current[edge] = Math.max(0, Math.min(32, Math.round(value)));
        all[barMode] = current;
        barPaddingOverrides = all;
        if (persist !== false) save();
        return true;
    }
    function resetBarPadding() {
        const all = Object.assign({}, barPaddingOverrides);
        delete all[barMode];
        barPaddingOverrides = all;
        save();
    }
    function validateBarPadding(raw) {
        const clean = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return clean;
        for (const mode of spacingModes) {
            const values = raw[mode];
            if (!values || typeof values !== "object" || Array.isArray(values)) continue;
            const record = {};
            for (const edge of ["top", "bottom", "left", "right"])
                if (Number.isInteger(values[edge]) && values[edge] >= 0 && values[edge] <= 32)
                    record[edge] = values[edge];
            clean[mode] = record;
        }
        return clean;
    }
    function marginFor(edge, fallback) {
        const mode = marginOverrides[barMode] || {};
        return typeof mode[edge] === "number" ? mode[edge] : fallback;
    }
    function setBarMargin(edge, value, persist) {
        if (["top", "bottom", "left", "right"].indexOf(edge) === -1) return;
        const all = Object.assign({}, marginOverrides);
        const current = Object.assign({}, all[barMode] || {});
        current[edge] = Math.max(0, Math.min(32, Math.round(value)));
        all[barMode] = current;
        marginOverrides = all; // replace object to notify QML bindings
        if (persist !== false) save();
    }
    function resetBarMargins() {
        const all = Object.assign({}, marginOverrides);
        delete all[barMode];
        marginOverrides = all;
        save();
    }
    // RC2: persistent alignment for every bar item, not only optional indicators.
    // On vertical bars Left / Center / Right map to top / middle / bottom.
    readonly property var barIconKeys: ["rusticq", "arch", "launcher", "menu", "workspaces", "weather", "time", "date",
        "bluetooth", "wifi", "battery", "audio", "notifications", "barToggle", "task", "quickModes", "quickControl", "mic", "down", "up"]
    readonly property var defaultBarPlacements: ({
        rusticq:"left", arch:"left", launcher:"left", menu:"left", workspaces:"left",
        weather:"right", time:"right", date:"right", bluetooth:"right", wifi:"right",
        battery:"right", audio:"right", notifications:"right", barToggle:"right", task:"right", quickModes:"right", quickControl:"right",
        mic:"right", down:"right", up:"right"
    })
    // v5: independent layout profiles. Legacy barIconPlacements is read ONLY for migration.
    property var barIconPlacements: ({})
    property var barIconPlacementsByMode: ({})
    // Optional order override for each layout; existing profiles retain the RC4 order.
    property var barIconOrderByMode: ({})
    function validateBarIconOrder(order) {
        if (!Array.isArray(order)) return false;
        // Migrate both the old pre-bell layout and this release's new bar toggle
        // without resetting a user's draggable icon order or per-mode placement.
        const missing = barIconKeys.filter(key => order.indexOf(key) < 0);
        if (missing.some(key => key !== "notifications" && key !== "barToggle")) return false;
        if (order.length + missing.length !== barIconKeys.length) return false;
        return order.every((key, index) => barIconKeys.indexOf(key) >= 0 && order.indexOf(key) === index);
    }
    function normalizeBarOrder(order) {
        if (!validateBarIconOrder(order)) return barIconKeys.slice();
        const next = order.slice();
        if (next.indexOf("notifications") < 0) {
            const after = next.indexOf("audio");
            next.splice(after < 0 ? next.length : after + 1, 0, "notifications");
        }
        if (next.indexOf("barToggle") < 0) {
            const after = next.indexOf("notifications");
            next.splice(after < 0 ? next.length : after + 1, 0, "barToggle");
        }
        return next;
    }
    function validateBarIconOrders(data) {
        const clean = {};
        if (!data || typeof data !== "object" || Array.isArray(data)) return clean;
        for (const mode of spacingModes)
            if (validateBarIconOrder(data[mode])) clean[mode] = normalizeBarOrder(data[mode]);
        return clean;
    }
    function barOrder(modeName) {
        const saved = barIconOrderByMode[modeName || barMode];
        return normalizeBarOrder(saved);
    }
    // Swap positions of two tiles, including their Left/Center/Right zones.
    // A dragged tile occupies the target's old slot, and vice versa.
    function swapBarIcons(source, target) {
        if (source === target || barIconKeys.indexOf(source) < 0 ||
            barIconKeys.indexOf(target) < 0) return false;
        const fromZone = placementFor(source), toZone = placementFor(target);
        const order = barOrder().slice();
        const a = order.indexOf(source), b = order.indexOf(target);
        if (a < 0 || b < 0) return false;
        // Exchanging slots also exchanges zones. Keep zone-specific spacing
        // settings attached to the icon when moving between zones.
        if (fromZone !== toZone) {
            transferIconSpacing(source, fromZone, toZone, barMode);
            transferIconSpacing(target, toZone, fromZone, barMode);
            const allPlacements = Object.assign({}, barIconPlacementsByMode);
            const placements = Object.assign({}, allPlacements[barMode] || {});
            placements[source] = toZone;
            placements[target] = fromZone;
            allPlacements[barMode] = placements;
            barIconPlacementsByMode = allPlacements;
        }
        order[a] = target;
        order[b] = source;
        const allOrders = Object.assign({}, barIconOrderByMode);
        allOrders[barMode] = order;
        barIconOrderByMode = allOrders;
        if (fromZone !== toZone) {
            barIconMoved(source, toZone);
            barIconMoved(target, fromZone);
        }
        save();
        return true;
    }
    // Drop a tile before another tile or at the end of a zone. Persist order
    // separately from zone placement so rearranging cannot disable any icon.
    function moveBarIcon(key, zone, beforeKey) {
        if (barIconKeys.indexOf(key) < 0 || spacingZones.indexOf(zone) < 0) return false;
        if (beforeKey && (barIconKeys.indexOf(beforeKey) < 0 || beforeKey === key || placementFor(beforeKey) !== zone)) return false;
        const fromZone = placementFor(key);
        if (fromZone !== zone) {
            transferIconSpacing(key, fromZone, zone, barMode);
            const placements = Object.assign({}, barIconPlacementsByMode);
            const current = Object.assign({}, placements[barMode] || {});
            current[key] = zone;
            placements[barMode] = current;
            barIconPlacementsByMode = placements;
        }
        const order = barOrder().slice();
        order.splice(order.indexOf(key), 1);
        const at = beforeKey ? order.indexOf(beforeKey) : (() => {
            // Insert immediately after the final icon in the destination zone,
            // without affecting the relative order in any other zone.
            let last = -1;
            for (let i = 0; i < order.length; i++)
                if (placementFor(order[i]) === zone) last = i;
            return last + 1;
        })();
        order.splice(at, 0, key);
        const all = Object.assign({}, barIconOrderByMode);
        all[barMode] = order;
        barIconOrderByMode = all;
        if (fromZone !== zone) barIconMoved(key, zone);
        save();
        return true;
    }
    signal barIconMoved(string key, string zone)
    function placementFor(key) {
        if (barIconKeys.indexOf(key) < 0) return "right";
        const value = (barIconPlacementsByMode[barMode] || {})[key];
        return ["left", "center", "right"].indexOf(value) !== -1 ? value : defaultBarPlacements[key];
    }
    function transferIconSpacing(key, fromZone, toZone, onlyMode) {
        if (fromZone === toZone) return;
        const all = Object.assign({}, barSpacingOverrides);
        let changed = false;
        // Never move a different layout mode's spacing when relocating an icon.
        for (const modeName of (onlyMode ? [onlyMode] : spacingModes)) {
            const mode = Object.assign({}, all[modeName] || {});
            const from = Object.assign({}, mode[fromZone] || {});
            const fromItems = Object.assign({}, from.items || {});
            if (!Object.prototype.hasOwnProperty.call(fromItems, key)) continue;
            const to = Object.assign({}, mode[toZone] || {});
            const toItems = Object.assign({}, to.items || {});
            toItems[key] = fromItems[key];
            delete fromItems[key];
            changed = true;
            from.items = fromItems;
            to.items = toItems;
            mode[fromZone] = from;
            mode[toZone] = to;
            all[modeName] = mode;
        }
        if (changed) barSpacingOverrides = all;
    }
    function setIconPlacement(key, zone) {
        if (barIconKeys.indexOf(key) < 0 || ["left", "center", "right"].indexOf(zone) < 0) return;
        const fromZone = placementFor(key);
        if (fromZone === zone) return;
        transferIconSpacing(key, fromZone, zone, barMode);
        const all = Object.assign({}, barIconPlacementsByMode);
        const current = Object.assign({}, all[barMode] || {});
        current[key] = zone;
        all[barMode] = current;
        barIconPlacementsByMode = all;
        barIconMoved(key, zone);
        save();
    }
    function resetIconPlacements() {
        for (const key of barIconKeys)
            transferIconSpacing(key, placementFor(key), defaultBarPlacements[key], barMode);
        const all = Object.assign({}, barIconPlacementsByMode);
        delete all[barMode];
        barIconPlacementsByMode = all;
        const orders = Object.assign({}, barIconOrderByMode);
        delete orders[barMode];
        barIconOrderByMode = orders;
        save();
    }
    function validateIconPlacements(raw) {
        const clean = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return clean;
        for (const key of barIconKeys)
            if (["left", "center", "right"].indexOf(raw[key]) >= 0) clean[key] = raw[key];
        return clean;
    }
    function validateModePlacements(raw) {
        const clean = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return clean;
        for (const mode of spacingModes)
            if (raw[mode] && typeof raw[mode] === "object" && !Array.isArray(raw[mode]))
                clean[mode] = validateIconPlacements(raw[mode]);
        return clean;
    }
    // Manual spacing: three zones, independent for every bar layout mode.
    // All items share ONE registry; a relocated item is editable in its new zone.
    readonly property var spacingModes: ["compact", "clean-compact", "separated", "professional", "simple"]
    readonly property var spacingZones: ["left", "center", "right"]
    property var barSpacingOverrides: ({})
    function validSpacingItem(zone, key) {
        return spacingZones.indexOf(zone) >= 0 && barIconKeys.indexOf(key) >= 0;
    }
    function iconsInZone(zone) {
        return barOrder().filter(key => placementFor(key) === zone);
    }
    function spacingGroup(side, fallback) {
        const sideSettings = (barSpacingOverrides[barMode] || {})[side] || {};
        return Number.isInteger(sideSettings.gap) ? sideSettings.gap : fallback;
    }
    function spacingIcon(side, key, edge) {
        if (!validSpacingItem(side, key) || ["before", "after"].indexOf(edge) === -1) return 0;
        const record = (((barSpacingOverrides[barMode] || {})[side] || {}).items || {})[key] || {};
        return Number.isInteger(record[edge]) ? record[edge] : 0;
    }
    function setGroupSpacing(side, value, persist) {
        if (spacingZones.indexOf(side) < 0 || !Number.isFinite(value)) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        const group = Object.assign({}, mode[side] || {});
        group.gap = Math.max(0, Math.min(16, Math.round(value)));
        mode[side] = group; all[barMode] = mode; barSpacingOverrides = all;
        if (persist !== false) save();
    }
    function setIconSpacing(side, key, edge, value, persist) {
        if (!validSpacingItem(side, key) || ["before", "after"].indexOf(edge) < 0 || !Number.isFinite(value)) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        const group = Object.assign({}, mode[side] || {});
        const items = Object.assign({}, group.items || {});
        const item = Object.assign({}, items[key] || {});
        item[edge] = Math.max(0, Math.min(24, Math.round(value)));
        items[key] = item; group.items = items; mode[side] = group;
        all[barMode] = mode; barSpacingOverrides = all;
        if (persist !== false) save();
    }
    function resetIconSpacing(side, key) {
        if (!validSpacingItem(side, key)) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        const group = Object.assign({}, mode[side] || {});
        const items = Object.assign({}, group.items || {});
        delete items[key]; group.items = items; mode[side] = group;
        all[barMode] = mode; barSpacingOverrides = all; save();
    }
    function resetSideSpacing(side) {
        if (spacingZones.indexOf(side) < 0) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        delete mode[side]; all[barMode] = mode; barSpacingOverrides = all; save();
    }
    function validateSpacingOverrides(raw) {
        const result = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return result;
        for (const mode of spacingModes) {
            const sourceMode = raw[mode];
            if (!sourceMode || typeof sourceMode !== "object" || Array.isArray(sourceMode)) continue;
            const parsedMode = {};
            for (const side of spacingZones) {
                const source = sourceMode[side];
                if (!source || typeof source !== "object" || Array.isArray(source)) continue;
                const parsed = { items: {} };
                if (Number.isInteger(source.gap) && source.gap >= 0 && source.gap <= 16) parsed.gap = source.gap;
                for (const key of barIconKeys) {
                    const item = (source.items || {})[key];
                    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
                    const value = {};
                    for (const edge of ["before", "after"])
                        if (Number.isInteger(item[edge]) && item[edge] >= 0 && item[edge] <= 24) value[edge] = item[edge];
                    if (Object.keys(value).length > 0) parsed.items[key] = value;
                }
                parsedMode[side] = parsed;
            }
            result[mode] = parsedMode;
        }
        return result;
    }
    // v5: display preferences are scoped to the selected BAR LAYOUT, not the device.
    // Keep global legacy show* properties so old settings files can migrate safely.
    readonly property var barVisibilityKeys: [
        "showRusticQIcon", "showLauncher", "showArch", "showWorkspaces", "showQuickControl", "showNotificationIcon", "showBarToggleIcon",
        "showTaskView", "showWeather", "showTime", "showDate", "showWifi", "showBluetooth",
        "showBattery", "showAudio", "showMicrophoneStatus", "showDownloadSpeed",
        "showUploadSpeed", "showIndicators", "showMenuBar", "showMenuFile", "showMenuEdit",
        "showMenuView", "showMenuShare", "showMenuShell", "showMenuTools", "showQuickModes",
        "showKeepAwake", "showSilent", "showGamingMode", "showNightMode", "showMicMute"
    ]
    // The simple mode starts lean for fresh installations. Existing RC4 users keep
    // their current configuration through a one-time legacy migration below.
    readonly property var simpleHiddenIcons: [
        "showArch", "showTaskView", "showWeather", "showDate", "showBluetooth",
        "showMenuBar", "showMenuFile", "showMenuEdit", "showMenuView", "showMenuShare",
        "showMenuShell", "showMenuTools", "showQuickModes", "showMicrophoneStatus",
        "showDownloadSpeed", "showUploadSpeed"
    ]
    property var barIconVisibilityProfiles: ({})
    function modeIconVisible(key, modeName) {
        if (barVisibilityKeys.indexOf(key) < 0) return root[key] === true;
        const mode = modeName || barMode;
        const record = barIconVisibilityProfiles[mode] || {};
        if (typeof record[key] === "boolean") return record[key];
        if (mode === "simple" && simpleHiddenIcons.indexOf(key) >= 0) return false;
        return root[key] === true;
    }
    function setModeIconVisible(key, visible) {
        if (barVisibilityKeys.indexOf(key) < 0 || typeof visible !== "boolean") return;
        const all = Object.assign({}, barIconVisibilityProfiles);
        const record = Object.assign({}, all[barMode] || {});
        record[key] = visible;
        all[barMode] = record;
        barIconVisibilityProfiles = all;
        save();
    }
    function validateVisibilityProfiles(raw) {
        const clean = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return clean;
        for (const mode of spacingModes) {
            const values = raw[mode];
            if (!values || typeof values !== "object" || Array.isArray(values)) continue;
            const record = {};
            for (const key of barVisibilityKeys)
                if (typeof values[key] === "boolean") record[key] = values[key];
            clean[mode] = record;
        }
        return clean;
    }
    function resetModeVisibility() {
        const all = Object.assign({}, barIconVisibilityProfiles);
        delete all[barMode];
        barIconVisibilityProfiles = all;
        save();
    }
    function useMinimalModePreset() {
        const keep = ["showRusticQIcon", "showLauncher", "showWorkspaces", "showTime",
            "showWifi", "showBattery", "showAudio", "showQuickControl", "showIndicators"];
        const record = {};
        for (const key of barVisibilityKeys)
            record[key] = keep.indexOf(key) >= 0;
        const all = Object.assign({}, barIconVisibilityProfiles);
        all[barMode] = record;
        barIconVisibilityProfiles = all;
        save();
    }
    function copyVisibilityFromMode(sourceMode) {
        if (spacingModes.indexOf(sourceMode) < 0 || sourceMode === barMode) return;
        const record = {};
        for (const key of barVisibilityKeys)
            record[key] = modeIconVisible(key, sourceMode);
        const all = Object.assign({}, barIconVisibilityProfiles);
        all[barMode] = record;
        barIconVisibilityProfiles = all;
        save();
    }
    // Individual bar modules/icons (all enabled initially, safely migrates RC1).
    property bool showArch: true
    property bool showTime: true
    property bool showDate: true
    // Clock/calendar presentation is independent of all other bar icons.
    property string clockDisplayMode: "auto" // auto | icon | text | both
    property string calendarDisplayMode: "auto"
    property string clockFormat: "HH:mm"
    property string calendarFormat: "ddd, dd MMM"
    property string clockLocale: "system"
    property bool clockLowercase: false
    property bool clockSoundEnabled: true
    property bool clockSoundLoop: true
    property int clockSoundVolume: 125
    property string clockSound: "chime"
    property string clockSoundFile: ""
    readonly property var clockSounds: ["chime", "bell", "digital", "custom"]
    function setClockSoundVolume(value) {
        if (!Number.isInteger(value) || value < 0 || value > 125) return false;
        clockSoundVolume = value;
        save();
        return true;
    }
    function validClockSoundFile(path) {
        return typeof path === "string" && path.startsWith("/") && path.length <= 2048
            && !new RegExp("[\\x00-\\x1f\\x7f]").test(path)
            && new RegExp("\\.(wav|ogg|flac|mp3)$", "i").test(path);
    }
    function setClockSound(sound, path) {
        if (clockSounds.indexOf(sound) < 0 || (sound === "custom" && !validClockSoundFile(path))) return false;
        if (sound === "custom") clockSoundFile = path;
        clockSound = sound;
        save();
        return true;
    }
    property int clockAlarmHour: 7
    property int clockAlarmMinute: 0
    property bool clockAlarmDaily: false
    property bool clockAlarmEnabled: false
    property double clockAlarmNextAt: 0
    property int nightLightTemperature: 4000
    function setNightLightTemperature(value) {
        if (!Number.isInteger(value) || value < 2000 || value > 6000) return false;
        nightLightTemperature = value;
        save();
        return true;
    }
    function nextClockAlarm(now) {
        const date = new Date(now);
        date.setHours(clockAlarmHour, clockAlarmMinute, 0, 0);
        if (date.getTime() <= now) date.setDate(date.getDate() + 1);
        return date.getTime();
    }
    function setClockAlarm(hour, minute, daily) {
        if (!Number.isInteger(hour) || hour < 0 || hour > 23
                || !Number.isInteger(minute) || minute < 0 || minute > 59
                || typeof daily !== "boolean") return false;
        clockAlarmHour = hour;
        clockAlarmMinute = minute;
        clockAlarmDaily = daily;
        clockAlarmNextAt = nextClockAlarm(Date.now());
        clockAlarmEnabled = true;
        save();
        return true;
    }
    function disableClockAlarm() {
        clockAlarmEnabled = false;
        clockAlarmNextAt = 0;
        save();
    }
    // Local annotations use calendar dates, never UTC timestamps.
    property var calendarNotes: ({})
    readonly property var calendarCategories: ["event", "birthday", "work", "holiday"]
    function calendarDateKey(date) { return Qt.formatDate(date, "yyyy-MM-dd"); }
    function validCalendarDate(key) {
        if (typeof key !== "string") return false;
        const match = new RegExp("^([0-9]{4})-([0-9]{2})-([0-9]{2})$").exec(key);
        if (!match || Number(match[1]) < 1000) return false;
        const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
        return date.getFullYear() === Number(match[1]) && date.getMonth() + 1 === Number(match[2])
            && date.getDate() === Number(match[3]);
    }
    function normalizeCalendarNotes(value) {
        const clean = {};
        if (!value || typeof value !== "object" || Array.isArray(value)) return clean;
        for (const key of Object.keys(value).slice(0, 3660)) {
            const note = value[key];
            if (!validCalendarDate(key) || !note || typeof note !== "object" || Array.isArray(note)
                    || typeof note.title !== "string" || !note.title.trim() || note.title.length > 120
                    || new RegExp("[\\x00-\\x1f\\x7f]").test(note.title)) continue;
            clean[key] = {
                title: note.title.trim(),
                category: calendarCategories.indexOf(note.category) >= 0 ? note.category : "event",
                notes: typeof note.notes === "string" ? note.notes.replace(new RegExp("\\x00", "g"), "").slice(0, 1000) : ""
            };
        }
        return clean;
    }
    function calendarNote(key) { return calendarNotes[key] || null; }
    function setCalendarNote(key, title, category, notes) {
        if (!validCalendarDate(key) || typeof title !== "string" || !title.trim() || title.length > 120
                || new RegExp("[\\x00-\\x1f\\x7f]").test(title)
                || calendarCategories.indexOf(category) < 0 || typeof notes !== "string"
                || notes.length > 1000 || notes.indexOf("\0") >= 0
                || (!calendarNotes[key] && Object.keys(calendarNotes).length >= 3660)) return false;
        const next = Object.assign({}, calendarNotes);
        next[key] = {title: title.trim(), category: category, notes: notes};
        calendarNotes = next;
        save();
        return true;
    }
    function removeCalendarNote(key) {
        if (!validCalendarDate(key) || !calendarNotes[key]) return false;
        const next = Object.assign({}, calendarNotes);
        delete next[key];
        calendarNotes = next;
        save();
        return true;
    }
    function validClockFormat(value) {
        return typeof value === "string" && value.trim().length > 0 && value.length <= 120 &&
            !new RegExp("[\\x00-\\x1f\\x7f]").test(value);
    }
    function setClockFormat(key, value) {
        if (["clockFormat", "calendarFormat"].indexOf(key) < 0 || !validClockFormat(value)) return false;
        root[key] = value.trim();
        save();
        return true;
    }
    function formatClock(date, pattern) {
        const locale = clockLocale === "system" ? Qt.locale() : Qt.locale(clockLocale);
        const text = date.toLocaleString(locale, pattern);
        return clockLowercase ? text.toLocaleLowerCase() : text;
    }
    function clockFormatHasSeconds(pattern) {
        // Ignore quoted literal text (and escaped apostrophes) in Qt formats.
        const tokens = pattern.replace(new RegExp("'(?:[^']|'')*'", "g"), "");
        return new RegExp("[sz]").test(tokens);
    }
    property bool showWifi: true
    property bool showBluetooth: true
    property bool showBattery: true
    property bool showAudio: true
    property bool showQuickControl: true
    property bool showNotificationIcon: true
    property string quickControlButtonStyle: "plain" // plain | filled
    property bool showWeather: true
    property bool showWorkspaces: true
    property bool showIndicators: true
    property bool showQuickModes: true
    property bool quickModesAutoHide: true
    property bool showKeepAwake: true
    property bool showSilent: true
    property bool showGamingMode: true
    property bool showNightMode: true
    property bool showMicMute: true
    property bool showMicrophoneStatus: false
    property bool showDownloadSpeed: false
    property bool showUploadSpeed: false
    property string aiProvider: "openai"
    property string aiModel: "gpt-4.1-mini"
    readonly property color accentColor: accentName === "green" ? "#b8bb26" :
        accentName === "blue" ? "#83a598" :
        accentName === "purple" ? "#d3869b" : "#d65d0e"

    FileView {
        id: settingsFile
        path: Qt.resolvedUrl("../user-settings.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: settingsFile.reload()
        onLoaded: {
            const text = settingsFile.text();
            if (!root.settingsLoaded || text === root.settingsSnapshot) return;
            try {
                const data = JSON.parse(text);
                if (!data || typeof data !== "object" || Array.isArray(data)) return;
                const previous = JSON.parse(root.settingsSnapshot || "{}");
                const changed = Array.from(new Set(Object.keys(previous).concat(Object.keys(data))))
                    .filter(key => JSON.stringify(previous[key]) !== JSON.stringify(data[key]));
                root.settingsSnapshot = text;
                if (changed.length && changed.every(key => Object.prototype.hasOwnProperty.call(root.glassDefaults, key)
                    || Object.prototype.hasOwnProperty.call(root.barSurfaceDefaults,key)
                    || Object.prototype.hasOwnProperty.call(root.surfaceSpacingDefaults,key)
                    || Object.prototype.hasOwnProperty.call(root.networkPanelDefaults,key)
                    || Object.prototype.hasOwnProperty.call(root.quickControlDefaults,key)
                    || Object.prototype.hasOwnProperty.call(root.hyprSettingsDefaults,key)
                    || ["settingsWindowAppearance","rusticSettingsWidth","rusticSettingsHeight","surfaceMaterialOverrides"].indexOf(key)>=0
                    || Object.prototype.hasOwnProperty.call(root.launcherAppearanceDefaults,key))) {
                    root.applySurfaceSpacingSettings(root.surfaceSpacingDefaults);
                    root.loadSurfaceMaterials(data);
                    root.loadSettingsAppearance(data);
                    root.loadHyprSettingsPreferences(root.hyprSettingsDefaults);
                    root.loadHyprSettingsPreferences(data);
                    root.applySurfaceSpacingSettings(data);
                    root.applyNetworkPanelSettings(root.networkPanelDefaults);
                    root.applyNetworkPanelSettings(data);
                    root.applyQuickControlSettings(root.quickControlDefaults);
                    root.applyQuickControlSettings(data);
                    root.applyGlassSettings(root.glassDefaults);
                    root.applyGlassSettings(data);
                    root.applyBarSurfaceSettings(root.barSurfaceDefaults);
                    root.applyBarSurfaceSettings(data);
                    root.loadLauncherSettings(data);
                } else ShellReload.requestReload();
            } catch (e) { console.warn("Settings: ignored invalid external JSON"); }
        }
    }
    Component.onCompleted: {
        try {
            settingsSnapshot = settingsFile.text();
            const data = JSON.parse(settingsSnapshot);
            loadSurfaceMaterials(data);
            loadSettingsAppearance(data);
            loadHyprSettingsPreferences(data);
            applySurfaceSpacingSettings(data);
            applyNetworkPanelSettings(data);
            applyQuickControlSettings(data);
            applyGlassSettings(data);
            applyBarSurfaceSettings(data);
            if (typeof data.barPopupsOnHover === "boolean") barPopupsOnHover = data.barPopupsOnHover;
            if (["aether", "gruvbox"].indexOf(data.colorSource) !== -1) colorSource = data.colorSource;
            if (["orange", "green", "blue", "purple"].indexOf(data.accentName) !== -1)
                accentName = data.accentName;
            if (["compact", "clean-compact", "separated", "professional", "simple"].indexOf(data.barMode) !== -1) barMode = data.barMode;
            if (["top", "bottom", "left", "right"].indexOf(data.barPosition) !== -1) barPosition = data.barPosition;
            if (typeof data.absoluteCenter === "boolean") absoluteCenter = data.absoluteCenter;
            if (Number.isInteger(data.centerOffsetX) && data.centerOffsetX >= -400 && data.centerOffsetX <= 400) centerOffsetX = data.centerOffsetX;
            if (["poppins", "sans", "mono", "custom"].indexOf(data.uiFontFamily) >= 0) uiFontFamily = data.uiFontFamily;
            if (typeof data.uiCustomFont === "string" && data.uiCustomFont.length < 140) uiCustomFont = data.uiCustomFont;
            if (typeof data.uiFontScale === "number" && data.uiFontScale >= 0.85 && data.uiFontScale <= 1.2) uiFontScale = data.uiFontScale;
            if (["compact", "comfortable"].indexOf(data.uiDensity) >= 0) uiDensity = data.uiDensity;
            if (typeof data.animationsEnabled === "boolean") animationsEnabled = data.animationsEnabled;
            for (const key of ["animationStyle", "barAnimationStyle"])
                if (animationStyles.indexOf(data[key]) >= 0) root[key] = data[key];
            if (Number.isInteger(data.barIconSize) && data.barIconSize >= 12 && data.barIconSize <= 32) barIconSize = data.barIconSize;
            if (typeof data.wallpaperPath === "string" && data.wallpaperPath.length < 1024) wallpaperPath = data.wallpaperPath;
            if (["auto", "swww", "awww", "hyprpaper", "swaybg"].indexOf(data.wallpaperBackend) >= 0) wallpaperBackend = data.wallpaperBackend;
            if (["fill", "fit", "stretch", "center", "tile"].indexOf(data.wallpaperFitMode) >= 0) wallpaperFitMode = data.wallpaperFitMode;
            if (typeof data.wallpaperAutoRestore === "boolean") wallpaperAutoRestore = data.wallpaperAutoRestore;
            if (typeof data.wallpaperReplaceOnRestore === "boolean") wallpaperReplaceOnRestore = data.wallpaperReplaceOnRestore;
            if (typeof data.lowMemoryShellMode === "boolean") lowMemoryShellMode = data.lowMemoryShellMode;
            if (typeof data.osdEnabled === "boolean") osdEnabled = data.osdEnabled;
            for (const key of ["recordingIndicatorEnabled", "recordingIndicatorBlink"])
                if (typeof data[key] === "boolean") root[key] = data[key];
            if (recordingIndicatorCorners.indexOf(data.recordingIndicatorCorner) >= 0)
                recordingIndicatorCorner = data.recordingIndicatorCorner;
            for (const key of ["recordingIndicatorSize", "recordingIndicatorOffsetX", "recordingIndicatorOffsetY"])
                if (Number.isInteger(data[key])) updateRecordingIndicator(key, data[key], false);
            if (typeof data.barVisible === "boolean") barVisible = data.barVisible;
            if (typeof data.barAutoHide === "boolean") barAutoHide = data.barAutoHide;
            if (typeof data.showBarRecoveryHandle === "boolean") showBarRecoveryHandle = data.showBarRecoveryHandle;
            if (typeof data.showBarToggleIcon === "boolean") showBarToggleIcon = data.showBarToggleIcon;
            if (["solid", "wallpaper"].indexOf(data.lockscreenBackground) >= 0) lockscreenBackground = data.lockscreenBackground;
            if (["icons", "details", "hover"].indexOf(data.cleanRightMode) !== -1)
                cleanRightMode = data.cleanRightMode;
            else if (typeof data.cleanRightDetails === "boolean")
                cleanRightMode = data.cleanRightDetails ? "details" : "icons";
            if (data.marginOverrides && typeof data.marginOverrides === "object" && !Array.isArray(data.marginOverrides)) {
                const validated = {};
                for (const mode of ["compact", "clean-compact", "separated", "professional", "simple"]) {
                    const m = data.marginOverrides[mode];
                    if (!m || typeof m !== "object" || Array.isArray(m)) continue;
                    const values = {};
                    for (const edge of ["top", "bottom", "left", "right"])
                        if (Number.isInteger(m[edge]) && m[edge] >= 0 && m[edge] <= 32) values[edge] = m[edge];
                    validated[mode] = values;
                }
                marginOverrides = validated;
            }
            barPaddingOverrides = validateBarPadding(data.barPaddingOverrides);
            barSpacingOverrides = validateSpacingOverrides(data.barSpacingOverrides);
            barIconOrderByMode = validateBarIconOrders(data.barIconOrderByMode);
            barIconPlacements = validateIconPlacements(data.barIconPlacements);
            // Upgrade old global alignment into 5 isolated layout profiles.
            for (const pair of [["mic", "microphoneStatusPlacement"], ["down", "downloadSpeedPlacement"], ["up", "uploadSpeedPlacement"]])
                if (!barIconPlacements[pair[0]] && ["left", "center", "right"].indexOf(data[pair[1]]) !== -1)
                    barIconPlacements[pair[0]] = data[pair[1]];
            if (data.barIconPlacementsByMode && typeof data.barIconPlacementsByMode === "object")
                barIconPlacementsByMode = validateModePlacements(data.barIconPlacementsByMode);
            else {
                const legacy = {};
                for (const modeName of spacingModes) legacy[modeName] = Object.assign({}, barIconPlacements);
                barIconPlacementsByMode = legacy;
            }
            // Normalize legacy per-zone spacing only within its own layout mode.
            for (const modeName of spacingModes) {
                const targetPlacement = barIconPlacementsByMode[modeName] || {};
                for (const key of barIconKeys) {
                    const targetZone = targetPlacement[key] || defaultBarPlacements[key];
                    for (const zone of spacingZones)
                        if (zone !== targetZone) transferIconSpacing(key, zone, targetZone, modeName);
                }
            }
            loadLauncherSettings(data);
            if (["plain", "filled"].indexOf(data.quickControlButtonStyle) !== -1)
                quickControlButtonStyle = data.quickControlButtonStyle;
            for (const key of ["clockDisplayMode", "calendarDisplayMode"])
                if (["auto", "icon", "text", "both"].indexOf(data[key]) >= 0) root[key] = data[key];
            for (const key of ["clockFormat", "calendarFormat"])
                if (validClockFormat(data[key])) root[key] = data[key].trim();
            if (["system", "id_ID", "en_US"].indexOf(data.clockLocale) >= 0) clockLocale = data.clockLocale;
            if (typeof data.clockLowercase === "boolean") clockLowercase = data.clockLowercase;
            if (typeof data.clockSoundEnabled === "boolean") clockSoundEnabled = data.clockSoundEnabled;
            if (typeof data.clockSoundLoop === "boolean") clockSoundLoop = data.clockSoundLoop;
            if (Number.isInteger(data.clockSoundVolume) && data.clockSoundVolume >= 0 && data.clockSoundVolume <= 125)
                clockSoundVolume = data.clockSoundVolume;
            if (validClockSoundFile(data.clockSoundFile)) clockSoundFile = data.clockSoundFile;
            if (clockSounds.indexOf(data.clockSound) >= 0 && (data.clockSound !== "custom" || clockSoundFile))
                clockSound = data.clockSound;
            if (Number.isInteger(data.clockAlarmHour) && data.clockAlarmHour >= 0 && data.clockAlarmHour <= 23)
                clockAlarmHour = data.clockAlarmHour;
            if (Number.isInteger(data.clockAlarmMinute) && data.clockAlarmMinute >= 0 && data.clockAlarmMinute <= 59)
                clockAlarmMinute = data.clockAlarmMinute;
            if (typeof data.clockAlarmDaily === "boolean") clockAlarmDaily = data.clockAlarmDaily;
            if (data.clockAlarmEnabled === true && Number.isFinite(data.clockAlarmNextAt)
                    && data.clockAlarmNextAt > 0 && data.clockAlarmNextAt <= Date.now() + 172800000) {
                clockAlarmNextAt = data.clockAlarmNextAt;
                clockAlarmEnabled = true;
            }
            if (Number.isInteger(data.nightLightTemperature) && data.nightLightTemperature >= 2000 && data.nightLightTemperature <= 6000)
                nightLightTemperature = data.nightLightTemperature;
            calendarNotes = normalizeCalendarNotes(data.calendarNotes);
            if (data.widgetWorkspaceScopes && typeof data.widgetWorkspaceScopes === "object" &&
                !Array.isArray(data.widgetWorkspaceScopes)) {
                const cleanScopes = {};
                for (const kind of ["notes", "kanban", "randomImage"]) {
                    const ids = data.widgetWorkspaceScopes[kind];
                    cleanScopes[kind] = Array.isArray(ids)
                        ? ids.filter((id, i) => Number.isInteger(id) && id >= 1 && id <= 10 && ids.indexOf(id) === i)
                        : [1];
                }
                widgetWorkspaceScopes = cleanScopes;
            }
            if (data.workspaceNotes && typeof data.workspaceNotes === "object" && !Array.isArray(data.workspaceNotes)) {
                const notes = {};
                for (const key in data.workspaceNotes)
                    if (/^[a-zA-Z0-9_.:-]{1,120}$/.test(key) && typeof data.workspaceNotes[key] === "string")
                        notes[key] = data.workspaceNotes[key].slice(0, 30000);
                workspaceNotes = notes;
            }
            if (data.widgetSizes && typeof data.widgetSizes === "object" && !Array.isArray(data.widgetSizes)) {
                const sizes = {};
                for (const key in data.widgetSizes) {
                    const v = data.widgetSizes[key];
                    if (/^[a-zA-Z0-9_.:-]{1,120}$/.test(key) && v && typeof v === "object" &&
                        Number.isFinite(v.width) && Number.isFinite(v.height))
                        sizes[key] = {width:Math.round(Math.max(250,Math.min(1050,v.width))),
                                      height:Math.round(Math.max(145,Math.min(800,v.height)))};
                }
                widgetSizes = sizes;
            }
            if (data.widgetPositions && typeof data.widgetPositions === "object" && !Array.isArray(data.widgetPositions)) {
                const validPositions = {};
                for (const key in data.widgetPositions) {
                    const v = data.widgetPositions[key];
                    if (/^[a-zA-Z0-9_.:-]{1,120}$/.test(key) && v && typeof v === "object" &&
                        Number.isFinite(v.x) && Number.isFinite(v.y) && v.x >= 0 && v.x <= 1 && v.y >= 0 && v.y <= 1)
                        validPositions[key] = { x:v.x, y:v.y };
                }
                widgetPositions = validPositions;
            }
            for (const name of ["desktopNotes", "desktopKanban", "desktopRandomImage"])
                if (typeof data[name] === "boolean") root[name] = data[name];
            if (typeof data.widgetImageFolder === "string" && data.widgetImageFolder.length <= 1024 &&
                data.widgetImageFolder.indexOf("\0") < 0) widgetImageFolder = data.widgetImageFolder;
            if ([0, 60, 300, 900].indexOf(data.widgetImageRotateSeconds) >= 0)
                widgetImageRotateSeconds = data.widgetImageRotateSeconds;
            if (validQuickOrder(data.quickControlOrder)) quickControlOrder = data.quickControlOrder.slice();
            if (typeof data.showMenuBar === "boolean") showMenuBar = data.showMenuBar;
            for (const key of ["showMenuEdit", "showMenuView", "showMenuShare", "showMenuFile", "showMenuShell", "showMenuTools", "showNotifications", "showLauncher", "showRusticQIcon", "showTaskView", "desktopCalendar", "desktopSystem", "desktopClock", "desktopMedia", "desktopWeather", "desktopConnectivity", "showDock", "dockAutoHide", "dockFiles", "dockBrowser", "dockSettings", "dockTaskView", "dockAI", "dockRunningApps", "cleanRightDetails", "showArch", "showTime", "showDate", "showWifi", "showBluetooth", "showBattery", "showAudio", "showQuickControl", "showNotificationIcon"])
                if (typeof data[key] === "boolean") root[key] = data[key];
            if (typeof data.showWeather === "boolean") showWeather = data.showWeather;
            if (typeof data.showWorkspaces === "boolean") showWorkspaces = data.showWorkspaces;
            if (typeof data.showIndicators === "boolean") showIndicators = data.showIndicators;
            for (const key of ["showQuickModes", "quickModesAutoHide", "showKeepAwake", "showSilent", "showGamingMode", "showNightMode", "showMicMute", "showMicrophoneStatus", "showDownloadSpeed", "showUploadSpeed"])
                if (typeof data[key] === "boolean") root[key] = data[key];
            // Migrate RC4's single global icon toggle set *after* loading its flags.
            // Existing users do not unexpectedly lose icons in Simple mode.
            if (data.barIconVisibilityProfiles && typeof data.barIconVisibilityProfiles === "object")
                barIconVisibilityProfiles = validateVisibilityProfiles(data.barIconVisibilityProfiles);
            else {
                const migrated = {};
                for (const modeName of spacingModes) {
                    const record = {};
                    for (const key of barVisibilityKeys) record[key] = root[key] === true;
                    migrated[modeName] = record;
                }
                barIconVisibilityProfiles = migrated;
            }
            if (["coding", "gaming", "battery", "presentation"].indexOf(data.desktopProfile) !== -1)
                desktopProfile = data.desktopProfile;
            if (data.desktopProfilePrevious && typeof data.desktopProfilePrevious === "object" && !Array.isArray(data.desktopProfilePrevious)) {
                const clean = {};
                for (const key of desktopProfileKeys)
                    if (typeof data.desktopProfilePrevious[key] === "string" || typeof data.desktopProfilePrevious[key] === "boolean")
                        clean[key] = data.desktopProfilePrevious[key];
                desktopProfilePrevious = clean;
            }
            if (["openai", "anthropic", "gemini"].indexOf(data.aiProvider) !== -1) aiProvider = data.aiProvider;
            if (typeof data.aiModel === "string" && data.aiModel.length > 0 && data.aiModel !== "llama3.2") aiModel = data.aiModel;
        } catch (e) {
            console.warn("Settings: defaults in use (user-settings.json): " + e);
        }
        settingsLoaded = true;
    }
    function save() {
        // An external import wins over stale in-memory edits during reload.
        if (ShellReload.pending) return;
        const text = JSON.stringify(Object.assign({
            surfaceMaterialOverrides:surfaceMaterialOverrides,
            settingsWindowAppearance: settingsWindowAppearance,
            rusticSettingsWidth: rusticSettingsWidth,
            rusticSettingsHeight: rusticSettingsHeight,
            hyprSettingsWidth: hyprSettingsWidth,
            hyprSettingsHeight: hyprSettingsHeight,
            hyprSettingsTheme: hyprSettingsTheme,
            hyprSettingsGlass: hyprSettingsGlass,
            hyprSettingsShowUnsupported: hyprSettingsShowUnsupported,
            accentName: accentName,
            colorSource: colorSource,
            barMode: barMode,
            barPosition: barPosition,
            absoluteCenter: absoluteCenter,
            centerOffsetX: centerOffsetX,
            uiFontFamily: uiFontFamily,
            uiCustomFont: uiCustomFont,
            uiFontScale: uiFontScale,
            uiDensity: uiDensity,
            surfacePanelPadding: surfacePanelPadding,
            surfaceCardPadding: surfaceCardPadding,
            surfaceControlPadding: surfaceControlPadding,
            surfaceContentGap: surfaceContentGap,
            surfaceInlineGap: surfaceInlineGap,
            animationsEnabled: animationsEnabled,
            quickControlLayout: quickControlLayout,
            quickControlPanelBackground: quickControlPanelBackground,
            quickControlPanelOutline: quickControlPanelOutline,
            quickControlComponentBackground: quickControlComponentBackground,
            quickControlComponentOutline: quickControlComponentOutline,
            quickControlComponentGlass: quickControlComponentGlass,
            quickControlAccentTint: quickControlAccentTint,
            quickControlSurfaceOpacity: quickControlSurfaceOpacity,
            quickControlHoverOpacity: quickControlHoverOpacity,
            quickControlPanelRadius: quickControlPanelRadius,
            quickControlComponentRadius: quickControlComponentRadius,
            quickControlIconRadius: quickControlIconRadius,
            quickControlComponentSpacing: quickControlComponentSpacing,
            quickControlSectionSpacing: quickControlSectionSpacing,
            quickControlPanelWidth: quickControlPanelWidth,
            quickControlCompact: quickControlCompact,
            quickControlAnimations: quickControlAnimations,
            showSpeedTestPanel: showSpeedTestPanel,
            showSpeedometerGauge: showSpeedometerGauge,
            speedTestGaugeAnimation: speedTestGaugeAnimation,
            speedTestGaugeGlow: speedTestGaugeGlow,
            showSpeedTestTime: showSpeedTestTime,
            speedTestPanelStyle: speedTestPanelStyle,
            glassmorphismEnabled: glassmorphismEnabled,
            rageMode: rageMode,
            ragePalette: ragePalette,
            glassStyle: glassStyle,
            glassOpacity: glassOpacity,
            glassBlurEnabled: glassBlurEnabled,
            glassBlurRadius: glassBlurRadius,
            glassBorderOpacity: glassBorderOpacity,
            glassCornerRadius: glassCornerRadius,
            glassReflectionEnabled: glassReflectionEnabled,
            glassShadowEnabled: glassShadowEnabled,
            glassShadowIntensity: glassShadowIntensity,
            glassTintStrength: glassTintStrength,
            glassPerformanceMode: glassPerformanceMode,
            barBackgroundEnabled: barBackgroundEnabled,
            barOutlineEnabled: barOutlineEnabled,
            barSegmentBackgroundEnabled: barSegmentBackgroundEnabled,
            barSegmentOutlineEnabled: barSegmentOutlineEnabled,
            barModuleBackgroundEnabled: barModuleBackgroundEnabled,
            barModuleOutlineEnabled: barModuleOutlineEnabled,
            barGlassEnabled: barGlassEnabled,
            barRailFillEnabled: barRailFillEnabled,
            barOpacity: barOpacity,
            barCornerRadius: barCornerRadius,
            barSegmentRadius: barSegmentRadius,
            barModuleRadius: barModuleRadius,
            barCapsuleGeometry: barCapsuleGeometry,
            animationStyle: animationStyle,
            barAnimationStyle: barAnimationStyle,
            barIconSize: barIconSize,
            desktopProfile: desktopProfile,
            desktopProfilePrevious: desktopProfilePrevious,
            wallpaperPath: wallpaperPath,
            wallpaperBackend: wallpaperBackend,
            wallpaperFitMode: wallpaperFitMode,
            wallpaperAutoRestore: wallpaperAutoRestore,
            wallpaperReplaceOnRestore: wallpaperReplaceOnRestore,
            lowMemoryShellMode: lowMemoryShellMode,
            osdEnabled: osdEnabled,
            recordingIndicatorEnabled: recordingIndicatorEnabled,
            recordingIndicatorBlink: recordingIndicatorBlink,
            recordingIndicatorCorner: recordingIndicatorCorner,
            recordingIndicatorSize: recordingIndicatorSize,
            recordingIndicatorOffsetX: recordingIndicatorOffsetX,
            recordingIndicatorOffsetY: recordingIndicatorOffsetY,
            barVisible: barVisible,
            barAutoHide: barAutoHide,
            barPopupsOnHover: barPopupsOnHover,
            showBarRecoveryHandle: showBarRecoveryHandle,
            showBarToggleIcon: showBarToggleIcon,
            lockscreenBackground: lockscreenBackground,
            showNotifications: showNotifications,
            showLauncher: showLauncher,
            showRusticQIcon: showRusticQIcon,
            launcherLayoutMode: launcherLayoutMode,
            launcherWidth: launcherWidth,
            launcherHeight: launcherHeight,
            launcherIconSize: launcherIconSize,
            launcherRowHeight: launcherRowHeight,
            launcherFavoriteColumns: launcherFavoriteColumns,
            showTaskView: showTaskView,
            desktopCalendar: desktopCalendar,
            desktopSystem: desktopSystem,
            desktopClock: desktopClock,
            desktopMedia: desktopMedia,
            desktopWeather: desktopWeather,
            desktopConnectivity: desktopConnectivity,
            desktopNotes: desktopNotes,
            desktopKanban: desktopKanban,
            desktopRandomImage: desktopRandomImage,
            widgetImageFolder: widgetImageFolder,
            widgetImageRotateSeconds: widgetImageRotateSeconds,
            widgetPositions: widgetPositions,
            widgetWorkspaceScopes: widgetWorkspaceScopes,
            workspaceNotes: workspaceNotes,
            widgetSizes: widgetSizes,
            showDock: showDock,
            dockFiles: dockFiles,
            dockBrowser: dockBrowser,
            dockSettings: dockSettings,
            dockTaskView: dockTaskView,
            dockAI: dockAI,
            dockRunningApps: dockRunningApps,
            quickControlOrder: quickControlOrder,
            dockAutoHide: dockAutoHide,
            showMenuBar: showMenuBar,
            showMenuEdit: showMenuEdit,
            showMenuView: showMenuView,
            showMenuShare: showMenuShare,
            showMenuFile: showMenuFile,
            showMenuShell: showMenuShell,
            showMenuTools: showMenuTools,
            cleanRightDetails: cleanRightMode === "details", // older clients
            cleanRightMode: cleanRightMode,
            marginOverrides: marginOverrides,
            barPaddingOverrides: barPaddingOverrides,
            barSpacingOverrides: barSpacingOverrides,
            barIconPlacements: barIconPlacements, // legacy compatibility; not changed by v5 UI
            barIconPlacementsByMode: barIconPlacementsByMode,
            barIconOrderByMode: barIconOrderByMode,
            barIconVisibilityProfiles: barIconVisibilityProfiles,
            showArch: showArch,
            showTime: showTime,
            showDate: showDate,
            clockDisplayMode: clockDisplayMode,
            calendarDisplayMode: calendarDisplayMode,
            clockFormat: clockFormat,
            calendarFormat: calendarFormat,
            clockLocale: clockLocale,
            clockLowercase: clockLowercase,
            clockSoundEnabled: clockSoundEnabled,
            clockSoundLoop: clockSoundLoop,
            clockSoundVolume: clockSoundVolume,
            clockSound: clockSound,
            clockSoundFile: clockSoundFile,
            clockAlarmHour: clockAlarmHour,
            clockAlarmMinute: clockAlarmMinute,
            clockAlarmDaily: clockAlarmDaily,
            clockAlarmEnabled: clockAlarmEnabled,
            clockAlarmNextAt: clockAlarmNextAt,
            nightLightTemperature: nightLightTemperature,
            calendarNotes: calendarNotes,
            showWifi: showWifi,
            showBluetooth: showBluetooth,
            showBattery: showBattery,
            showAudio: showAudio,
            showQuickControl: showQuickControl,
            showNotificationIcon: showNotificationIcon,
            quickControlButtonStyle: quickControlButtonStyle,
            showWeather: showWeather,
            showWorkspaces: showWorkspaces,
            showIndicators: showIndicators,
            showQuickModes: showQuickModes,
            quickModesAutoHide: quickModesAutoHide,
            showKeepAwake: showKeepAwake,
            showSilent: showSilent,
            showGamingMode: showGamingMode,
            showNightMode: showNightMode,
            showMicMute: showMicMute,
            showMicrophoneStatus: showMicrophoneStatus,
            showDownloadSpeed: showDownloadSpeed,
            showUploadSpeed: showUploadSpeed,
            aiProvider: aiProvider,
            aiModel: aiModel
        }, launcherSnapshot()), null, 2) + "\n";
        settingsSnapshot = text;
        settingsFile.setText(text);
    }
}
