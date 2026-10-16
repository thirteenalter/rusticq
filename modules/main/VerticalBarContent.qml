import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../../components"
import "../../config"
import "../../services"

// A real vertical layout (not a rotated horizontal bar). The side rail
// uses icon-only controls and opens the same mini widgets as the top bar.
Item {
    id: root
    required property var hostWindow
    signal requestPopup(string kind, real localX, real localY)
    function popup(kind, item) {
        const point = hostWindow.mapFromItem(item, item.width / 2, item.height / 2);
        requestPopup(kind, point.x, point.y);
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }
    readonly property bool soundAvailable: sink !== null && sink.audio !== null

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 12

        Rectangle {
            id: launch
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            color: Theme.surface
            radius: 12
            Icon { anchors.centerIn: parent; icon: "\ueb8e"; font.pixelSize: 19; color: Theme.accent }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.hostWindow.closeMini(); Store.toggleAi(root.hostWindow.screen); }
            }
        }

        Flickable {
            id: railScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: railContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: railContent
                width: railScroll.width
                spacing: 12

        ColumnLayout {
            visible: SettingsStore.showWorkspaces
            Layout.alignment: Qt.AlignHCenter
            spacing: 5
            Repeater {
                model: 6
                delegate: Rectangle {
                    id: workspaceButton
                    required property int index
                    readonly property int workspaceId: index + 1
                    readonly property bool selected: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 30
                    radius: 9
                    color: selected ? Theme.accent : Theme.surface
                    Text {
                        anchors.centerIn: parent
                        text: workspaceButton.workspaceId
                        font.family: Fonts.poppins.name
                        font.pixelSize: 11
                        color: workspaceButton.selected ? Theme.background : Theme.foreground
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const target = String(workspaceButton.workspaceId);
                            Hyprland.dispatch(Hyprland.usingLua
                                ? 'hl.dsp.focus({ workspace = "' + target + '" })'
                                : 'workspace ' + target);
                        }
                    }
                }
            }
        }

        // Maintain a large middle gap on tall screens, but allow scrolling
        // on short displays instead of clipping workspaces or indicators.
        Item { Layout.preferredHeight: Math.max(12, railScroll.height - 590) }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 9
            Rectangle {
                id: weatherButton
                visible: SettingsStore.showWeather
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 42
                Layout.preferredHeight: 38
                radius: 10
                color: Theme.surface
                Icon { anchors.centerIn: parent; icon: WeatherService.icon; font.pixelSize: 20; color: Theme.foreground }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup("weather", weatherButton) }
            }
            Rectangle {
                id: timeButton
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 46
                Layout.preferredHeight: 43
                radius: 10
                color: Theme.surface
                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: "\ue8b5"; font.pixelSize: 17 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "HH:mm"); font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.foreground }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup("time", timeButton) }
            }
            Rectangle {
                id: dateButton
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 46
                Layout.preferredHeight: 39
                radius: 10
                color: Theme.surface
                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: "\uebcc"; font.pixelSize: 17 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "dd/MM"); font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.foreground }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup("date", dateButton) }
            }
        }

        ColumnLayout {
            visible: SettingsStore.showIndicators
            Layout.alignment: Qt.AlignHCenter
            spacing: 7
            Repeater {
                model: [
                    { kind: "bluetooth", glyph: BluetoothService.icon, available: true },
                    { kind: "wifi", glyph: WifiService.icon, available: true },
                    { kind: "battery", glyph: BatteryService.icon, available: BatteryService.available },
                    { kind: "audio", glyph: !root.soundAvailable || root.sink.audio.muted ? "\ue04f" : "\ue050", available: true }
                ]
                delegate: Rectangle {
                    id: statusButton
                    required property var modelData
                    visible: modelData.available
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: visible ? 36 : 0
                    radius: 10
                    color: Theme.surface
                    Icon { anchors.centerIn: parent; icon: statusButton.modelData.glyph; font.pixelSize: 19; color: Theme.foreground }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup(statusButton.modelData.kind, statusButton) }
                }
            }
        }

            }
        }

        Rectangle {
            id: settingsButton
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 42
            Layout.preferredHeight: 40
            radius: 12
            color: Theme.surface
            Icon { anchors.centerIn: parent; icon: "\ue69b"; font.pixelSize: 20; color: Theme.accent }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.hostWindow.closeMini(); Store.toggleQuick(root.hostWindow.screen); }
            }
        }
    }
}
