import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../services"
import "../../components"

// Shell > System monitor opens this independent floating window.
// GPU and I/O unavailable states are explicit, not fabricated.
FloatingWindow {
    id: monitorWindow
    visible: Store.systemMonitorVisible
    title: "RusticQ · System Monitor"
    // Closing the floating window from the compositor must also reset its
    // LazyLoader state; the header intentionally has no close button.
    onVisibleChanged: {
        if (!visible && Store.systemMonitorVisible)
            Store.systemMonitorVisible = false;
    }
    implicitWidth: 920
    implicitHeight: 720
    color: Theme.background
    property bool processTab: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 42; Layout.preferredHeight: 42
                radius: 12; color: Qt.alpha(Theme.accent, 0.13)
                Icon { anchors.centerIn: parent; icon: "\uef43"; color: Theme.accent; font.pixelSize: Fonts.scale(23) }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "System Monitor"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(19); color: Theme.foreground }
                Text { text: "Live hardware utilization · measured every 2 seconds"; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); color: Theme.muted }
            }
            Text { text: SystemMetrics.error ? "SENSOR ERROR" : "● LIVE"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10); color: SystemMetrics.error ? Theme.muted : Theme.accent }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: ["Performance", "Processes"]
                delegate: Rectangle {
                    id: tab
                    required property string modelData
                    readonly property bool chosen: (tab.modelData === "Processes") === monitorWindow.processTab
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: chosen ? Qt.alpha(Theme.accent, 0.17) : Theme.surface
                    radius: 10
                    Text { anchors.centerIn: parent; text: tab.modelData; color: tab.chosen ? Theme.accent : Theme.foreground; font.pixelSize: Fonts.scale(12); font.family: Fonts.poppinsSB.name }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: monitorWindow.processTab = tab.modelData === "Processes" }
                }
            }
        }

        Flickable {
            visible: !monitorWindow.processTab
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: graphContent.implicitHeight + 16
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: graphContent
                width: parent.width
                spacing: 12
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    MonitorGraphCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        heading: "CPU"
                        valueLabel: SysMonService.cpuUsage.toFixed(1) + "%"
                        detail: "Total logical CPU usage · " + SysMonService.cpuHistory.length + " samples"
                        glyph: "\ue322"
                        percentage: true
                        history: SysMonService.cpuHistory
                    }
                    MonitorGraphCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        heading: "GPU"
                        valueLabel: SystemMetrics.gpuPercent === null ? "N/A" : SystemMetrics.gpuPercent.toFixed(0) + "%"
                        detail: SystemMetrics.gpuPercent === null ? "Utilization sensor unavailable" : SystemMetrics.gpuName
                        glyph: "\ue30b"
                        percentage: true
                        history: SystemMetrics.gpuHistory
                    }
                    MonitorGraphCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        heading: "Memory"
                        valueLabel: SysMonService.memUsedGB.toFixed(1) + " GiB"
                        detail: SysMonService.memTotalGB.toFixed(1) + " GiB total · " + (SysMonService.memUsedPercent * 100).toFixed(0) + "%"
                        glyph: "\ue322"
                        percentage: true
                        history: SysMonService.memHistory
                    }
                    MonitorGraphCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        heading: "Network · download"
                        valueLabel: SystemMetrics.speed(SystemMetrics.rxPerSec)
                        detail: (SystemMetrics.interfaces.length ? SystemMetrics.interfaces.join(", ") : "No active interface") + " · auto scale"
                        glyph: "\ue63e"
                        history: SystemMetrics.rxHistory
                    }
                    MonitorGraphCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        heading: "Network · upload"
                        valueLabel: SystemMetrics.speed(SystemMetrics.txPerSec)
                        detail: "TX throughput · auto scale"
                        glyph: "\ue2c6"
                        history: SystemMetrics.txHistory
                    }
                    MonitorGraphCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        heading: "Disk · read"
                        valueLabel: SystemMetrics.speed(SystemMetrics.diskReadPerSec)
                        detail: SystemMetrics.disks.length ? SystemMetrics.disks.join(", ") + " · auto scale" : "Disk I/O unavailable"
                        glyph: "\ue1db"
                        history: SystemMetrics.readHistory
                    }
                    MonitorGraphCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        heading: "Disk · write"
                        valueLabel: SystemMetrics.speed(SystemMetrics.diskWritePerSec)
                        detail: "Kernel block-device throughput · auto scale"
                        glyph: "\ue1db"
                        history: SystemMetrics.writeHistory
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 13
                        color: Theme.surface
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            Text { text: "Hardware details"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            Text { Layout.fillWidth: true; text: "GPU: " + SystemMetrics.gpuName; color: Theme.muted; font.pixelSize: Fonts.scale(11); elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: "VRAM: " + (SystemMetrics.vramTotal !== null ? (SystemMetrics.vramUsed / 1048576).toFixed(0) + " / " + (SystemMetrics.vramTotal / 1048576).toFixed(0) + " MiB" : "unavailable"); color: Theme.muted; font.pixelSize: Fonts.scale(11) }
                            Text { Layout.fillWidth: true; text: "Wi-Fi: " + (WifiService.connected ? (WifiService.ssid + " · " + WifiService.strength + "%") : "not connected"); color: Theme.muted; font.pixelSize: Fonts.scale(11); elide: Text.ElideRight }
                            Text { text: "Thermal sensor: " + (SysMonService.temperature >= 0 ? SysMonService.temperature.toFixed(0) + "°C" : "unavailable"); color: Theme.muted; font.pixelSize: Fonts.scale(11) }
                            Text { text: "Disk free: " + SysMonService.diskAvailableGB.toFixed(1) + " GiB"; color: Theme.muted; font.pixelSize: Fonts.scale(11) }
                            Text { text: "Local kernel counters · nothing uploaded"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
                        }
                    }
                }
            }
        }
        Loader {
            active: monitorWindow.processTab
            visible: monitorWindow.processTab
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: SystemDashboard {}
        }
        Text {
            Layout.fillWidth: true
            text: SystemMetrics.error || "Charts show measured data only. Network and disk charts auto-scale to their largest observed value."
            color: Theme.muted
            font.pixelSize: Fonts.scale(10)
            font.family: Fonts.poppins.name
            wrapMode: Text.WordWrap
        }
    }
}
