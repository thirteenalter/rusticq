pragma Singleton
import QtQuick

QtObject {
    // Original Gruvbox Dark identity, shared across all shell components.
    readonly property color background: "#282828"
    readonly property color surface: "#3c3836"
    readonly property color foreground: "#ebdbb2"
    readonly property color borderaccent: "#303030"
    readonly property color accent: SettingsStore.accentColor
    readonly property color trsp: "transparent"

    // Supporting Gruvbox tones (missing from the original palette).
    readonly property color muted: "#a89984"
    readonly property color error: "#fb4934"
    readonly property color warning: "#fabd2f"
    readonly property color success: "#b8bb26"

    // Shared component geometry for Quick Control + Advanced pages.
    readonly property int sectionPadding: 16
    readonly property int sectionHeaderHeight: 36
    readonly property int sectionGap: 10
    readonly property int sectionRadius: 20
    readonly property int rowRadius: 11
    readonly property int sectionTitleSize: 15
    readonly property int controlTextSize: 12
    readonly property int helperTextSize: 10

    // Shared icon/text rhythm for Compact and Clean Compact information.
    readonly property int barIconSlotSize: 18
    readonly property int barIconTextGap: 6
    readonly property int barInfoGap: 12
}
