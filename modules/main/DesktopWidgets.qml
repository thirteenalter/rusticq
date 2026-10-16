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
    implicitWidth: 306
    implicitHeight: cards.implicitHeight + 4
    color: "transparent"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Component {
        id: widgetFrame
        Rectangle {
            radius: 18
            color: Qt.alpha(Theme.background, 0.96)
            border.color: Theme.borderaccent
            border.width: 1
        }
    }

    ColumnLayout {
        id: cards
        width: parent.width
        spacing: 12

        Rectangle {
            visible: SettingsStore.desktopClock
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 112 : 0
            radius: 18
            color: Qt.alpha(Theme.background, 0.96)
            border.color: Theme.borderaccent
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 9; color: Qt.alpha(Theme.accent, 0.13); Icon { anchors.centerIn: parent; icon: "\ue8b5"; font.pixelSize: 16; color: Theme.accent } }
                    Text { text: "Desk clock"; Layout.fillWidth: true; color: Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: 10 }
                }
                Text { text: Qt.formatDateTime(clock.date, "HH:mm"); font.family: Fonts.poppinsSB.name; font.pixelSize: 31; color: Theme.foreground; Layout.alignment: Qt.AlignHCenter }
                Text { text: Qt.formatDate(clock.date, "dddd, dd MMMM yyyy"); font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted; Layout.alignment: Qt.AlignHCenter }
            }
        }

        Rectangle {
            visible: SettingsStore.desktopCalendar
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 252 : 0
            radius: 18
            color: Qt.alpha(Theme.background, 0.96)
            border.color: Theme.borderaccent
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 9
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 10; color: Qt.alpha(Theme.accent, 0.13); Icon { anchors.centerIn: parent; icon: "\ue916"; font.pixelSize: 16; color: Theme.accent } }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: "Calendar"; color: Theme.foreground; font.pixelSize: 13; font.family: Fonts.poppinsSB.name }
                        Text { text: Qt.formatDate(clock.date, "MMMM yyyy"); color: Theme.muted; font.pixelSize: 10; font.family: Fonts.poppins.name }
                    }
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 10
                        color: Qt.alpha(Theme.accent, 0.10)
                        Text { anchors.centerIn: parent; text: Qt.formatDate(clock.date, "dd"); color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 2
                    Repeater {
                        model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                        delegate: Text { required property string modelData; text: modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 9; color: Theme.muted }
                    }
                    Repeater {
                        model: 42
                        delegate: Rectangle {
                            id: dayCard
                            required property int index
                            readonly property int offset: (new Date(clock.date.getFullYear(), clock.date.getMonth(), 1).getDay() + 6) % 7
                            readonly property int day: index - offset + 1
                            readonly property int monthLength: new Date(clock.date.getFullYear(), clock.date.getMonth()+1, 0).getDate()
                            readonly property bool valid: day > 0 && day <= monthLength
                            readonly property bool today: valid && day === clock.date.getDate()
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: today ? Theme.accent : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: dayCard.valid ? String(dayCard.day) : ""
                                font.pixelSize: 10
                                color: dayCard.today ? Theme.background : dayCard.valid ? Theme.foreground : Theme.muted
                                opacity: dayCard.valid ? 1 : 0.45
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: SettingsStore.desktopSystem
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 134 : 0
            radius: 18
            color: Qt.alpha(Theme.background, 0.96)
            border.color: Theme.borderaccent
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 10; color: Qt.alpha(Theme.accent, 0.13); Icon { anchors.centerIn: parent; icon: "\ue1db"; font.pixelSize: 16; color: Theme.accent } }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: "System monitor"; color: Theme.foreground; font.pixelSize: 13; font.family: Fonts.poppinsSB.name }
                        Text { text: "CPU, memory and storage snapshot"; color: Theme.muted; font.pixelSize: 10; font.family: Fonts.poppins.name }
                    }
                }
                Repeater {
                    model: [
                        {label:"CPU", pct:SysMonService.cpuUsage / 100, value:SysMonService.cpuUsage.toFixed(0)+"%"},
                        {label:"RAM", pct:SysMonService.memUsedPercent, value:SysMonService.memUsedGB.toFixed(1)+" / "+SysMonService.memTotalGB.toFixed(1)+" GiB"},
                        {label:"Disk", pct:SysMonService.diskUsedPercent, value:SysMonService.diskAvailableGB.toFixed(1)+" GiB free"}
                    ]
                    delegate: ColumnLayout {
                        id: meter
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: meter.modelData.label; Layout.preferredWidth: 36; font.pixelSize: 10; color: Theme.foreground; font.family: Fonts.poppinsSB.name }
                            Text { text: meter.modelData.value; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Theme.foreground }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: Theme.surface
                            Rectangle {
                                width: Math.max(0, Math.min(1, meter.modelData.pct)) * parent.width
                                height: parent.height
                                radius: 3
                                color: Theme.accent
                            }
                        }
                    }
                }
            }
        }
    }
}
