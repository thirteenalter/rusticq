pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Exactly one provider supplies every semantic token, including solid surfaces.
// Aether's *applied* colors.toml is watched; no Aether process or side effects.
Singleton {
    id: root
    readonly property string aetherPath: Quickshell.env("HOME") + "/.config/aether/theme/colors.toml"
    property var aetherPalette: ({})
    readonly property bool aetherAvailable: Boolean(aetherPalette.background && aetherPalette.foreground)
    readonly property bool followAether: SettingsStore.colorSource === "aether"
    readonly property bool rageExclusive: SettingsStore.rageMode === "exclusive"
    readonly property bool useAether: !rageExclusive && followAether && aetherAvailable
    readonly property string paletteProvider: rageExclusive ? "rage" : useAether ? "aether" : "gruvbox"

    function validHex(text) { return new RegExp("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$").test(text); }
    function parseAether(text) {
        // The generated palette uses flat TOML keys. Never eval arbitrary content.
        const found = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const match = lines[i].trim().match(new RegExp("^([a-zA-Z][a-zA-Z0-9_]*)\\s*=\\s*[\"'](#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?)[\"']"));
            if (match && validHex(match[2])) found[match[1]] = match[2];
        }
        // Never expose a partially updated or invalid file as active palette.
        if (!found.background || !found.foreground) return;
        root.aetherPalette = found;
    }
    function mix(a, b, factor) {
        return Qt.rgba(a.r*(1-factor)+b.r*factor, a.g*(1-factor)+b.g*factor,
                       a.b*(1-factor)+b.b*factor, 1);
    }
    FileView {
        id: aetherFile
        path: Qt.resolvedUrl("file://" + root.aetherPath)
        watchChanges: true
        onLoaded: root.parseAether(aetherFile.text())
        onFileChanged: aetherFile.reload()
    }
    // Also covers Aether's atomic replacement and file first appearing later.
    Timer {
        interval: 8000
        repeat: true
        running: root.followAether
        onTriggered: aetherFile.reload()
    }

    // Native palettes contain only native constants. No external palette or
    // wallpaper value enters this branch, even when glass is switched off.
    readonly property var ragePalettes: ({
        obsidian: {background:"#19191c",surface:"#262629",foreground:"#f5f5f7",secondary:"#c7c7cc",muted:"#98989f",accent:"#d8d8df",border:"#444448",edge:"#ffffff",error:"#ff6961",warning:"#ffd166",success:"#71d69a",info:"#86b9ff"},
        pearl: {background:"#f2f2f5",surface:"#e4e4e9",foreground:"#19191c",secondary:"#404047",muted:"#606068",accent:"#373740",border:"#c8c8cf",edge:"#ffffff",error:"#be3044",warning:"#855500",success:"#216e45",info:"#245fa9"},
        "pure-crystal": {background:"#101013",surface:"#222226",foreground:"#fafafc",secondary:"#d1d1d7",muted:"#a3a3ac",accent:"#e3e3e9",border:"#414148",edge:"#ffffff",error:"#ff6961",warning:"#ffd166",success:"#71d69a",info:"#86b9ff"},
        "graphite-frost": {background:"#242427",surface:"#303034",foreground:"#f5f5f7",secondary:"#c7c7cc",muted:"#a0a0a8",accent:"#d8d8df",border:"#4c4c53",edge:"#ffffff",error:"#ff6961",warning:"#ffd166",success:"#71d69a",info:"#86b9ff"}
    })
    readonly property var effectivePalette: {
        if (rageExclusive) return ragePalettes[SettingsStore.ragePalette] || ragePalettes.obsidian;
        if (useAether) return {background:aetherPalette.background,foreground:aetherPalette.foreground,
            accent:aetherPalette.accent || aetherPalette.color4 || "#d65d0e",
            error:aetherPalette.color1 || "#fb4934",warning:aetherPalette.color3 || "#fabd2f",
            success:aetherPalette.color2 || "#b8bb26",info:aetherPalette.color4 || "#83a598"};
        return {background:"#282828",surface:"#3c3836",foreground:"#ebdbb2",accent:SettingsStore.accentColor,
            border:"#303030",muted:"#a89984",error:"#fb4934",warning:"#fabd2f",success:"#b8bb26",info:"#83a598"};
    }
    readonly property color background: Qt.alpha(effectivePalette.background, 1)
    readonly property color foreground: Qt.alpha(effectivePalette.foreground, 1)
    readonly property color accent: effectivePalette.accent
    readonly property color surface: effectivePalette.surface || mix(background, foreground, 0.09)
    readonly property color borderaccent: effectivePalette.border || mix(background, foreground, 0.065)
    readonly property color muted: effectivePalette.muted || mix(background, foreground, 0.57)
    readonly property color secondaryForeground: effectivePalette.secondary || mix(background, foreground, 0.78)
    readonly property color error: effectivePalette.error
    readonly property color warning: effectivePalette.warning
    readonly property color success: effectivePalette.success
    readonly property color info: effectivePalette.info
    readonly property color edge: effectivePalette.edge || foreground
    readonly property color controlKnob: rageExclusive ? background : foreground
    readonly property color shadow: "#000000"
    readonly property color authenticationScrim: Qt.alpha(shadow, 0.80)
    readonly property color modalScrim: Qt.alpha(shadow, 0.60)
    readonly property bool lightPalette: background.r * 0.2126 + background.g * 0.7152 + background.b * 0.0722 > 0.6
    function calendarCategoryColor(category) {
        return category === "birthday" ? warning : category === "work" ? success
            : category === "holiday" ? info : accent;
    }
    readonly property color trsp: "transparent"

    // Materials consume the resolved provider; they never select a palette.
    readonly property bool glassEnabled: SettingsStore.glassmorphismEnabled
    readonly property bool glassEconomy: SettingsStore.glassPerformanceMode || SettingsStore.lowMemoryShellMode
    readonly property bool glassEffects: glassEnabled && !glassEconomy
    readonly property bool glassReflections: glassEffects && SettingsStore.glassReflectionEnabled
    readonly property bool glassShadows: glassEffects && SettingsStore.glassShadowEnabled
    readonly property bool glassBackdropAvailable: Store.glassBlurActive && !glassEconomy
    readonly property real glassEffectiveOpacity: Math.max(SettingsStore.glassOpacity, glassBackdropAvailable ? 0.15 : 0.86)
    // Exclusive tint adjusts native neutral luminance only. Adaptive retains a
    // restrained version of the selected external accent, without a color wash.
    readonly property color glassTint: rageExclusive ? mix(background, foreground, SettingsStore.glassTintStrength * 0.06)
        : mix(background, accent, SettingsStore.glassTintStrength * (SettingsStore.glassStyle === "tinted" ? 0.35 : 0.16))
    readonly property color glassPrimary: Qt.alpha(glassTint, glassEffectiveOpacity)
    readonly property color glassWindow: Qt.alpha(glassTint, Math.max(0.56, glassEffectiveOpacity))
    readonly property color glassOverlayInk: lightPalette ? shadow : edge
    readonly property color glassSecondary: Qt.alpha(glassOverlayInk, 0.03)
    readonly property color glassCard: Qt.alpha(glassOverlayInk, 0.045)
    readonly property color glassControl: Qt.alpha(glassOverlayInk, 0.065)
    readonly property color glassHover: Qt.alpha(glassOverlayInk, 0.10)
    readonly property color glassPressed: Qt.alpha(glassOverlayInk, 0.16)
    readonly property color glassSelected: Qt.alpha(accent, 0.18)
    readonly property color glassPopup: Qt.alpha(glassTint, Math.max(0.50, glassEffectiveOpacity))
    readonly property color glassTooltip: Qt.alpha(glassTint, Math.max(0.82, glassEffectiveOpacity))
    readonly property color glassBorderColor: Qt.alpha(glassOverlayInk, SettingsStore.glassBorderOpacity)
    readonly property color glassSpecular: Qt.alpha(edge, glassReflections ? Math.min(0.30, SettingsStore.glassBorderOpacity * 1.25) : 0)
    readonly property color glassLighting: Qt.alpha(edge, glassReflections ? 0.025 : 0)
    function glassShadowAlpha(intensity) { return 0.20*Math.max(0,intensity)/(Math.max(0,intensity)+0.10); }
    readonly property color glassShadowColor: Qt.alpha(shadow, glassShadows ? glassShadowAlpha(SettingsStore.glassShadowIntensity) : 0)
    readonly property color contentMuted: glassEnabled ? secondaryForeground : muted
    readonly property color glassTextShadow: Qt.alpha(shadow, glassEnabled ? 0.60 : 0)
    readonly property color glassModal: Qt.alpha(glassTint, Math.max(0.88, glassEffectiveOpacity))
    readonly property color glassAuthentication: mix(background, surface, 0.30)
    readonly property bool barGlassActive: glassEnabled && SettingsStore.barGlassEnabled
    readonly property bool barVertical: SettingsStore.barPosition === "left" || SettingsStore.barPosition === "right"
    readonly property color barBaseBackground: SettingsStore.barMode === "separated" && SettingsStore.barRailFillEnabled ? background : barVertical
        ? (SettingsStore.barMode === "separated" || SettingsStore.barMode === "clean-compact" ? "transparent" : background)
        : SettingsStore.barMode === "professional" ? background : "transparent"
    readonly property real barBaseBorderWidth: SettingsStore.barMode === "separated" && SettingsStore.barRailFillEnabled ? 1 : (barVertical && SettingsStore.barMode !== "separated" && SettingsStore.barMode !== "clean-compact")
        || (!barVertical && SettingsStore.barMode === "professional") ? 1 : 0
    readonly property real barBaseCornerRadius: barVertical && SettingsStore.barMode !== "professional" ? 12 : 0
    function barBackgroundVisible(layer) {
        return layer === "outer" ? SettingsStore.barBackgroundEnabled
            : layer === "segment" ? SettingsStore.barSegmentBackgroundEnabled : SettingsStore.barModuleBackgroundEnabled;
    }
    function barOutlineVisible(layer) {
        return layer === "outer" ? SettingsStore.barOutlineEnabled
            : layer === "segment" ? SettingsStore.barSegmentOutlineEnabled : SettingsStore.barModuleOutlineEnabled;
    }
    function barSurfaceColor(layer, original) {
        if (!barBackgroundVisible(layer)) return "transparent";
        const value=barGlassActive ? (layer === "outer" ? glassColor("bar",original)
            : glassColor(layer === "segment" ? "primary" : "control",original)) : original;
        const color=typeof value === "string" ? Qt.tint(value,"transparent") : value;
        return Qt.alpha(color,color.a*SettingsStore.barOpacity);
    }
    function barSurfaceBorder(layer, original) {
        return !barOutlineVisible(layer) ? "transparent" : barGlassActive ? glassBorder("primary",original) : original;
    }
    function barSurfaceBorderWidth(layer, original) {
        if (!barOutlineVisible(layer)) return 0;
        if (layer === "outer" && !SettingsStore.barBackgroundEnabled) return Math.max(1,original);
        // A clear separated rail must never acquire RAGE's automatic frame.
        if (layer === "outer" && SettingsStore.barMode === "separated") return original;
        return barGlassActive ? glassBorderWidth("primary",original) : original;
    }
    function barSurfaceRadius(layer, original, extent) {
        const custom=layer === "outer" ? SettingsStore.barCornerRadius
            : layer === "segment" ? SettingsStore.barSegmentRadius : SettingsStore.barModuleRadius;
        if (layer !== "outer" && SettingsStore.barCapsuleGeometry) return Math.max(0,extent/2);
        return custom >= 0 ? custom : original;
    }
    function glassScrim(original) { return glassEnabled ? Qt.alpha(background, 0.18) : original; }
    function sameRgb(a, b) { return Math.abs(a.r-b.r) + Math.abs(a.g-b.g) + Math.abs(a.b-b.b) < 0.02; }
    function surfacePreference(surface) {const p=SettingsStore.surfaceMaterialOverrides[surface];return p && p.inherit===false?p:null;}
    function surfaceColor(surface,role,original) {
        const p=surfacePreference(surface);if(!p)return glassColor(role,original);
        if(!p.background)return "transparent";
        if(!p.glass || !glassEnabled)return original;
        return Qt.alpha(glassTint,Math.max(p.opacity,Store.glassBlurActive?0:0.92));
    }
    function surfaceBorder(surface,role,original) {const p=surfacePreference(surface);return p && !p.outline?"transparent":glassBorder(role,original);}
    function surfaceBorderWidth(surface,role,original) {const p=surfacePreference(surface);return p && !p.outline?0:glassBorderWidth(role,original);}
    function surfaceRadius(surface,role,original) {const p=surfacePreference(surface);return p?p.radius:glassRadius(role,original);}
    function glassColor(role, original) {
        if (!glassEnabled || role === "signal" || role === "security") return original;
        const base = typeof original === "string" ? Qt.tint(original, "transparent") : original;
        if (role === "bar") return SettingsStore.barMode === "separated" && !SettingsStore.barRailFillEnabled ? original : glassPrimary;
        if (base.a < 0.001) return original;
        // Filled semantic actions retain their contrast with inverse text.
        if (base.a > 0.98 && (sameRgb(base, accent) || sameRgb(base, error)
            || sameRgb(base, success) || sameRgb(base, warning)
            || sameRgb(base, foreground) || sameRgb(base, muted))) return original;
        if (role === "window") return glassWindow;
        if (role === "primary") return glassPrimary;
        if (role === "popup") return glassPopup;
        if (role === "tooltip") return glassTooltip;
        if (role === "modal") return glassModal;
        if (role === "authentication") return glassAuthentication;
        if (sameRgb(base, accent)) return Qt.alpha(accent, Math.max(base.a, glassSelected.a));
        if (sameRgb(base, foreground) && base.a < 0.3) return base.a > 0.13 ? glassPressed : glassHover;
        return role === "control" ? glassControl : role === "secondary" ? glassSecondary : glassCard;
    }
    function glassRadius(role, original) {
        if (!glassEnabled || role === "signal" || role === "security" || original <= 0) return original;
        return ["primary", "popup", "tooltip", "modal", "authentication"].indexOf(role) >= 0
            ? SettingsStore.glassCornerRadius : Math.min(role === "control" ? 12 : 14, SettingsStore.glassCornerRadius * 0.65);
    }
    function glassBorder(role, original) {
        if (!glassEnabled || role === "signal" || role === "security") return original;
        if (original === accent || original === error) return original;
        return glassBorderColor;
    }
    function glassBorderWidth(role, original) {
        if (!glassEnabled || role === "signal" || role === "security") return original;
        return ["primary", "popup", "tooltip", "modal", "authentication"].indexOf(role) >= 0 ? 1 : original;
    }

    // Content insets have one owner: window > card > control. A popup whose
    // child already owns its padding must not add a second inset in its Loader.
    readonly property int panelPadding: SettingsStore.surfacePanelPadding >= 0 ? SettingsStore.surfacePanelPadding : SettingsStore.uiDensity === "compact" ? 12 : 16
    readonly property int cardPadding: SettingsStore.surfaceCardPadding >= 0 ? SettingsStore.surfaceCardPadding : SettingsStore.uiDensity === "compact" ? 10 : 12
    readonly property int controlPadding: SettingsStore.surfaceControlPadding >= 0 ? SettingsStore.surfaceControlPadding : SettingsStore.uiDensity === "compact" ? 8 : 12
    readonly property int contentGap: SettingsStore.surfaceContentGap >= 0 ? SettingsStore.surfaceContentGap : SettingsStore.uiDensity === "compact" ? 8 : 12
    readonly property int inlineGap: SettingsStore.surfaceInlineGap >= 0 ? SettingsStore.surfaceInlineGap : SettingsStore.uiDensity === "compact" ? 6 : 8
    readonly property int compactGap: 4
    readonly property int dialogPadding: panelPadding + inlineGap
    readonly property int sectionPadding: panelPadding
    readonly property int sectionHeaderHeight: 36
    readonly property int sectionGap: contentGap
    readonly property int sectionRadius: 20
    readonly property int rowRadius: 11
    readonly property int sectionTitleSize: 15
    readonly property int controlTextSize: 12
    readonly property int helperTextSize: 10
    // Shared motion timing; SurfaceMotion supplies the selected surface style.
    readonly property bool motionEnabled: SettingsStore.animationsEnabled
    readonly property int motionFastDuration: motionEnabled ? 120 : 0
    readonly property int motionEnterDuration: motionEnabled ? 220 : 0
    readonly property int motionExitDuration: motionEnabled ? 160 : 0
    readonly property int motionDistance: 22
    // RusticQ alpha-1: one visual rhythm for clock, date, weather and system.
    readonly property int barTextSize: 12
    readonly property int barSymbolSize: SettingsStore.barIconSize
    readonly property int barIconSlotSize: Math.max(18, barSymbolSize + 2)
    readonly property int barIconTextGap: 6
    readonly property int barInfoGap: 12
    // Alpha 3: shared spacing rhythm, including edge-positioned bars.
    readonly property int barEdgeGap: 4
    readonly property int barGroupGap: 9
    readonly property int barControlGap: 8
    readonly property int verticalBarWidth: Math.max(60, barRailItemSize + 20)
    readonly property int barRailItemSize: Math.max(32, barSymbolSize + 12)
    readonly property int barRailGroupPadding: 4
    readonly property int barRailZoneGap: 12
}
