import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../../config"
import "../../services"
import "../../components"

// Layer Bottom puts cards behind normal application windows.
// Each card measures its own content; overflow scrolls on short displays.
PanelWindow {
    id: desktop
    visible: SettingsStore.desktopCalendar || SettingsStore.desktopSystem || SettingsStore.desktopClock ||
             SettingsStore.desktopMedia || SettingsStore.desktopWeather || SettingsStore.desktopConnectivity
    anchors { top: true; left: true }
    margins { top: 76; left: 20 }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    WlrLayershell.layer: WlrLayer.Bottom
    implicitWidth: 302
    implicitHeight: Math.max(1, Math.min(cards.implicitHeight + 4,
        desktop.screen ? Math.max(180, desktop.screen.height - 110) : 750))
    color: "transparent"

    readonly property var player: {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i) if (players[i].isPlaying) return players[i];
        return players.length ? players[0] : null;
    }
    readonly property bool hasPlayer: player !== null
    property var cpuHistory: []
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Timer {
        interval: 2000
        repeat: true
        running: desktop.visible && SettingsStore.desktopSystem
        triggeredOnStart: true
        onTriggered: desktop.cpuHistory = desktop.cpuHistory.concat([Math.max(0, Math.min(1, SysMonService.cpuUsage / 100))]).slice(-42)
    }
    Flickable {
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: cards.implicitHeight + 4
        ColumnLayout {
            id: cards
            width: desktop.width
            spacing: 12

            Rectangle {
                visible: SettingsStore.desktopClock
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? clockContent.implicitHeight + 28 : 0
                radius: 17; color: Theme.background; border.color: Theme.borderaccent
                ColumnLayout {
                    id: clockContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true; spacing: 7
                        Icon { icon: "\ue8b5"; color: Theme.accent; font.pixelSize: 17 }
                        Text { text: "DESK CLOCK"; color: Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: 10; Layout.fillWidth: true }
                    }
                    Text { text: Qt.formatDateTime(clock.date, "HH:mm"); color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 30; Layout.alignment: Qt.AlignHCenter }
                    Text { text: Qt.formatDate(clock.date, "dddd, dd MMMM yyyy"); color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                }
            }

            Rectangle {
                visible: SettingsStore.desktopCalendar
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? calendarContent.implicitHeight + 28 : 0
                radius: 17; color: Theme.background; border.color: Theme.borderaccent
                ColumnLayout {
                    id: calendarContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 9
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: "\ue916"; color: Theme.accent; font.pixelSize: 18 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: "Calendar"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Text { text: Qt.formatDate(clock.date, "MMMM yyyy"); color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                        }
                        Rectangle {
                            Layout.preferredWidth: 30; Layout.preferredHeight: 26; radius: 8
                            color: Qt.alpha(Theme.accent, .14)
                            Text { anchors.centerIn: parent; text: Qt.formatDate(clock.date, "dd"); color: Theme.accent; font.pixelSize: 11; font.family: Fonts.poppinsSB.name }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true; columns: 7; columnSpacing: 3; rowSpacing: 2
                        Repeater {
                            model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                            delegate: Text { required property string modelData; text: modelData; Layout.fillWidth: true; Layout.preferredHeight: 19; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: Theme.muted; font.pixelSize: 9 }
                        }
                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                id: dayChip; required property int index
                                readonly property int day: index - ((new Date(clock.date.getFullYear(), clock.date.getMonth(), 1).getDay() + 6) % 7) + 1
                                readonly property bool validDay: day >= 1 && day <= new Date(clock.date.getFullYear(),clock.date.getMonth()+1,0).getDate()
                                readonly property bool isToday: validDay && day === clock.date.getDate()
                                Layout.fillWidth: true; Layout.preferredHeight: 24; radius: 7
                                color: isToday ? Theme.accent : "transparent"
                                Text { anchors.centerIn: parent; text: dayChip.validDay ? String(dayChip.day) : ""; color: dayChip.isToday ? Theme.background : Theme.foreground; font.pixelSize: 10 }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: SettingsStore.desktopSystem
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? sysContent.implicitHeight + 28 : 0
                radius: 17; color: Theme.background; border.color: Theme.borderaccent
                ColumnLayout {
                    id: sysContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: "\uf190"; font.pixelSize: 18; color: Theme.accent }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: "System monitor"; font.pixelSize: 13; font.family: Fonts.poppinsSB.name; color: Theme.foreground }
                            Text { text: "Live usage · history"; font.pixelSize: 10; font.family: Fonts.poppins.name; color: Theme.muted }
                        }
                        Text { text: "LIVE"; font.pixelSize: 9; color: Theme.accent; font.family: Fonts.poppinsSB.name }
                    }
                    MetricWave { Layout.fillWidth: true; Layout.preferredHeight: 48; samples: desktop.cpuHistory }
                    Repeater {
                        model: [
                            {label:"CPU", pct:SysMonService.cpuUsage/100, value:SysMonService.cpuUsage.toFixed(0)+"%"},
                            {label:"RAM", pct:SysMonService.memUsedPercent, value:SysMonService.memUsedGB.toFixed(1)+" / "+SysMonService.memTotalGB.toFixed(1)+" GiB"},
                            {label:"Disk", pct:SysMonService.diskUsedPercent, value:SysMonService.diskAvailableGB.toFixed(1)+" GiB free"}
                        ]
                        delegate: ColumnLayout {
                            id: meter; required property var modelData
                            Layout.fillWidth: true; spacing: 3
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: meter.modelData.label; Layout.fillWidth: true; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 10 }
                                Text { text: meter.modelData.value; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 3; color: Theme.surface
                                Rectangle { height: parent.height; width: Math.max(0,Math.min(1,meter.modelData.pct))*parent.width; radius: 3; color: Theme.accent }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: SettingsStore.desktopMedia
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? mediaContent.implicitHeight + 28 : 0
                radius: 17; color: Theme.background; border.color: Theme.borderaccent
                ColumnLayout {
                    id: mediaContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 9
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: "\ue405"; color: Theme.accent; font.pixelSize: 19 }
                        Text { text: "Now Playing"; Layout.fillWidth: true; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                        Text { text: desktop.hasPlayer ? desktop.player.identity : "Idle"; color: Theme.muted; font.pixelSize: 9; elide: Text.ElideRight; Layout.maximumWidth: 90 }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 57; radius: 11; color: Theme.surface
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 9
                            Rectangle { Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 10; color: Qt.alpha(Theme.accent, .12); Icon { anchors.centerIn: parent; icon: "\ue405"; font.pixelSize: 23; color: Theme.accent } }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text { Layout.fillWidth: true; text: desktop.hasPlayer ? (desktop.player.trackTitle || "Unknown track") : "Nothing playing"; elide: Text.ElideRight; color: Theme.foreground; font.pixelSize: 11; font.family: Fonts.poppinsSB.name }
                                Text { Layout.fillWidth: true; text: desktop.hasPlayer ? (desktop.player.trackArtist || "Unknown artist") : "Open a music player"; elide: Text.ElideRight; color: Theme.muted; font.pixelSize: 10 }
                            }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 14
                        Repeater {
                            model: [
                                {glyph:"\ue045",op:"previous"},
                                {glyph:desktop.hasPlayer && desktop.player.isPlaying ? "\ue034" : "\ue037",op:"toggle"},
                                {glyph:"\ue044",op:"next"}
                            ]
                            delegate: Rectangle {
                                id: mediaButton; required property var modelData
                                Layout.preferredWidth: 38; Layout.preferredHeight: 34; radius: 10; color: Theme.surface
                                Icon { anchors.centerIn: parent; icon: mediaButton.modelData.glyph; font.pixelSize: 20; color: Theme.foreground }
                                MouseArea { anchors.fill: parent; enabled: desktop.hasPlayer && desktop.player.canControl; cursorShape: Qt.PointingHandCursor; onClicked: {
                                    if (mediaButton.modelData.op === "previous" && desktop.player.canGoPrevious) desktop.player.previous();
                                    if (mediaButton.modelData.op === "next" && desktop.player.canGoNext) desktop.player.next();
                                    if (mediaButton.modelData.op === "toggle" && desktop.player.canTogglePlaying) desktop.player.togglePlaying();
                                } }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: SettingsStore.desktopWeather
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? weatherContent.implicitHeight + 28 : 0
                radius: 17; color: Theme.background; border.color: Theme.borderaccent
                ColumnLayout {
                    id: weatherContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: WeatherService.icon; color: Theme.accent; font.pixelSize: 24 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: "Weather"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Text { text: WeatherService.location || "Location unavailable"; color: Theme.muted; font.pixelSize: 10; elide: Text.ElideRight }
                        }
                        Text { text: WeatherService.temperature || "--"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 18 }
                    }
                    Text { text: WeatherService.condition || "Weather information unavailable"; color: Theme.foreground; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    Text { text: "Feels like " + (WeatherService.feelsLike || "--"); color: Theme.muted; font.pixelSize: 10 }
                }
            }

            Rectangle {
                visible: SettingsStore.desktopConnectivity
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? networkContent.implicitHeight + 28 : 0
                radius: 17; color: Theme.background; border.color: Theme.borderaccent
                ColumnLayout {
                    id: networkContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: "\ue1d8"; color: Theme.accent; font.pixelSize: 18 }
                        Text { text: "Connectivity"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: 13; font.family: Fonts.poppinsSB.name }
                    }
                    Repeater {
                        model: [
                            {glyph:WifiService.icon, label:"Wi-Fi", detail:WifiService.connected ? (WifiService.ssid || "Connected") : "Disconnected"},
                            {glyph:BluetoothService.icon, label:"Bluetooth", detail:BluetoothService.enabled ? "Enabled" : "Off"},
                            {glyph:BatteryService.icon, label:"Battery", detail:BatteryService.available ? BatteryService.percentage + "% · " + BatteryService.status : "Unavailable"}
                        ]
                        delegate: RowLayout {
                            id: netRow; required property var modelData
                            Layout.fillWidth: true; spacing: 8
                            Icon { icon: netRow.modelData.glyph; color: Theme.accent; font.pixelSize: 16 }
                            Text { text: netRow.modelData.label; color: Theme.foreground; font.pixelSize: 10; font.family: Fonts.poppinsSB.name; Layout.fillWidth: true }
                            Text { text: netRow.modelData.detail; color: Theme.muted; font.pixelSize: 10; elide: Text.ElideRight; Layout.maximumWidth: 170 }
                        }
                    }
                }
            }
        }
    }
}
