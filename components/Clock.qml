import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"

Pill {
    id: root
    // Retained for compatibility with existing bar modes. Material icons are
    // now always visible so every status item follows the same design system.
    property bool showIcon: true
    property bool showDate: false
    property bool showTime: true
    property bool showDetails: true
    property bool useBarSpacing: false
    signal timeActivated(real localX)
    signal dateActivated(real localX)
    color: "transparent"
    horizontalPadding: 4
    verticalPadding: 1

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        spacing: root.useBarSpacing ? SettingsStore.spacingGroup("right", 4) : Theme.barInfoGap
        InfoSegment {
            id: timePart
            Layout.leftMargin: root.useBarSpacing ? SettingsStore.spacingIcon("right", "time", "before") : 0
            Layout.rightMargin: root.useBarSpacing ? SettingsStore.spacingIcon("right", "time", "after") : 0
            visible: root.showTime
            showCaption: root.showDetails
            symbol: "\ue8b5"  // schedule, Material Symbols Rounded
            caption: Qt.formatDateTime(clock.date, "HH:mm")
            onActivated: {
                const point = timePart.mapToItem(root, timePart.width / 2, 0);
                root.timeActivated(point.x);
            }
        }
        InfoSegment {
            id: datePart
            Layout.leftMargin: root.useBarSpacing ? SettingsStore.spacingIcon("right", "date", "before") : 0
            Layout.rightMargin: root.useBarSpacing ? SettingsStore.spacingIcon("right", "date", "after") : 0
            showCaption: root.showDetails
            visible: root.showDate
            symbol: "\uebcc"  // calendar_month
            caption: Qt.formatDateTime(clock.date, root.showIcon ? "ddd, dd MMM" : "dddd, dd MMM")
            onActivated: {
                const point = datePart.mapToItem(root, datePart.width / 2, 0);
                root.dateActivated(point.x);
            }
        }
    }
}
