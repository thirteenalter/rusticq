import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Services

// Fixed card heights and layout-managed rows prevent bar/value/footer overlap.
Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 372
    radius: Theme.sectionRadius
    color: Qt.alpha(Theme.foreground, 0.02)
    border.width: 1
    border.color: Theme.borderaccent
    clip: true

    RowLayout {
        x: 16; y: 16; width: parent.width - 32; height: 36
        spacing: 10
        Icon { icon: "\ue8b8"; font.pixelSize: 20; color: Theme.accent; Layout.preferredWidth: 24 }
        Text { text: "System"; color: Theme.foreground; font.pixelSize: Theme.sectionTitleSize;
               font.family: Fonts.poppinsSB.name; Layout.fillWidth: true }
        Text { text: "LIVE"; color: Theme.muted; font.pixelSize: 10; font.family: Fonts.poppins.name }
    }

    ColumnLayout {
        id: metricColumn
        x: 16; y: 64
        width: parent.width - 32
        spacing: 8

        Repeater {
            model: ["cpu", "memory", "disk", "temperature"]
            delegate: Rectangle {
                id: metric
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: modelData === "disk" ? 72 : 58
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
                    anchors.topMargin: 7; anchors.bottomMargin: 8
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 21
                        spacing: 7
                        Icon { icon: metric.glyph; font.pixelSize: 16; color: Theme.accent; Layout.preferredWidth: 20 }
                        Text {
                            text: metric.title
                            Layout.fillWidth: true
                            font.family: Fonts.poppins.name; font.pixelSize: 11
                            color: Theme.foreground
                        }
                        Text {
                            text: metric.valueText
                            font.family: Fonts.poppinsSB.name; font.pixelSize: 10
                            color: Theme.foreground
                        }
                    }
                    Text {
                        visible: metric.modelData === "disk"
                        Layout.fillWidth: true
                        Layout.leftMargin: 27
                        text: Services.SysMonService.diskAvailableGB.toFixed(1) + " GiB available (root /)"
                        font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted
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
            Layout.fillWidth: true
            Layout.leftMargin: 5
            text: "System metrics · Updated from the local machine"
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: 10
        }
    }
}
