import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../../components"
import "../../config"
import "../../services"

// All five bar modes work on either vertical edge. Every mode shares the
// same sources and popup actions; only geometry, hierarchy and density vary.
Item {
    id: root
    required property var hostWindow
    signal requestPopup(string kind, real localX, real localY)
    signal requestMenu(string section, var sourceItem)
    readonly property string mode: SettingsStore.barMode
    readonly property bool simple: mode === "simple"
    readonly property bool clean: mode === "clean-compact"
    readonly property bool compact: clean || mode === "compact"
    readonly property bool separated: mode === "separated"
    readonly property bool professional: mode === "professional"
    readonly property int controlSize: clean ? 30 : compact ? 34 : professional ? 44 : simple ? 34 : 40
    readonly property int controlGap: clean ? 3 : compact ? 5 : professional ? 10 : simple ? 6 : 8
    readonly property int workspaceCount: 6
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool soundAvailable: sink !== null && sink.audio !== null
    PwObjectTracker { objects: [root.sink] }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    function popup(kind, item) {
        const p = hostWindow.mapFromItem(item, item.width / 2, item.height / 2);
        requestPopup(kind, p.x, p.y);
    }

    // Each side maintains a valid, scrollable vertical rail, even on short screens.
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.clean ? 4 : 6
        anchors.rightMargin: root.clean ? 4 : 6
        anchors.topMargin: root.clean ? 5 : 7
        anchors.bottomMargin: root.clean ? 5 : 7
        spacing: root.controlGap

        Rectangle {
            id: launcher
            visible: SettingsStore.showArch
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.controlSize
            Layout.preferredHeight: root.controlSize
            color: root.clean ? "transparent" : root.separated ? Theme.surface : Qt.alpha(Theme.accent, root.professional ? 0.19 : 0.09)
            radius: root.professional ? 7 : 11
            Icon { anchors.centerIn: parent; icon: "\ueb8e"; font.pixelSize: 19; color: Theme.accent }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { root.hostWindow.closeMini(); Store.toggleAi(root.hostWindow.screen) }
            }
        }

        Rectangle {
            id: launcherSearch
            visible: SettingsStore.showLauncher
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.controlSize
            Layout.preferredHeight: root.controlSize
            color: root.clean ? "transparent" : root.separated ? Theme.surface : Qt.alpha(Theme.accent, 0.10)
            radius: root.professional ? 7 : 11
            Icon { anchors.centerIn: parent; icon: "\ue8b6"; font.pixelSize: 19; color: Theme.accent }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { root.hostWindow.closeMini(); Store.toggleLauncher(root.hostWindow.screen); }
            }
        }

        ContextMenuBar {
            id: railMenu
            visible: SettingsStore.showMenuBar
            vertical: true
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: visible ? root.controlSize : 0
            Layout.preferredHeight: visible ? root.controlSize : 0
            onMenuRequested: (section, item) => root.requestMenu(section, item)
        }

        // The separating line is only present in Professional mode, as in
        // the solid desktop bar. Separated mode instead uses rounded islands.
        Rectangle {
            visible: root.professional
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 1 : 0
            color: Qt.alpha(Theme.accent, 0.38)
        }

        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: railContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ColumnLayout {
                id: railContent
                width: scroll.width
                spacing: root.separated ? 14 : root.controlGap + 3

                Rectangle {
                    id: workspaceIsland
                    visible: SettingsStore.showWorkspaces && !root.simple
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.separated ? root.controlSize + 5 : scroll.width
                    Layout.preferredHeight: visible ? workspaceColumn.implicitHeight + (root.separated ? 12 : 0) : 0
                    color: root.separated ? Theme.surface : "transparent"
                    radius: 12
                    ColumnLayout {
                        id: workspaceColumn
                        anchors.centerIn: parent
                        spacing: root.compact ? 2 : 5
                        Repeater {
                            model: root.workspaceCount
                            delegate: Rectangle {
                                id: workspaceButton
                                required property int index
                                readonly property int workspaceId: index + 1
                                readonly property bool selected: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: root.controlSize - (root.clean ? 4 : 6)
                                Layout.preferredHeight: root.compact ? 25 : 29
                                radius: root.clean ? 6 : 8
                                color: selected ? Theme.accent : root.clean ? "transparent" : root.separated ? Theme.background : Theme.surface
                                Text {
                                    anchors.centerIn: parent
                                    text: workspaceButton.workspaceId
                                    font.family: Fonts.poppins.name
                                    font.pixelSize: 11
                                    color: workspaceButton.selected ? Theme.background : Theme.foreground
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
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
                }

                Rectangle {
                    visible: root.professional || root.separated
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 1 : 0
                    color: root.professional ? Qt.alpha(Theme.accent, .35) : "transparent"
                }
                Rectangle {
                    id: infoIsland
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.separated ? root.controlSize + 5 : scroll.width
                    Layout.preferredHeight: infoColumn.implicitHeight + (root.separated ? 12 : 0)
                    color: root.separated ? Theme.surface : "transparent"
                    radius: 12
                    ColumnLayout {
                        id: infoColumn
                        anchors.centerIn: parent
                        spacing: root.controlGap
                        Rectangle {
                            id: weatherButton
                            visible: !root.simple && SettingsStore.showWeather
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: root.controlSize
                            Layout.preferredHeight: visible ? root.controlSize : 0
                            radius: root.professional ? 7 : 10
                            color: root.clean ? "transparent" : root.separated ? Theme.background : Theme.surface
                            Icon { anchors.centerIn: parent; icon: WeatherService.icon; font.pixelSize: 19; color: Theme.foreground }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup("weather", weatherButton) }
                        }
                        Rectangle {
                            id: timeButton
                            visible: SettingsStore.showTime
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: root.controlSize
                            Layout.preferredHeight: root.controlSize + (root.compact ? 6 : 9)
                            radius: root.professional ? 7 : 10
                            color: root.clean ? "transparent" : root.separated ? Theme.background : Theme.surface
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: "\ue8b5"; font.pixelSize: 17 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "HH:mm"); font.family: Fonts.poppins.name; font.pixelSize: 9; color: Theme.foreground }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup("time", timeButton) }
                        }
                        Rectangle {
                            id: dateButton
                            visible: !root.simple && SettingsStore.showDate
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: root.controlSize
                            Layout.preferredHeight: visible ? root.controlSize + 4 : 0
                            radius: root.professional ? 7 : 10
                            color: root.clean ? "transparent" : root.separated ? Theme.background : Theme.surface
                            Column {
                                anchors.centerIn: parent; spacing: 0
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: "\uebcc"; font.pixelSize: 16 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "dd/MM"); font.family: Fonts.poppins.name; font.pixelSize: 9; color: Theme.foreground }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup("date", dateButton) }
                        }
                    }
                }
                Rectangle {
                    visible: root.professional || root.separated
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 1 : 0
                    color: root.professional ? Qt.alpha(Theme.accent, .35) : "transparent"
                }
                Rectangle {
                    id: systemIsland
                    visible: !root.simple && SettingsStore.showIndicators && (SettingsStore.showWifi || SettingsStore.showBluetooth || SettingsStore.showBattery || SettingsStore.showAudio)
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.separated ? root.controlSize + 5 : scroll.width
                    Layout.preferredHeight: visible ? systemColumn.implicitHeight + (root.separated ? 12 : 0) : 0
                    color: root.separated ? Theme.surface : "transparent"
                    radius: 12
                    ColumnLayout {
                        id: systemColumn
                        anchors.centerIn: parent; spacing: root.controlGap
                        Repeater {
                            model: [
                                { kind: "bluetooth", glyph: BluetoothService.icon, available: SettingsStore.showBluetooth },
                                { kind: "wifi", glyph: WifiService.icon, available: SettingsStore.showWifi },
                                { kind: "battery", glyph: BatteryService.icon, available: SettingsStore.showBattery && BatteryService.available },
                                { kind: "audio", glyph: !root.soundAvailable || root.sink.audio.muted ? "\ue04f" : "\ue050", available: SettingsStore.showAudio }
                            ]
                            delegate: Rectangle {
                                id: statusButton
                                required property var modelData
                                visible: modelData.available
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: root.controlSize
                                Layout.preferredHeight: visible ? root.controlSize : 0
                                radius: root.professional ? 7 : 10
                                color: root.clean ? "transparent" : root.separated ? Theme.background : Theme.surface
                                Icon { anchors.centerIn: parent; icon: statusButton.modelData.glyph; font.pixelSize: 19; color: Theme.foreground }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup(statusButton.modelData.kind, statusButton) }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: taskButtonVertical
            visible: SettingsStore.showTaskView && !root.simple
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.controlSize
            Layout.preferredHeight: visible ? root.controlSize : 0
            radius: 10; color: root.clean ? "transparent" : Theme.surface
            Icon { anchors.centerIn: parent; icon: "\uf190"; color: Theme.accent; font.pixelSize: 19 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup("task", taskButtonVertical) }
        }

        Rectangle {
            id: quickButton
            visible: SettingsStore.showQuickControl
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.controlSize
            Layout.preferredHeight: root.controlSize
            radius: root.professional ? 7 : 11
            color: root.clean ? "transparent" : Theme.surface
            Icon { anchors.centerIn: parent; icon: "\ue69b"; font.pixelSize: 20; color: Theme.accent }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { root.hostWindow.closeMini(); Store.toggleQuick(root.hostWindow.screen) }
            }
        }
    }
}
