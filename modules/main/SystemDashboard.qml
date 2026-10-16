import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../services"
import "../../components"

Rectangle {
    id: root
    radius: 15; color: Theme.background
    property var processData: ({processes: [], total: 0, load: [0,0,0], uptime: 0, cores: 1})
    property string error: ""
    Process {
        id: proc
        command: ["python3", Quickshell.shellPath("scripts/rustiq-processes.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.processData = JSON.parse(this.text); root.error = ""; }
                catch (e) { root.error = "Process data unavailable"; }
            }
        }
    }
    Timer {
        running: root.visible; repeat: true; interval: 3000; triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 15; spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Icon { icon: "\uf190"; font.pixelSize: 21; color: Theme.accent }
            Text { text: "System · Task View"; Layout.fillWidth: true; font.pixelSize: 15; font.family: Fonts.poppinsSB.name; color: Theme.foreground }
            Text { text: "LIVE"; font.pixelSize: 10; color: Theme.muted }
        }
        Repeater {
            model: [
                { label: "CPU", value: SysMonService.cpuUsage.toFixed(0) + "%", pct: SysMonService.cpuUsage / 100, icon: "\ue322" },
                { label: "Memory", value: SysMonService.memUsedGB.toFixed(1) + " / " + SysMonService.memTotalGB.toFixed(1) + " GiB", pct: SysMonService.memUsedPercent, icon: "\ue322" },
                { label: "Storage", value: SysMonService.diskAvailableGB.toFixed(1) + " GiB free", pct: SysMonService.diskUsedPercent, icon: "\ue1db" }
            ]
            delegate: ColumnLayout {
                id: metric
                required property var modelData
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: metric.modelData.label; Layout.fillWidth: true; font.pixelSize: 11; color: Theme.foreground; font.family: Fonts.poppinsSB.name }
                    Text { text: metric.modelData.value; font.pixelSize: 11; color: Theme.foreground }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 3; color: Theme.surface
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, metric.modelData.pct)); height: parent.height; radius: 3; color: Theme.accent }
                }
            }
        }
        Text { text: "Load " + root.processData.load.join(" / ") + "  ·  " + root.processData.cores + " CPUs  ·  " + root.processData.total + " processes"; Layout.fillWidth: true; font.pixelSize: 10; color: Theme.muted }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "TOP CPU PROCESSES"; Layout.fillWidth: true; font.pixelSize: 10; font.family: Fonts.poppinsSB.name; color: Theme.muted }
            Text { text: "CPU"; font.pixelSize: 10; color: Theme.muted }
            Text { text: "RAM"; font.pixelSize: 10; color: Theme.muted }
        }
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            model: root.processData.processes
            spacing: 3
            delegate: Rectangle {
                id: pRow
                required property var modelData
                required property int index
                width: ListView.view.width; height: 30; radius: 6
                color: index % 2 ? Qt.alpha(Theme.foreground, .035) : Theme.surface
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    Text { text: pRow.modelData.name + "  #" + pRow.modelData.pid; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 11; color: Theme.foreground }
                    Text { text: pRow.modelData.cpu.toFixed(1) + "%"; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Theme.foreground }
                    Text { text: pRow.modelData.memMiB.toFixed(0) + " MiB"; Layout.preferredWidth: 67; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Theme.muted }
                }
            }
        }
        Text { text: root.error || "Read-only process view · updates every 3 s"; font.pixelSize: 10; color: Theme.muted }
    }
}
