pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One shared palette for the entire shell. Gruvbox always remains unchanged.
// Aether's *applied* colors.toml is watched; no Aether process or side effects.
Singleton {
    id: root
    readonly property string aetherPath: Quickshell.env("HOME") + "/.config/aether/theme/colors.toml"
    property var aetherPalette: ({})
    readonly property bool aetherAvailable: Boolean(aetherPalette.background && aetherPalette.foreground)
    readonly property bool followAether: SettingsStore.colorSource === "aether"
    readonly property bool useAether: followAether && aetherAvailable

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

    readonly property color background: useAether ? aetherPalette.background : "#282828"
    readonly property color foreground: useAether ? aetherPalette.foreground : "#ebdbb2"
    readonly property color accent: useAether ? (aetherPalette.accent || aetherPalette.color4 || "#d65d0e") : SettingsStore.accentColor
    readonly property color surface: useAether ? mix(background, foreground, 0.09) : "#3c3836"
    readonly property color borderaccent: useAether ? mix(background, foreground, 0.065) : "#303030"
    readonly property color muted: useAether ? mix(background, foreground, 0.57) : "#a89984"
    readonly property color error: useAether ? (aetherPalette.color1 || "#fb4934") : "#fb4934"
    readonly property color warning: useAether ? (aetherPalette.color3 || "#fabd2f") : "#fabd2f"
    readonly property color success: useAether ? (aetherPalette.color2 || "#b8bb26") : "#b8bb26"
    readonly property color trsp: "transparent"

    readonly property int sectionPadding: 16
    readonly property int sectionHeaderHeight: 36
    readonly property int sectionGap: 10
    readonly property int sectionRadius: 20
    readonly property int rowRadius: 11
    readonly property int sectionTitleSize: 15
    readonly property int controlTextSize: 12
    readonly property int helperTextSize: 10
    // RusticQ alpha-1: one visual rhythm for clock, date, weather and system.
    readonly property int barTextSize: 12
    readonly property int barSymbolSize: 16
    readonly property int barIconSlotSize: 18
    readonly property int barIconTextGap: 6
    readonly property int barInfoGap: 12
    // Alpha 3: shared spacing rhythm, including edge-positioned bars.
    readonly property int barEdgeGap: 9
    readonly property int barGroupGap: 12
    readonly property int barControlGap: 8
    readonly property int verticalBarWidth: 64
}
