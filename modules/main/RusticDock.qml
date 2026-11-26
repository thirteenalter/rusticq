import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import "../../config"
import "../../components"

// Optional dock. Running apps are real Hyprland GUI windows (not /proc tasks).
PanelWindow {
    WlrLayershell.namespace: "rusticq-dock"
    id: dock
    visible: motion.presented
    property bool firstFrameReady: false
    onBackingWindowVisibleChanged: if (!backingWindowVisible) firstFrameReady = false
    Connections {
        target: dock.contentItem.Window.window
        enabled: SettingsStore.showDock && !dock.firstFrameReady
        function onFrameSwapped() { dock.firstFrameReady = true; }
    }
    SurfaceMotion { id: motion; shown: SettingsStore.showDock; target: dock.contentItem; edge: "bottom"; closedScale: 1; startReady: dock.firstFrameReady; animate: Theme.motionEnabled && !SettingsStore.lowMemoryShellMode }
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    margins.bottom: SettingsStore.barPosition === "bottom" ? 54 : 8
    margins.left: dock.screen ? Math.max(0, Math.round((dock.screen.width - implicitWidth) / 2)) : 0
    property bool expanded: !SettingsStore.dockAutoHide
    // Hyprland -j clients is reliable on Lua-based Omarchy too. Count only
    // actual visible GUI app entries: never reserve space for hidden delegates.
    property var runningApps: []
    property string runningError: ""
    property string runningSnapshot: "[]"
    readonly property int runningCount: SettingsStore.dockRunningApps ? runningApps.length : 0
    // Measure rendered delegates, not estimated icon counts. The same 10px
    // padding is added on the left and right of the visible content.
    readonly property int dockPadding: 10
    readonly property int desiredDockWidth: Math.ceil(contentRow.implicitWidth) + dockPadding * 2
    Process {
        id: clientsProcess
        command: ["python3", Quickshell.shellPath("scripts/rustiq-running-apps.py"), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    if (!data.ok) throw new Error(data.error || "Hyprland clients unavailable");
                    const next = data.apps || [];
                    const snapshot = JSON.stringify(next);
                    if (snapshot !== dock.runningSnapshot) {
                        dock.runningSnapshot = snapshot;
                        dock.runningApps = next;
                    }
                    dock.runningError = "";
                } catch (err) {
                    dock.runningApps = [];
                    dock.runningSnapshot = "[]";
                    dock.runningError = String(err);
                    console.warn("RusticQ dock running apps: " + err);
                }
            }
        }
    }
    function refreshRunningApps() {
        if (dock.visible && SettingsStore.dockRunningApps && !clientsProcess.running)
            clientsProcess.running = true;
    }
    Timer {
        interval: 2500
        repeat: true
        running: dock.visible && SettingsStore.dockRunningApps
        triggeredOnStart: true
        onTriggered: dock.refreshRunningApps()
    }
    // Reserve the expanded native buffer once. Only the QML surface animates;
    // hover must not resize/recenter a Wayland window on every frame.
    readonly property int expandedWidth: Math.min(dock.screen ? Math.max(82, dock.screen.width - 24) : 860, Math.max(82, desiredDockWidth))
    implicitWidth: expandedWidth
    implicitHeight: 94
    mask: Region { item: SettingsStore.showDock ? dockSurface : null }
    color: "transparent"
    onVisibleChanged: if (visible) {
        expanded = !SettingsStore.dockAutoHide;
        if (SettingsStore.dockRunningApps) dock.refreshRunningApps();
    }
    Connections {
        target: SettingsStore
        function onDockAutoHideChanged() { dock.expanded = !SettingsStore.dockAutoHide; }
        function onDockRunningAppsChanged() {
            if (SettingsStore.dockRunningApps) dock.refreshRunningApps();
            else { dock.runningApps = []; dock.runningSnapshot = "[]"; dock.runningError = ""; }
        }
    }
    Timer { id: hideLater; interval: 700; onTriggered: if (SettingsStore.dockAutoHide) dock.expanded = false }

    GlassSurface {
        id: dockSurface
        objectName: "dockSurface"
        surfaceRole: "primary"
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: dock.expanded ? dock.expandedWidth : 82
        height: dock.expanded ? 94 : 18
        Behavior on width { enabled: Theme.motionEnabled && !SettingsStore.lowMemoryShellMode; NumberAnimation { duration: Theme.motionEnterDuration; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: Theme.motionEnabled && !SettingsStore.lowMemoryShellMode; NumberAnimation { duration: Theme.motionEnterDuration; easing.type: Easing.OutCubic } }
        clip: true
        transform: Translate { x: motion.offsetX; y: motion.offsetY }
        radius: Theme.surfaceRadius("dock","primary", dock.expanded ? 22 : 9)
        color: Theme.surfaceColor("dock","primary", dock.expanded ? Qt.alpha(Theme.background, 0.97) : Qt.alpha(Theme.accent, 0.72))
        border.width: Theme.surfaceBorderWidth("dock","primary", dock.expanded ? 1 : 0)
        border.color: Theme.surfaceBorder("dock","primary", Theme.borderaccent)
        Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
        Behavior on radius { enabled: Theme.motionEnabled; NumberAnimation { duration: Theme.motionEnterDuration; easing.type: Easing.OutCubic } }
        HoverHandler {
            onHoveredChanged: {
                if (hovered) { hideLater.stop(); dock.expanded = true; }
                else if (SettingsStore.dockAutoHide) hideLater.start();
            }
        }
        SurfaceMotion {
            id: contentMotion
            shown: dock.expanded
            target: dockContents
            style: "fade"
            animate: Theme.motionEnabled && !SettingsStore.lowMemoryShellMode
        }
        ColumnLayout {
            id: dockContents
            objectName: "dockContents"
            // Keep layout/icon geometry stable while its clipped surface shrinks.
            // Zero opacity culls drawing; SurfaceMotion releases input on close.
            x: (parent.width - width) / 2
            y: dock.dockPadding
            width: dock.expandedWidth - dock.dockPadding * 2
            height: 94 - dock.dockPadding * 2
            spacing: 6
            Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 48; Layout.preferredHeight: 5; radius: 3; color: Qt.alpha(Theme.foreground, 0.18) }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: contentRow.implicitWidth
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                RowLayout {
                    id: contentRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.round((parent.width - implicitWidth) / 2))
                    spacing: 8
                    Repeater {
                        model: [
                            {icon:"\ue8b6",label:"Launcher",enabled:true,command:[]},
                            {icon:"\ue2c7",label:"Files",enabled:SettingsStore.dockFiles,command:["sh", "-c", "xdg-open \"$HOME\""]},
                            {icon:"\ue80b",label:"Browser",enabled:SettingsStore.dockBrowser,command:["sh", "-c", "xdg-open https://www.google.com"]},
                            {icon:"\ue8b8",label:"Settings",enabled:SettingsStore.dockSettings,command:[]},
                            {icon:"\uf500",label:"Monitor",enabled:SettingsStore.dockTaskView,command:[],action:"system-monitor"},
                            {icon:"\uf371",label:"AI",enabled:SettingsStore.dockAI,command:[]}
                        ]
                        delegate: ColumnLayout {
                            id: app
                            required property var modelData
                            visible: modelData.enabled
                            Layout.preferredWidth: visible ? 50 : 0
                            spacing: 3
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 46; Layout.preferredHeight: 46
                                radius: Theme.glassRadius("card", 14)
                                color: Theme.glassColor("card", mouse.containsMouse ? Qt.alpha(Theme.accent, .18) : Theme.surface)
                                scale: mouse.pressed ? 0.96 : mouse.containsMouse ? 1.04 : 1
                                Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
                                Behavior on scale { enabled: Theme.motionEnabled; NumberAnimation { duration: Theme.motionFastDuration; easing.type: Easing.OutCubic } }
                                RusticQIcon { anchors.centerIn: parent; iconSize: 23; visible: app.modelData.label === "Settings" }
                                Icon { anchors.centerIn: parent; visible: app.modelData.label !== "Settings"; icon: app.modelData.icon; color: Theme.accent; font.pixelSize: Fonts.scale(23) }
                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (app.modelData.label === "Launcher") Store.toggleLauncher(dock.screen);
                                        else if (app.modelData.label === "Settings") Store.showSettings("dock");
                                        else if (app.modelData.action === "system-monitor") Store.systemMonitorVisible = true;
                                        else if (app.modelData.label === "AI") Store.toggleAi(dock.screen);
                                        else Quickshell.execDetached(app.modelData.command);
                                    }
                                }
                            }
                            GlassLabel { text: app.modelData.label; Layout.alignment: Qt.AlignHCenter; font.pixelSize: Fonts.scale(9); color: Theme.contentMuted; font.family: Fonts.poppins.name }
                        }
                    }
                    Item { visible: SettingsStore.dockRunningApps && dock.runningCount > 0; Layout.preferredWidth: visible ? Theme.sectionGap : 0; Layout.preferredHeight: 36 }
                    Repeater {
                        model: SettingsStore.dockRunningApps ? dock.runningApps : []
                        delegate: ColumnLayout {
                            id: runningApp
                            objectName: "dockRunningApp_" + String(modelData.appId || "")
                            required property var modelData
                            readonly property string appKey: String(modelData.appId || "")
                            readonly property var entry: DesktopEntries.heuristicLookup(appKey)
                            readonly property string appName: entry && entry.name ? String(entry.name) : appKey
                            readonly property string iconName: entry && entry.icon ? String(entry.icon) : appKey
                            Layout.preferredWidth: 50
                            spacing: 3
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 46; Layout.preferredHeight: 46
                                radius: Theme.glassRadius("card", 14)
                                color: Theme.glassColor("card", activeArea.containsMouse ? Qt.alpha(Theme.accent, .20) : Theme.surface)
                                scale: activeArea.pressed ? 0.96 : activeArea.containsMouse ? 1.04 : 1
                                Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
                                Behavior on scale { enabled: Theme.motionEnabled; NumberAnimation { duration: Theme.motionFastDuration; easing.type: Easing.OutCubic } }
                                border.width: Theme.glassBorderWidth("card", runningApp.modelData.active ? 1 : 0)
                                border.color: Theme.glassBorder("card", Theme.accent)
                                IconImage {
                                    id: activeIcon
                                    anchors.centerIn: parent
                                    width: 29; height: 29
                                    asynchronous: true
                                    source: Quickshell.iconPath(runningApp.iconName, true)
                                }
                                Icon {
                                    visible: activeIcon.status === Image.Error || runningApp.iconName === ""
                                    anchors.centerIn: parent
                                    icon: "\ue80b"
                                    font.pixelSize: Fonts.scale(21)
                                    color: Theme.accent
                                }
                                MouseArea {
                                    id: activeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached([
                                        "python3", Quickshell.shellPath("scripts/rustiq-running-apps.py"),
                                        "focus", runningApp.modelData.address
                                    ])
                                }
                            }
                            GlassLabel {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 50
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: runningApp.appName
                                color: runningApp.modelData.active ? Theme.accent : Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(8)
                            }
                        }
                    }
                }
            }
        }
        Rectangle { visible: contentMotion.progress < 1; opacity: 1 - contentMotion.surfaceOpacity; anchors.centerIn: parent; width: 42; height: 6; radius: 3; color: Theme.background }
    }
}
