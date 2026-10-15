import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

// Read-only monitor overview; nwg-displays edits and persists Hyprland monitor rules.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8
    property var monitors: []
    property string status: "Reading monitors…"

    Process {
        id: readMonitors
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(this.text);
                    root.monitors = Array.isArray(value) ? value : [];
                    root.status = root.monitors.length ? "" : "No active monitors reported";
                } catch (e) {
                    root.status = "Could not read Hyprland monitors";
                }
            }
        }
        onExited: (code, status) => { if (code !== 0) root.status = "hyprctl monitors failed"; }
    }
    Timer {
        interval: 7000; repeat: true; running: root.visible; triggeredOnStart: true
        onTriggered: { if (!readMonitors.running) readMonitors.running = true; }
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "Connected monitors"
            Layout.fillWidth: true
            font.family: Fonts.poppinsSB.name; font.pixelSize: 12; color: Theme.foreground
        }
        Text {
            text: "Refresh"
            font.family: Fonts.poppins.name; font.pixelSize: 11; color: Theme.accent
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!readMonitors.running) readMonitors.running = true
            }
        }
    }
    Repeater {
        model: root.monitors
        delegate: Rectangle {
            id: monitorRow
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 61
            radius: 10; color: Theme.surface
            RowLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 8
                Icon { icon: "\ue30b"; font.pixelSize: 18; color: Theme.accent }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: monitorRow.modelData.name || "Display"
                        font.family: Fonts.poppinsSB.name; font.pixelSize: 12
                        color: Theme.foreground; elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: monitorRow.modelData.width + "×" + monitorRow.modelData.height +
                              " @ " + Math.round(monitorRow.modelData.refreshRate || 0) + " Hz" +
                              " · " + (monitorRow.modelData.scale || 1) + "x"
                        font.family: Fonts.poppins.name; font.pixelSize: 10
                        color: Theme.muted; elide: Text.ElideRight
                    }
                }
            }
        }
    }
    Text {
        visible: root.status.length > 0
        Layout.fillWidth: true
        text: root.status
        font.family: Fonts.poppins.name; font.pixelSize: 11; color: Theme.muted
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 9; color: Theme.surface
        RowLayout {
            anchors.centerIn: parent; spacing: 6
            Icon { icon: "\ue8b8"; font.pixelSize: 17; color: Theme.accent }
            Text {
                text: "Configure displays (nwg-displays)"
                font.family: Fonts.poppins.name; font.pixelSize: 11; color: Theme.foreground
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["nwg-displays"])
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Install nwg-displays to change resolution, refresh rate, scale and layout."
        font.family: Fonts.poppins.name; font.pixelSize: 10
        color: Theme.muted; wrapMode: Text.WordWrap
    }
}
