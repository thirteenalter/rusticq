import QtQuick
import QtQuick.Layouts
import "../config"

Pill {
    id: root
    property bool compact: false
    property bool backgroundEnabled: true
    readonly property bool cleanStyle: compact && !backgroundEnabled
    color: backgroundEnabled ? Theme.borderaccent : "transparent"
    // Bare indicators use the bar's spacing instead of invisible pill padding.
    horizontalPadding: !backgroundEnabled ? 0 : compact ? 8 : 14
    verticalPadding: compact ? 3 : 7

    RowLayout {
        spacing: root.cleanStyle ? Theme.barInfoGap : root.compact ? 8 : 12
        Bluetooth { iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14; cleanStyle: root.cleanStyle }
        Wifi { iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14; cleanStyle: root.cleanStyle }
        Battery { iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14; cleanStyle: root.cleanStyle }
    }
}
