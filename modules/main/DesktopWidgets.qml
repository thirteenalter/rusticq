import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// Wayland Bottom layer: behind normal application windows, above wallpaper.
// Only the actual cards occupy input space; optional & disabled by default.
PanelWindow {
    id: desktop
    visible: SettingsStore.desktopCalendar || SettingsStore.desktopSystem || SettingsStore.desktopClock
    anchors { top: true; left: true }
    margins { top: 85; left: 22 }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    WlrLayershell.layer: WlrLayer.Bottom
    implicitWidth: 294
    implicitHeight: cards.implicitHeight + 4
    color: "transparent"
    ColumnLayout {
        id: cards
        width: parent.width
        spacing: 10
        Rectangle {
            visible: SettingsStore.desktopClock
            Layout.fillWidth: true; Layout.preferredHeight: visible ? 100 : 0
            radius: 15; color: Theme.background; border.color: Theme.borderaccent
            ColumnLayout {
                anchors.centerIn: parent; spacing: 1
                Text { text: Qt.formatDateTime(clock.date, "HH:mm"); font.family: Fonts.poppinsSB.name; font.pixelSize: 30; color: Theme.foreground; Layout.alignment: Qt.AlignHCenter }
                Text { text: Qt.formatDate(clock.date, "dddd, dd MMMM yyyy"); font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted; Layout.alignment: Qt.AlignHCenter }
            }
        }
        Rectangle {
            visible: SettingsStore.desktopCalendar
            Layout.fillWidth: true; Layout.preferredHeight: visible ? 238 : 0
            radius: 15; color: Theme.background; border.color: Theme.borderaccent
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 7
                Text { text: Qt.formatDate(clock.date, "MMMM yyyy"); font.pixelSize: 14; font.family: Fonts.poppinsSB.name; color: Theme.foreground }
                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; columns: 7; rowSpacing: 0; columnSpacing: 2
                    Repeater {
                        model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                        delegate: Text { required property string modelData; text: modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 9; color: Theme.muted }
                    }
                    Repeater {
                        model: 42
                        delegate: Rectangle {
                            id: dayCard
                            required property int index
                            readonly property int day: index - ((new Date(clock.date.getFullYear(),clock.date.getMonth(),1).getDay() + 6) % 7) + 1
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: 6; color: day === clock.date.getDate() ? Theme.accent : "transparent"
                            Text { anchors.centerIn: parent; text: dayCard.day > 0 && dayCard.day <= new Date(clock.date.getFullYear(),clock.date.getMonth()+1,0).getDate() ? String(dayCard.day) : ""; font.pixelSize: 10; color: dayCard.day === clock.date.getDate() ? Theme.background : Theme.foreground }
                        }
                    }
                }
            }
        }
        Rectangle {
            visible: SettingsStore.desktopSystem
            Layout.fillWidth: true; Layout.preferredHeight: visible ? 115 : 0
            radius: 15; color: Theme.background; border.color: Theme.borderaccent
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 6
                Text { text: "SYSTEM MONITOR"; color: Theme.muted; font.pixelSize: 10; font.family: Fonts.poppinsSB.name }
                Repeater {
                    model: [{label:"CPU",pct:SysMonService.cpuUsage / 100,value:SysMonService.cpuUsage.toFixed(0)+"%"}, {label:"RAM",pct:SysMonService.memUsedPercent,value:SysMonService.memUsedGB.toFixed(1)+" GiB"}]
                    delegate: RowLayout {
                        id: meter; required property var modelData; Layout.fillWidth: true; spacing: 8
                        Text { text: meter.modelData.label; Layout.preferredWidth: 30; font.pixelSize: 10; color: Theme.foreground }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 3; color: Theme.surface
                            Rectangle { width: Math.max(0, Math.min(1, meter.modelData.pct)) * parent.width; height: parent.height; radius: 3; color: Theme.accent }
                        }
                        Text { text: meter.modelData.value; Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Theme.foreground }
                    }
                }
            }
        }
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
}
