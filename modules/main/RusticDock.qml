import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"

// Optional dock: pointer at bottom handle reveals apps; no app auto-launch.
PanelWindow {
    id: dock
    visible: SettingsStore.showDock
    anchors { bottom: true; left: true }
    margins.left: dock.screen ? Math.max(0, Math.round((dock.screen.width - implicitWidth) / 2)) : 0
    exclusionMode: ExclusionMode.Ignore
    margins.bottom: SettingsStore.barPosition === "bottom" ? 53 : 6
    implicitWidth: 336
    implicitHeight: expanded ? 64 : 9
    color: "transparent"
    property bool expanded: !SettingsStore.dockAutoHide
    onVisibleChanged: if (visible) expanded = !SettingsStore.dockAutoHide
    Connections {
        target: SettingsStore
        function onDockAutoHideChanged() { dock.expanded = !SettingsStore.dockAutoHide; }
    }
    Timer { id: hideLater; interval: 600; onTriggered: if (SettingsStore.dockAutoHide) dock.expanded = false }
    Rectangle {
        anchors.fill: parent
        color: dock.expanded ? Theme.background : Qt.alpha(Theme.accent, .65)
        radius: dock.expanded ? 18 : 4
        border.width: dock.expanded ? 1 : 0
        border.color: Theme.borderaccent
        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) { hideLater.stop(); dock.expanded = true; }
                else if (SettingsStore.dockAutoHide) hideLater.start();
            }
        }
        RowLayout {
            visible: dock.expanded
            anchors.centerIn: parent; spacing: 11
            Repeater {
                model: [
                    {icon:"\ue2c7",label:"Files",enabled:SettingsStore.dockFiles,command:["sh", "-c", "xdg-open \"$HOME\""]},
                    {icon:"\ue80b",label:"Browser",enabled:SettingsStore.dockBrowser,command:["xdg-open", "https://www.google.com"]},
                    {icon:"\ue8b8",label:"Settings",enabled:SettingsStore.dockSettings,command:[]},
                    {icon:"\uf190",label:"Task View",enabled:SettingsStore.dockTaskView,command:[]},
                    {icon:"\ue8f4",label:"AI",enabled:SettingsStore.dockAI,command:[]}
                ]
                delegate: Rectangle {
                    id: app
                    required property var modelData
                    visible: modelData.enabled
                    Layout.preferredWidth: 47; Layout.preferredHeight: 47
                    radius: 13; color: mouse.containsMouse ? Qt.alpha(Theme.accent, .2) : Theme.surface
                    Icon { anchors.centerIn: parent; icon: app.modelData.icon; color: Theme.accent; font.pixelSize: 23 }
                    MouseArea {
                        id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (app.modelData.label === "Settings") Store.showSettings("bar");
                            else if (app.modelData.label === "Task View") Store.taskViewVisible = !Store.taskViewVisible;
                            else if (app.modelData.label === "AI") Store.toggleAi(dock.screen);
                            else Quickshell.execDetached(app.modelData.command);
                        }
                    }
                }
            }
        }
    }
}
