import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../services"
import "../../components"

Rectangle {
    id: root
    radius: Theme.glassRadius("card", 15); color: Theme.glassColor("card", Theme.background)
    property var processData: ({processes: [], total: 0, load: [0,0,0], uptime: 0, cores: 1})
    property string error: ""
    property bool showTrends: false
    readonly property var cpuHistory: SysMonService.cpuHistory
    readonly property var memHistory: SysMonService.memHistory
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
        objectName: "surfaceContent"
        anchors.fill: parent; anchors.margins: Theme.panelPadding; spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Icon { icon: "\uf500"; font.pixelSize: Fonts.scale(21); color: Theme.accent }
            GlassLabel { text: "System · Task View"; Layout.fillWidth: true; font.pixelSize: Fonts.scale(15); font.family: Fonts.poppinsSB.name; color: Theme.foreground }
            GlassLabel { text: "LIVE"; font.pixelSize: Fonts.scale(10); color: Theme.contentMuted }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            Repeater {
                model: [{key:"overview",title:"Processes",icon:"\ue8b8"}, {key:"trends",title:"Live graphs",icon:"\uef43"}]
                delegate: Rectangle {
                    id: viewTab
                    required property var modelData
                    readonly property bool active: (modelData.key === "trends") === root.showTrends
                    Layout.fillWidth: true
                    Layout.preferredHeight: 31
                    radius: Theme.glassRadius("card", 9)
                    color: Theme.glassColor("card", active ? Qt.alpha(Theme.accent, 0.18) : Theme.surface)
                    border.width: Theme.glassBorderWidth("card", active ? 1 : 0)
                    border.color: Theme.glassBorder("card", Theme.accent)
                    RowLayout { anchors.centerIn: parent; spacing: 5
                        Icon { icon: viewTab.modelData.icon; font.pixelSize: Fonts.scale(15); color: active ? Theme.accent : Theme.foreground }
                        GlassLabel { text: viewTab.modelData.title; font.pixelSize: Fonts.scale(11); color: Theme.foreground; font.family: Fonts.poppinsSB.name }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showTrends = viewTab.modelData.key === "trends" }
                }
            }
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
                    GlassLabel { text: metric.modelData.label; Layout.fillWidth: true; font.pixelSize: Fonts.scale(11); color: Theme.foreground; font.family: Fonts.poppinsSB.name }
                    GlassLabel { text: metric.modelData.value; font.pixelSize: Fonts.scale(11); color: Theme.foreground }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 3; color: Theme.surface
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, metric.modelData.pct)); height: parent.height; radius: 3; color: Theme.accent }
                }
            }
        }
        ColumnLayout {
            visible: root.showTrends
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            Repeater {
                model: [
                    {label:"CPU usage · last ~96 seconds", value:SysMonService.cpuUsage.toFixed(0)+"%", series:root.cpuHistory},
                    {label:"Memory usage · last ~96 seconds", value:(SysMonService.memUsedPercent*100).toFixed(0)+"%", series:root.memHistory}
                ]
                delegate: Rectangle {
                    id: trendCard; required property var modelData
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.glassColor("card", Theme.surface); radius: Theme.glassRadius("card", 12)
                    ColumnLayout { anchors.fill: parent; anchors.margins: Theme.cardPadding; spacing: 9
                        RowLayout { Layout.fillWidth: true
                            GlassLabel { text: trendCard.modelData.label; Layout.fillWidth: true; color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
                            GlassLabel { text: trendCard.modelData.value; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                        }
                        MetricWave { Layout.fillWidth: true; Layout.fillHeight: true; samples: trendCard.modelData.series }
                    }
                }
            }
            GlassLabel { text: "Live samples every 2 seconds · no historical files saved"; color: Theme.contentMuted; font.pixelSize: Fonts.scale(10); Layout.fillWidth: true }
        }
        GlassLabel { text: "Load " + root.processData.load.join(" / ") + "  ·  " + root.processData.cores + " CPUs  ·  " + root.processData.total + " processes"; Layout.fillWidth: true; font.pixelSize: Fonts.scale(10); color: Theme.contentMuted }
        RowLayout {
            visible: !root.showTrends
            Layout.fillWidth: true
            GlassLabel { text: "TOP CPU PROCESSES"; Layout.fillWidth: true; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppinsSB.name; color: Theme.contentMuted }
            GlassLabel { text: "CPU"; font.pixelSize: Fonts.scale(10); color: Theme.contentMuted }
            GlassLabel { text: "RAM"; font.pixelSize: Fonts.scale(10); color: Theme.contentMuted }
        }
        ListView {
            visible: !root.showTrends
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            model: root.processData.processes
            spacing: 3
            delegate: Rectangle {
                id: pRow
                required property var modelData
                required property int index
                width: ListView.view.width; height: 30; radius: Theme.glassRadius("card", 6)
                color: Theme.glassColor("card", index % 2 ? Qt.alpha(Theme.foreground, .035) : Theme.surface)
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    GlassLabel { text: pRow.modelData.name + "  #" + pRow.modelData.pid; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: Fonts.scale(11); color: Theme.foreground }
                    GlassLabel { text: pRow.modelData.cpu.toFixed(1) + "%"; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight; font.pixelSize: Fonts.scale(10); color: Theme.foreground }
                    GlassLabel { text: pRow.modelData.memMiB.toFixed(0) + " MiB"; Layout.preferredWidth: 67; horizontalAlignment: Text.AlignRight; font.pixelSize: Fonts.scale(10); color: Theme.contentMuted }
                }
            }
        }
        GlassLabel { text: root.error || "Read-only process view · updates every 3 s"; font.pixelSize: Fonts.scale(10); color: Theme.contentMuted }
    }
}
