import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../../config"
import "../../services"
import "../../components"

// Layer Bottom puts cards behind normal application windows.
// Each card measures its own content; overflow scrolls on short displays.
PanelWindow {
    WlrLayershell.namespace: "rusticq-desktop-widgets"
    id: desktop
    // On the Bottom layer these windows would otherwise appear on ALL
    // workspaces. Filter using this monitor's active workspace, not global
    // focusedWorkspace (which is incorrect on dual-monitor setups).
    readonly property var hyprMonitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property int activeWorkspaceId: hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : -1
    readonly property bool interactiveWidget: kind === "notes" || kind === "kanban" || kind === "randomImage"
    readonly property bool workspaceAllowed: !interactiveWidget || SettingsStore.widgetAllowedOnWorkspace(kind, activeWorkspaceId)
    focusable: interactiveWidget
    visible: workspaceAllowed && ((kind === "calendar" && SettingsStore.desktopCalendar) ||
             (kind === "system" && SettingsStore.desktopSystem) ||
             (kind === "clock" && SettingsStore.desktopClock) ||
             (kind === "media" && SettingsStore.desktopMedia) ||
             (kind === "weather" && SettingsStore.desktopWeather) ||
             (kind === "connectivity" && SettingsStore.desktopConnectivity) ||
             (kind === "notes" && SettingsStore.desktopNotes) ||
             (kind === "kanban" && SettingsStore.desktopKanban) ||
             (kind === "randomImage" && SettingsStore.desktopRandomImage))
    anchors { top: true; left: true }
    property string kind: "clock"
    readonly property var storedPosition: SettingsStore.widgetPosition(kind, screen ? screen.name : "", activeWorkspaceId)
    readonly property var customSize: interactiveWidget ? SettingsStore.widgetSize(kind, screen ? screen.name : "", activeWorkspaceId) : null
    property real resizedWidth: -1
    property real resizedHeight: -1
    function saveSize() {
        SettingsStore.setWidgetSize(kind, screen ? screen.name : "", activeWorkspaceId, implicitWidth, implicitHeight);
        resizedWidth = -1;
        resizedHeight = -1;
    }
    readonly property var defaultPoint: ({
        clock: [20,76], calendar: [20,210], system: [20,510],
        media: [342,76], weather: [342,290], connectivity: [342,450],
        notes: [665,76], kanban: [665,340], randomImage: [1000,76]
    })[kind] || [20,76]
    readonly property real maxX: Math.max(0, (screen ? screen.width : 1280) - implicitWidth - 8)
    readonly property real maxY: Math.max(0, (screen ? screen.height : 900) - implicitHeight - 8)
    property real previewX: -1
    property real previewY: -1
    readonly property real anchorX: storedPosition ? storedPosition.x * maxX : Math.min(maxX, defaultPoint[0])
    readonly property real anchorY: storedPosition ? storedPosition.y * maxY : Math.min(maxY, defaultPoint[1])
    readonly property real positionX: Math.max(0, Math.min(maxX, previewX >= 0 ? previewX : anchorX))
    readonly property real positionY: Math.max(0, Math.min(maxY, previewY >= 0 ? previewY : anchorY))
    margins.left: Math.round(positionX)
    margins.top: Math.round(positionY)
    function savePosition() {
        SettingsStore.setWidgetPosition(kind, screen ? screen.name : "",
            maxX > 0 ? positionX/maxX : 0, maxY > 0 ? positionY/maxY : 0, activeWorkspaceId);
        previewX = -1;
        previewY = -1;
    }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    WlrLayershell.layer: WlrLayer.Bottom
    implicitWidth: resizedWidth >= 0 ? Math.round(resizedWidth) : customSize ? customSize.width :
        kind === "kanban" ? 410 : kind === "randomImage" ? 320 : kind === "notes" ? 340 : 302
    implicitHeight: resizedHeight >= 0 ? Math.round(resizedHeight) : customSize ? customSize.height :
        interactiveWidget ? (kind === "notes" ? 270 : kind === "kanban" ? 235 : 285) :
        Math.max(95, Math.min(cards.implicitHeight,
        desktop.screen ? Math.max(95, desktop.screen.height - 24) : 750))
    color: "transparent"

    readonly property var player: {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i) if (players[i].isPlaying) return players[i];
        return players.length ? players[0] : null;
    }
    readonly property bool hasPlayer: player !== null
    readonly property var cpuHistory: SysMonService.cpuHistory
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Item {
        id: dragHandle
        z: 20
        // Dragging is reserved for this handle, not an invisible full-width
        // layer stealing presses from TextInput, Kanban buttons or text selection.
        x: desktop.width - 36; y: 0
        width: 36
        height: 34
        // DragHandle is always on the top heading, not on media controls.
        DragHandler {
            id: moveGesture
            target: null
            acceptedButtons: Qt.LeftButton
            property real startX: 0
            property real startY: 0
            onActiveChanged: {
                if (active) {
                    startX = desktop.positionX;
                    startY = desktop.positionY;
                } else {
                    desktop.savePosition();
                }
            }
            onTranslationChanged: {
                if (!active) return;
                desktop.previewX = Math.max(0, Math.min(desktop.maxX, startX + translation.x));
                desktop.previewY = Math.max(0, Math.min(desktop.maxY, startY + translation.y));
            }
        }
        Icon {
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            icon: "\ue25d"
            color: Theme.contentMuted
            opacity: 0.8
            font.pixelSize: Fonts.scale(14)
        }
    }
    // Resize grip. It only receives pointer gestures from the bottom-right
    // corner; widgets can be resized independently for each workspace.
    Item {
        visible: desktop.interactiveWidget
        z: 40
        width: 29; height: 29
        anchors.right: parent.right; anchors.bottom: parent.bottom
        Icon { anchors.centerIn: parent; icon: "\ue3c6"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
        DragHandler {
            target: null
            acceptedButtons: Qt.LeftButton
            property real startWidth: 0
            property real startHeight: 0
            onActiveChanged: {
                if (active) { startWidth = desktop.implicitWidth; startHeight = desktop.implicitHeight; }
                else if (desktop.resizedWidth >= 0) desktop.saveSize();
            }
            onTranslationChanged: {
                if (!active) return;
                desktop.resizedWidth = Math.max(250, Math.min(1050, startWidth + translation.x));
                desktop.resizedHeight = Math.max(145, Math.min(800, startHeight + translation.y));
            }
        }
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
            spacing: 0

            Loader {
                active: desktop.kind === "notes"
                visible: active
                Layout.fillWidth: true
                Layout.preferredHeight: active ? Math.max(165, desktop.height) : 0
                sourceComponent: DesktopScratchpadCard {
                    monitorName: desktop.screen ? desktop.screen.name : ""
                    workspaceId: desktop.activeWorkspaceId
                }
            }
            Loader {
                active: desktop.kind === "kanban"
                visible: active
                Layout.fillWidth: true
                sourceComponent: DesktopNotesCard { boardKind: "kanban" }
            }
            Loader {
                active: desktop.kind === "randomImage"
                visible: active
                Layout.fillWidth: true
                sourceComponent: DesktopRandomImageCard {}
            }

            GlassSurface {
                Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
                border.width: Theme.surfaceBorderWidth("widgets","primary", 0)
                surfaceRole: "primary"
                visible: desktop.kind === "clock"
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? clockContent.implicitHeight + 2 * Theme.panelPadding : 0
                radius: Theme.surfaceRadius("widgets","primary", 17); color: Theme.surfaceColor("widgets","primary", Theme.background); border.color: Theme.surfaceBorder("widgets","primary", Theme.borderaccent)
                ColumnLayout {
                    id: clockContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true; spacing: 7
                        Icon { icon: "\ue8b5"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                        GlassLabel { text: "DESK CLOCK"; color: Theme.contentMuted; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10); Layout.fillWidth: true }
                    }
                    GlassLabel { text: Qt.formatDateTime(clock.date, "HH:mm"); color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(34); font.letterSpacing: -0.8; Layout.alignment: Qt.AlignHCenter }
                    GlassLabel { text: Qt.formatDate(clock.date, "dddd, dd MMMM yyyy"); color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); Layout.alignment: Qt.AlignHCenter }
                }
            }

            GlassSurface {
                Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
                border.width: Theme.surfaceBorderWidth("widgets","primary", 0)
                surfaceRole: "primary"
                visible: desktop.kind === "calendar"
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? calendarContent.implicitHeight + 2 * Theme.panelPadding : 0
                radius: Theme.surfaceRadius("widgets","primary", 17); color: Theme.surfaceColor("widgets","primary", Theme.background); border.color: Theme.surfaceBorder("widgets","primary", Theme.borderaccent)
                ColumnLayout {
                    id: calendarContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
                    spacing: 9
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: "\ue916"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            GlassLabel { text: "Calendar"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            GlassLabel { text: Qt.formatDate(clock.date, "MMMM yyyy"); color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                        }
                        Rectangle {
                            Layout.preferredWidth: 30; Layout.preferredHeight: 26; radius: Theme.glassRadius("card", 8)
                            color: Theme.glassColor("card", Qt.alpha(Theme.accent, .14))
                            GlassLabel { anchors.centerIn: parent; text: Qt.formatDate(clock.date, "dd"); color: Theme.accent; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppinsSB.name }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true; columns: 7; columnSpacing: 3; rowSpacing: 2
                        Repeater {
                            model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                            delegate: GlassLabel { required property string modelData; text: modelData; Layout.fillWidth: true; Layout.preferredHeight: 19; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: Theme.contentMuted; font.pixelSize: Fonts.scale(9) }
                        }
                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                id: dayChip; required property int index
                                readonly property int day: index - ((new Date(clock.date.getFullYear(), clock.date.getMonth(), 1).getDay() + 6) % 7) + 1
                                readonly property bool validDay: day >= 1 && day <= new Date(clock.date.getFullYear(),clock.date.getMonth()+1,0).getDate()
                                readonly property bool isToday: validDay && day === clock.date.getDate()
                                readonly property var dateNote: validDay ? SettingsStore.calendarNote(SettingsStore.calendarDateKey(
                                    new Date(clock.date.getFullYear(), clock.date.getMonth(), day))) : null
                                Layout.fillWidth: true; Layout.preferredHeight: 24; radius: Theme.glassRadius("card", 7)
                                color: Theme.glassColor("card", isToday ? Theme.accent : "transparent")
                                GlassLabel { anchors.centerIn: parent; text: dayChip.validDay ? String(dayChip.day) : ""; color: dayChip.isToday ? Theme.background : Theme.foreground; font.pixelSize: Fonts.scale(10) }
                                Rectangle {
                                    visible: dayChip.dateNote !== null
                                    width: 3; height: 3; radius: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 1
                                    color: dayChip.isToday ? Theme.background : Theme.calendarCategoryColor(dayChip.dateNote ? dayChip.dateNote.category : "event")
                                }
                            }
                        }
                    }
                }
            }

            GlassSurface {
                Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
                border.width: Theme.surfaceBorderWidth("widgets","primary", 0)
                surfaceRole: "primary"
                visible: desktop.kind === "system"
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? sysContent.implicitHeight + 2 * Theme.panelPadding : 0
                radius: Theme.surfaceRadius("widgets","primary", 17); color: Theme.surfaceColor("widgets","primary", Theme.background); border.color: Theme.surfaceBorder("widgets","primary", Theme.borderaccent)
                ColumnLayout {
                    id: sysContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: "\ue322"; font.pixelSize: Fonts.scale(18); color: Theme.accent }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            GlassLabel { text: "System monitor"; font.pixelSize: Fonts.scale(13); font.family: Fonts.poppinsSB.name; color: Theme.foreground }
                            GlassLabel { text: "Live usage · history"; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppins.name; color: Theme.contentMuted }
                        }
                        GlassLabel { text: "LIVE"; font.pixelSize: Fonts.scale(9); color: Theme.accent; font.family: Fonts.poppinsSB.name }
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
                                GlassLabel { text: meter.modelData.label; Layout.fillWidth: true; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                                GlassLabel { text: meter.modelData.value; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 3; color: Theme.glassColor("control", Theme.surface)
                                Rectangle { height: parent.height; width: Math.max(0,Math.min(1,meter.modelData.pct))*parent.width; radius: 3; color: Theme.accent }
                            }
                        }
                    }
                }
            }

            GlassSurface {
                Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
                border.width: Theme.surfaceBorderWidth("widgets","primary", 0)
                surfaceRole: "primary"
                visible: desktop.kind === "media"
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? mediaContent.implicitHeight + 2 * Theme.panelPadding : 0
                radius: Theme.surfaceRadius("widgets","primary", 17); color: Theme.surfaceColor("widgets","primary", Theme.background); border.color: Theme.surfaceBorder("widgets","primary", Theme.borderaccent)
                ColumnLayout {
                    id: mediaContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
                    spacing: 9
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: "\ue405"; color: Theme.accent; font.pixelSize: Fonts.scale(19) }
                        GlassLabel { text: "Now Playing"; Layout.fillWidth: true; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                        GlassLabel { text: desktop.hasPlayer ? desktop.player.identity : "Idle"; color: Theme.contentMuted; font.pixelSize: Fonts.scale(9); elide: Text.ElideRight; Layout.maximumWidth: 90 }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 57; radius: Theme.glassRadius("card", 11); color: Theme.glassColor("card", Theme.surface)
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 9
                            Rectangle { Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: Theme.glassRadius("card", 10); color: Theme.glassColor("card", Qt.alpha(Theme.accent, .12)); Icon { anchors.centerIn: parent; icon: "\ue405"; font.pixelSize: Fonts.scale(23); color: Theme.accent } }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                GlassLabel { Layout.fillWidth: true; text: desktop.hasPlayer ? (desktop.player.trackTitle || "Unknown track") : "Nothing playing"; elide: Text.ElideRight; color: Theme.foreground; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppinsSB.name }
                                GlassLabel { Layout.fillWidth: true; text: desktop.hasPlayer ? (desktop.player.trackArtist || "Unknown artist") : "Open a music player"; elide: Text.ElideRight; color: Theme.contentMuted; font.pixelSize: Fonts.scale(10) }
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
                                Layout.preferredWidth: 38; Layout.preferredHeight: 34; radius: Theme.glassRadius("card", 10); color: Theme.glassColor("card", Theme.surface)
                                Icon { anchors.centerIn: parent; icon: mediaButton.modelData.glyph; font.pixelSize: Fonts.scale(20); color: Theme.foreground }
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

            GlassSurface {
                Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
                border.width: Theme.surfaceBorderWidth("widgets","primary", 0)
                surfaceRole: "primary"
                visible: desktop.kind === "weather"
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? weatherContent.implicitHeight + 2 * Theme.panelPadding : 0
                radius: Theme.surfaceRadius("widgets","primary", 17); color: Theme.surfaceColor("widgets","primary", Theme.background); border.color: Theme.surfaceBorder("widgets","primary", Theme.borderaccent)
                ColumnLayout {
                    id: weatherContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: WeatherService.icon; color: Theme.accent; font.pixelSize: Fonts.scale(24) }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            GlassLabel { text: "Weather"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            GlassLabel { text: WeatherService.location || "Location unavailable"; color: Theme.contentMuted; font.pixelSize: Fonts.scale(10); elide: Text.ElideRight }
                        }
                        GlassLabel { text: WeatherService.temperature || "--"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(18) }
                    }
                    GlassLabel { text: WeatherService.condition || "Weather information unavailable"; color: Theme.foreground; font.pixelSize: Fonts.scale(11); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    GlassLabel { text: "Feels like " + (WeatherService.feelsLike || "--"); color: Theme.contentMuted; font.pixelSize: Fonts.scale(10) }
                }
            }

            GlassSurface {
                Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
                border.width: Theme.surfaceBorderWidth("widgets","primary", 0)
                surfaceRole: "primary"
                visible: desktop.kind === "connectivity"
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? networkContent.implicitHeight + 2 * Theme.panelPadding : 0
                radius: Theme.surfaceRadius("widgets","primary", 17); color: Theme.surfaceColor("widgets","primary", Theme.background); border.color: Theme.surfaceBorder("widgets","primary", Theme.borderaccent)
                ColumnLayout {
                    id: networkContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panelPadding }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Icon { icon: "\ue1d8"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                        GlassLabel { text: "Connectivity"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: Fonts.scale(13); font.family: Fonts.poppinsSB.name }
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
                            Icon { icon: netRow.modelData.glyph; color: Theme.accent; font.pixelSize: Fonts.scale(16) }
                            GlassLabel { text: netRow.modelData.label; color: Theme.foreground; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppinsSB.name; Layout.fillWidth: true }
                            GlassLabel { text: netRow.modelData.detail; color: Theme.contentMuted; font.pixelSize: Fonts.scale(10); elide: Text.ElideRight; Layout.maximumWidth: 170 }
                        }
                    }
                }
            }
        }
    }
}
