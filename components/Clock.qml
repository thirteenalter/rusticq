import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"

Pill {
    id: root
    property bool showIcon: true
    property bool showDate: false
    property bool showTime: true
    property bool showDetails: true
    property bool useBarSpacing: false
    property bool vertical: false
    readonly property string timeDisplayMode: SettingsStore.clockDisplayMode
    readonly property string dateDisplayMode: SettingsStore.calendarDisplayMode
    readonly property bool timeHasCaption: timeDisplayMode === "text" || timeDisplayMode === "both" || (timeDisplayMode === "auto" && showDetails)
    readonly property bool dateHasCaption: dateDisplayMode === "text" || dateDisplayMode === "both" || (dateDisplayMode === "auto" && showDetails)
    readonly property bool usesSeconds: (showTime && timeHasCaption && SettingsStore.clockFormatHasSeconds(SettingsStore.clockFormat)) ||
        (showDate && dateHasCaption && SettingsStore.clockFormatHasSeconds(SettingsStore.calendarFormat))
    signal timeActivated(real localX)
    signal dateActivated(real localX)
    color: "transparent"
    horizontalPadding: 4
    verticalPadding: 1

    SystemClock {
        id: clock
        precision: root.usesSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    RowLayout {
        spacing: root.useBarSpacing ? SettingsStore.spacingGroup("right", 4) : Theme.barInfoGap
        InfoSegment {
            id: timePart
            Layout.leftMargin: root.useBarSpacing ? SettingsStore.spacingIcon("right", "time", "before") : 0
            Layout.rightMargin: root.useBarSpacing ? SettingsStore.spacingIcon("right", "time", "after") : 0
            visible: root.showTime
            showSymbol: root.showIcon && root.timeDisplayMode !== "text"
            showCaption: root.timeHasCaption
            stacked: root.vertical
            captionMaximumWidth: root.vertical ? Theme.verticalBarWidth - 30 : 420
            symbol: "\ue8b5"  // schedule, Material Symbols Rounded
            caption: SettingsStore.formatClock(clock.date, SettingsStore.clockFormat)
            onActivated: {
                const point = timePart.mapToItem(root, timePart.width / 2, 0);
                root.timeActivated(point.x);
            }
        }
        InfoSegment {
            id: datePart
            Layout.leftMargin: root.useBarSpacing ? SettingsStore.spacingIcon("right", "date", "before") : 0
            Layout.rightMargin: root.useBarSpacing ? SettingsStore.spacingIcon("right", "date", "after") : 0
            showSymbol: root.showIcon && root.dateDisplayMode !== "text"
            showCaption: root.dateHasCaption
            stacked: root.vertical
            captionMaximumWidth: root.vertical ? Theme.verticalBarWidth - 30 : 420
            visible: root.showDate
            symbol: "\uebcc"  // calendar_month
            caption: SettingsStore.formatClock(clock.date, SettingsStore.calendarFormat)
            onActivated: {
                const point = datePart.mapToItem(root, datePart.width / 2, 0);
                root.dateActivated(point.x);
            }
        }
    }
}
