import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../config"
import "../../components"

// Optional dock. Running apps are real Hyprland GUI windows (not /proc tasks).
PanelWindow {
    id: dock
    visible: SettingsStore.showDock
    anchors { bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    margins.bottom: SettingsStore.barPosition === "bottom" ? 54 : 8
    margins.left: dock.screen ? Math.max(0, Math.round((dock.screen.width - implicitWidth) / 2)) : 0
    property bool expanded: !SettingsStore.dockAutoHide
    // Hyprland -j clients is reliable on Lua-based Omarchy too. Count only
    // actual visible GUI app entries: never reserve space for hidden delegates.
    property var runningApps: []
    property string runningError: ""
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
                    dock.runningApps = data.apps || [];
                    dock.runningError = "";
                } catch (err) {
                    dock.runningApps = [];
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
    implicitWidth: expanded ? Math.min(dock.screen ? Math.max(82, dock.screen.width - 24) : 860, Math.max(82, desiredDockWidth)) : 82
    implicitHeight: expanded ? 94 : 18
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
            else { dock.runningApps = []; dock.runningError = ""; }
        }
    }
    Timer { id: hideLater; interval: 700; onTriggered: if (SettingsStore.dockAutoHide) dock.expanded = false }

    Rectangle {
        anchors.fill: parent
        radius: dock.expanded ? 22 : 9
        color: dock.expanded ? Qt.alpha(Theme.background, 0.97) : Qt.alpha(Theme.accent, 0.72)
        border.width: dock.expanded ? 1 : 0
        border.color: Theme.borderaccent
        HoverHandler {
            onHoveredChanged: {
                if (hovered) { hideLater.stop(); dock.expanded = true; }
                else if (SettingsStore.dockAutoHide) hideLater.start();
            }
        }
        ColumnLayout {
            visible: dock.expanded
            anchors.fill: parent
            anchors.margins: dock.dockPadding
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
                            {icon:"\uf190",label:"Monitor",enabled:SettingsStore.dockTaskView,command:[],action:"system-monitor"},
                            {icon:"\ue8f4",label:"AI",enabled:SettingsStore.dockAI,command:[]}
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
                                radius: 14
                                color: mouse.containsMouse ? Qt.alpha(Theme.accent, .18) : Theme.surface
                                Icon { anchors.centerIn: parent; icon: app.modelData.icon; color: Theme.accent; font.pixelSize: 23 }
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
                            Text { text: app.modelData.label; Layout.alignment: Qt.AlignHCenter; font.pixelSize: 9; color: Theme.muted; font.family: Fonts.poppins.name }
                        }
                    }
                    Rectangle { visible: SettingsStore.dockRunningApps && dock.runningCount > 0; Layout.preferredWidth: visible ? 1 : 0; Layout.preferredHeight: 36; color: Theme.borderaccent }
                    Repeater {
                        model: SettingsStore.dockRunningApps ? dock.runningApps : []
                        delegate: ColumnLayout {
                            id: runningApp
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
                                radius: 14
                                color: activeArea.containsMouse ? Qt.alpha(Theme.accent, .20) : Theme.surface
                                border.width: runningApp.modelData.active ? 1 : 0
                                border.color: Theme.accent
                                IconImage {
                                    id: activeIcon
                                    anchors.centerIn: parent
                                    width: 29; height: 29
                                    source: Quickshell.iconPath(runningApp.iconName, true)
                                }
                                Icon {
                                    visible: activeIcon.status === Image.Error || runningApp.iconName === ""
                                    anchors.centerIn: parent
                                    icon: "\ue80b"
                                    font.pixelSize: 21
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
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 50
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: runningApp.appName
                                color: runningApp.modelData.active ? Theme.accent : Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: 8
                            }
                        }
                    }
                }
            }
        }
        Rectangle { visible: !dock.expanded; anchors.centerIn: parent; width: 42; height: 6; radius: 3; color: Theme.background }
    }
}
