import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Services

// Fixed card heights and layout-managed rows prevent bar/value/footer overlap.
Rectangle {
    id: root
    Layout.fillWidth: true
    property bool compactQuick: false
    Layout.preferredHeight: compactQuick ? 222 : 372
    radius: Theme.sectionRadius
    color: Qt.alpha(Theme.foreground, 0.02)
    border.width: 1
    border.color: Theme.borderaccent
    clip: true

    RowLayout {
        x: 16; y: compactQuick ? 9 : 16; width: parent.width - 32; height: 36
        spacing: 10
        Icon { icon: "\ue8b8"; font.pixelSize: Fonts.scale(20); color: Theme.accent; Layout.preferredWidth: 24 }
        Text { text: "System"; color: Theme.foreground; font.pixelSize: Theme.sectionTitleSize;
               font.family: Fonts.poppinsSB.name; Layout.fillWidth: true }
        Text { text: "LIVE"; color: Theme.muted; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppins.name }
    }

    GridLayout {
        id: compactGrid
        visible: root.compactQuick
        x: 16; y: 49; width: parent.width - 32
        columns: 2
        columnSpacing: 8; rowSpacing: 8
        Repeater {
            model: ["cpu", "memory", "disk", "temperature"]
            delegate: Rectangle {
                id: compactMetric
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 73
                radius: 11; color: Qt.alpha(Theme.foreground, 0.055)
                readonly property real level: modelData === "cpu" ? Services.SysMonService.cpuUsage / 100
                    : modelData === "memory" ? Services.SysMonService.memUsedPercent
                    : modelData === "disk" ? Services.SysMonService.diskUsedPercent
                    : Math.max(0, Math.min(1, Services.SysMonService.temperature / 100))
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true; spacing: 5
                        Icon {
                            icon: compactMetric.modelData === "cpu" ? "\ue30d" : compactMetric.modelData === "memory" ? "\ue322" : compactMetric.modelData === "disk" ? "\ue1db" : "\ue1ff"
                            color: Theme.accent; font.pixelSize: Fonts.scale(15)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: compactMetric.modelData === "cpu" ? "CPU" : compactMetric.modelData === "memory" ? "RAM" : compactMetric.modelData === "disk" ? "Free disk" : "Temp"
                            color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                            elide: Text.ElideRight
                        }
                        Text {
                            text: compactMetric.modelData === "cpu" ? Math.round(Services.SysMonService.cpuUsage) + "%"
                                : compactMetric.modelData === "memory" ? Services.SysMonService.memUsedGB.toFixed(1) + "G"
                                : compactMetric.modelData === "disk" ? Services.SysMonService.diskAvailableGB.toFixed(0) + "G"
                                : Services.SysMonService.temperature < 0 ? "N/A" : Math.round(Services.SysMonService.temperature) + "°"
                            color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10)
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 4; radius: 3
                        color: Qt.alpha(Theme.foreground, 0.10)
                        Rectangle { width: parent.width * Math.max(0, Math.min(1, compactMetric.level)); height: parent.height; radius: parent.radius; color: Theme.accent }
                    }
                }
            }
        }
    }

    ColumnLayout {
        visible: !root.compactQuick
        id: metricColumn
        x: 16; y: compactQuick ? 46 : 64
        width: parent.width - 32
        spacing: compactQuick ? 5 : 8

        Repeater {
            model: ["cpu", "memory", "disk", "temperature"]
            delegate: Rectangle {
                id: metric
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: compactQuick ? (modelData === "disk" ? 51 : 43) : (modelData === "disk" ? 72 : 58)
                radius: 11
                color: Qt.alpha(Theme.foreground, 0.055)
                readonly property real fraction: {
                    if (modelData === "cpu") return Services.SysMonService.cpuUsage / 100;
                    if (modelData === "memory") return Services.SysMonService.memUsedPercent;
                    if (modelData === "disk") return Services.SysMonService.diskUsedPercent;
                    if (modelData === "temperature") return Services.SysMonService.temperature < 0 ? 0 : Math.min(1, Services.SysMonService.temperature / 100);
                    return 0;
                }
                readonly property color usageColor: modelData === "temperature" && Services.SysMonService.temperature < 0 ? Theme.muted :
                    fraction >= 0.85 ? Theme.error : fraction >= 0.6 ? Theme.accent : Theme.success
                readonly property string title: ({cpu: "CPU", memory: "Memory", disk: "Storage", temperature: "Temperature"})[modelData]
                readonly property string glyph: ({cpu: "\ue30d", memory: "\ue322", disk: "\ue1db", temperature: "\ue1ff"})[modelData]
                readonly property string valueText: {
                    if (modelData === "cpu") return Math.round(Services.SysMonService.cpuUsage) + "%";
                    if (modelData === "memory") return Services.SysMonService.memUsedGB.toFixed(1) + " / " + Services.SysMonService.memTotalGB.toFixed(1) + " GiB";
                    if (modelData === "disk") return Services.SysMonService.diskUsedGB.toFixed(0) + " / " + Services.SysMonService.diskTotalGB.toFixed(0) + " GiB";
                    if (modelData === "temperature") return Services.SysMonService.temperature < 0 ? "N/A" : Math.round(Services.SysMonService.temperature) + "°C";
                    return "";
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11; anchors.rightMargin: 11
                    anchors.topMargin: compactQuick ? 4 : 7; anchors.bottomMargin: compactQuick ? 4 : 8
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: compactQuick ? 16 : 21
                        spacing: 7
                        Icon { icon: metric.glyph; font.pixelSize: Fonts.scale(16); color: Theme.accent; Layout.preferredWidth: 20 }
                        Text {
                            text: metric.title
                            Layout.fillWidth: true
                            font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                            color: Theme.foreground
                        }
                        Text {
                            text: metric.valueText
                            font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10)
                            color: Theme.foreground
                        }
                    }
                    Text {
                        visible: metric.modelData === "disk" && !compactQuick
                        Layout.fillWidth: true
                        Layout.leftMargin: 27
                        text: Services.SysMonService.diskAvailableGB.toFixed(1) + " GiB available (root /)"
                        font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); color: Theme.muted
                    }
                    Item { Layout.fillHeight: true }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        radius: 3
                        color: Qt.alpha(Theme.foreground, 0.12)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, metric.fraction))
                            height: parent.height
                            radius: parent.radius
                            color: metric.usageColor
                        }
                    }
                }
            }
        }
        Text {
            visible: !compactQuick
            Layout.fillWidth: true
            Layout.leftMargin: 5
            text: "System metrics · Updated from the local machine"
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(10)
        }
    }
}
