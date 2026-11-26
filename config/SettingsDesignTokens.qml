import QtQuick
import "../services"

QtObject {
    id: root
    property string application: "rusticq"
    readonly property var preferences: SettingsMaterial.preferences(application)
    readonly property bool follow: preferences.mode==="follow"
    readonly property bool lightPalette: preferences.mode.indexOf("light")>=0 || (follow && Theme.lightPalette)
    readonly property bool glassEnabled: SettingsMaterial.wantsBlur(application)
    readonly property bool verifiedBlur: application==="hyprland" ? Store.hyprSettingsBlurActive : Store.settingsBlurActive
    readonly property color base: follow ? Theme.background : lightPalette ? "#e8edf4" : "#111720"
    readonly property color foreground: follow ? Theme.foreground : lightPalette ? "#202733" : "#f1f3f5"
    readonly property color muted: follow ? Theme.muted : lightPalette ? "#586474" : "#b0b7c3"
    readonly property color accent: follow ? Theme.accent : preferences.accent
    readonly property color glassTextShadow: Qt.alpha("#000000",0.38)
    readonly property color disabled: lightPalette ? "#7b8592" : "#727985"
    readonly property color edge: outline
    readonly property color shadow: Qt.alpha("#000000",preferences.shadow)
    readonly property color info: accent
    readonly property color line: Qt.alpha(lightPalette ? "#1d2b3b" : "#ffffff",0.08)
    readonly property color outline: Qt.alpha(lightPalette ? "#ffffff" : "#ffffff",preferences.outlineOpacity)
    readonly property color windowColor: glassEnabled ? Qt.alpha(base,verifiedBlur ? preferences.windowOpacity : 0.97) : base
    readonly property color sidebar: follow ? (glassEnabled?Qt.alpha(Theme.surface,preferences.sidebarOpacity):Theme.surface) : glassEnabled ? Qt.alpha(lightPalette ? "#d5dce6" : "#151b24",preferences.sidebarOpacity) : lightPalette ? "#dce2ea" : "#1b212b"
    readonly property color group: follow ? (glassEnabled?Qt.alpha(Theme.surface,preferences.groupOpacity):Theme.surface) : glassEnabled ? Qt.alpha("#ffffff",preferences.groupOpacity) : lightPalette ? "#f7f9fc" : "#242b36"
    readonly property color interactive: follow ? Theme.glassColor("control",Theme.surface) : glassEnabled ? Qt.alpha(foreground,0.065) : lightPalette ? "#e7ebf1" : "#2d3542"
    readonly property color popover: Qt.alpha(base,glassEnabled ? preferences.popoverOpacity : 1)
    readonly property color selected: Qt.alpha(foreground,lightPalette ? 0.10 : 0.12)
    readonly property color hover: Qt.alpha(foreground,0.075)
    readonly property color background: glassEnabled ? Qt.alpha(base,0.14) : base
    readonly property color surface: group
    readonly property color borderaccent: line
    readonly property color contentMuted: muted
    readonly property color secondaryForeground: muted
    readonly property color warning: lightPalette ? "#97611c" : "#e3b877"
    readonly property color error: lightPalette ? "#b94642" : "#f39891"
    readonly property color success: lightPalette ? "#318454" : "#8aca9d"
    readonly property bool light: lightPalette
    readonly property bool rageExclusive: !follow || Theme.rageExclusive
    readonly property bool useAether: follow && Theme.useAether
    readonly property bool aetherAvailable: Theme.aetherAvailable
    readonly property string aetherPath: Theme.aetherPath
    readonly property int panelPadding: Theme.panelPadding
    readonly property int cardPadding: Theme.cardPadding
    readonly property int contentGap: Theme.contentGap
    readonly property int sectionHeaderHeight: Theme.sectionHeaderHeight
    readonly property int motionEnterDuration: motionEnabled?200:0
    readonly property int motionExitDuration: motionEnabled?180:0
    readonly property color controlKnob: foreground
    readonly property color glassCard: group
    readonly property color glassHover: hover
    readonly property color glassSelected: selected
    readonly property bool glassReflections: false
    readonly property bool glassShadows: false
    readonly property color glassShadowColor: Qt.alpha("#000000",preferences.shadow)
    readonly property int sectionPadding: Theme.sectionPadding
    readonly property int sectionGap: Theme.sectionGap
    readonly property int sectionRadius: 12
    readonly property int rowRadius: 7
    readonly property int controlPadding: Theme.controlPadding
    readonly property int inlineGap: 8
    readonly property int compactGap: 6
    readonly property int sectionTitleSize: Fonts.scale(15)
    readonly property int helperTextSize: Fonts.scale(12)
    readonly property int controlTextSize: Fonts.scale(13)
    readonly property int barSymbolSize: Theme.barSymbolSize
    readonly property int sidebarWidth: preferences.sidebarWidth
    readonly property int rowHeight: preferences.density==="compact" ? 44 : 50
    readonly property bool motionEnabled: Theme.motionEnabled && preferences.animations
    readonly property int duration: motionEnabled ? 160 : 0
    readonly property int motionFastDuration: duration
    readonly property int windowRadius: preferences.radius
    readonly property real outlineWidth: preferences.outline ? preferences.outlineWidth : 0
    readonly property string capabilityText: !glassEnabled ? "Opaque appearance" : verifiedBlur ? "Compositor backdrop blur active" : "Opaque fallback · compositor blur unavailable or disabled"
    function glassColor(role, base) { return base; }
    function glassBorder(role, base) { return preferences.outline ? base : "transparent"; }
    function glassBorderWidth(role, width) { return preferences.outline ? Math.min(width,preferences.outlineWidth) : 0; }
    function glassRadius(role, radius) { return Math.min(radius,role==="window" ? windowRadius : 12); }
    function mix(a,b,factor) { return Theme.mix(a,b,factor); }
    function compositorColor(value, fallback) {
        const text=String(value || "");let hex="";
        if (/^0x[0-9a-fA-F]{8}$/.test(text)) hex=text.slice(4)+text.slice(2,4);
        else { const match=/^rgba?\(([0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)\)$/.exec(text); if(match)hex=match[1]; }
        return hex ? Qt.rgba(parseInt(hex.slice(0,2),16)/255,parseInt(hex.slice(2,4),16)/255,parseInt(hex.slice(4,6),16)/255,hex.length===8?parseInt(hex.slice(6,8),16)/255:1) : fallback;
    }
}
