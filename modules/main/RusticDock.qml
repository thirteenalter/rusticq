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
    margins.bottom: SettingsStore.barPosition === "bottom" ? 54 : 10
    implicitWidth: expanded ? 392 : 78
    implicitHeight: expanded ? 76 : 16
    color: "transparent"
    property bool expanded: !SettingsStore.dockAutoHide
    onVisibleChanged: if (visible) expanded = !SettingsStore.dockAutoHide
    Connections {
        target: SettingsStore
        function onDockAutoHideChanged() { dock.expanded = !SettingsStore.dockAutoHide; }
    }
    Timer { id: hideLater; interval: 650; onTriggered: if (SettingsStore.dockAutoHide) dock.expanded = false }

    Rectangle {
        anchors.fill: parent
        radius: expanded ? 22 : 9
        color: expanded ? Qt.alpha(Theme.background, 0.97) : Qt.alpha(Theme.accent, 0.72)
        border.width: expanded ? 1 : 0
        border.color: Theme.borderaccent

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) { hideLater.stop(); dock.expanded = true; }
                else if (SettingsStore.dockAutoHide) hideLater.start();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: expanded ? 9 : 0
            spacing: 6

            Rectangle {
                visible: dock.expanded
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 5
                radius: 3
                color: Qt.alpha(Theme.foreground, 0.18)
            }

            RowLayout {
                visible: dock.expanded
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Repeater {
                    model: [
                        {icon:"\ue8b6",label:"Launcher",enabled:true,command:[]},
                        {icon:"\ue2c7",label:"Files",enabled:SettingsStore.dockFiles,command:["sh", "-c", "xdg-open \"$HOME\""]},
                        {icon:"\ue80b",label:"Browser",enabled:SettingsStore.dockBrowser,command:["sh", "-c", "xdg-open https://www.google.com"]},
                        {icon:"\ue8b8",label:"Settings",enabled:SettingsStore.dockSettings,command:[]},
                        {icon:"\uf190",label:"Task View",enabled:SettingsStore.dockTaskView,command:[]},
                        {icon:"\ue8f4",label:"AI",enabled:SettingsStore.dockAI,command:[]}
                    ]
                    delegate: ColumnLayout {
                        id: app
                        required property var modelData
                        visible: modelData.enabled
                        spacing: 3
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: 15
                            color: mouse.containsMouse ? Qt.alpha(Theme.accent, .18) : Theme.surface
                            border.width: mouse.containsMouse ? 1 : 0
                            border.color: Qt.alpha(Theme.accent, 0.30)
                            Icon { anchors.centerIn: parent; icon: app.modelData.icon; color: Theme.accent; font.pixelSize: 23 }
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (app.modelData.label === "Launcher") {
                                        Quickshell.execDetached(["sh", "-lc", "(command -v rofi >/dev/null && rofi -show drun) || (command -v wofi >/dev/null && wofi --show drun) || (command -v fuzzel >/dev/null && fuzzel) || (command -v bemenu-run >/dev/null && bemenu-run)"]);
                                    } else if (app.modelData.label === "Settings") Store.showSettings("bar");
                                    else if (app.modelData.label === "Task View") Store.taskViewVisible = !Store.taskViewVisible;
                                    else if (app.modelData.label === "AI") Store.toggleAi(dock.screen);
                                    else Quickshell.execDetached(app.modelData.command);
                                }
                            }
                        }
                        Text { text: app.modelData.label; Layout.alignment: Qt.AlignHCenter; font.pixelSize: 9; color: Theme.muted; font.family: Fonts.poppins.name }
                    }
                }
            }
        }

        Rectangle {
            visible: !dock.expanded
            anchors.centerIn: parent
            width: 42
            height: 6
            radius: 3
            color: Theme.background
        }
    }
}
