import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services"

GlassSurface {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    objectName: "speedTestCard"
    surfaceRole: "card"
    baseColor: Qt.alpha(root.settingsTheme.foreground, 0.02)
    baseRadius: root.settingsTheme.sectionRadius
    implicitHeight: content.implicitHeight + 2 * root.settingsTheme.panelPadding
    readonly property bool compact: SettingsStore.speedTestPanelStyle === "compact"
    readonly property bool gaugeVisible: SettingsStore.showSpeedometerGauge && !compact
    readonly property bool uploading: SpeedTestService.phase === "upload"
    readonly property real gaugeSpeed: uploading ? SpeedTestService.uploadMbps : SpeedTestService.downloadMbps

    ColumnLayout {
        id: content
        objectName: "speedTestContent"
        x: root.settingsTheme.panelPadding
        y: root.settingsTheme.panelPadding
        width: Math.max(0, root.width - 2 * root.settingsTheme.panelPadding)
        spacing: root.settingsTheme.compactGap
        RowLayout {
            Layout.fillWidth: true
            spacing: root.settingsTheme.inlineGap
            Icon { icon: "\ue9e4"; font.pixelSize: Fonts.scale(19); color: root.settingsTheme.accent }
            GlassLabel {
                Layout.fillWidth: true
                text: "Speed Test"
                color: root.settingsTheme.foreground
                font.family: Fonts.poppinsSB.name
                font.pixelSize: Fonts.scale(13)
            }
            GlassLabel {
                visible: SettingsStore.showSpeedTestTime && SpeedTestService.lastTestTime > 0
                text: "Last · " + Qt.formatTime(new Date(SpeedTestService.lastTestTime), "HH:mm")
                color: root.settingsTheme.contentMuted
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(9)
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(root.settingsTheme.foreground, 0.08) }
        RowLayout {
            Layout.fillWidth: true
            spacing: root.settingsTheme.inlineGap
            Loader {
                objectName: "speedTestGaugeLoader"
                active: root.gaugeVisible
                visible: active
                Layout.preferredWidth: Math.min(140, Math.max(110, content.width * 0.43))
                Layout.preferredHeight: SettingsStore.uiDensity === "compact" ? 110 : 120
                sourceComponent: SpeedometerGauge {
                    objectName: "speedTestGauge"
                    speed: Math.max(0, root.gaugeSpeed)
                    peakSpeed: Math.max(0, SpeedTestService.downloadMbps, SpeedTestService.uploadMbps)
                    phaseLabel: root.uploading ? "Upload" : "Download"
                    modern: SettingsStore.speedTestPanelStyle === "modern"
                }
            }
            Rectangle {
                objectName: "speedTestVerticalDivider"
                visible: root.gaugeVisible
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Qt.alpha(root.settingsTheme.foreground, 0.08)
            }
            GridLayout {
                objectName: "speedTestMetrics"
                Layout.fillWidth: true
                columns: root.compact ? 3 : 1
                columnSpacing: root.settingsTheme.inlineGap
                rowSpacing: root.settingsTheme.compactGap
                Repeater {
                    model: [
                        {label: "Ping", symbol: "\ue8b5", value: SpeedTestService.pingMs, unit: "ms"},
                        {label: "Download", symbol: "\ue2c4", value: SpeedTestService.downloadMbps, unit: "Mbps"},
                        {label: "Upload", symbol: "\ue2c6", value: SpeedTestService.uploadMbps, unit: "Mbps"}
                    ]
                    ColumnLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: root.compact ? 3 : 5
                        RowLayout {
                            visible: root.compact
                            Layout.fillWidth: true
                            spacing: 4
                            Icon { icon: modelData.symbol; font.pixelSize: Fonts.scale(13); color: root.settingsTheme.accent }
                            GlassLabel { Layout.fillWidth: true; text: modelData.label; elide: Text.ElideRight; color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.minimumHeight: root.compact ? 20 : 28
                            spacing: 3
                            Icon { visible: !root.compact; icon: modelData.symbol; font.pixelSize: Fonts.scale(13); color: root.settingsTheme.accent }
                            GlassLabel { visible: !root.compact; text: modelData.label; color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                            GlassLabel {
                                objectName: "speedTestValue_" + modelData.label.toLowerCase()
                                Layout.fillWidth: true
                                text: modelData.value < 0 ? "—" : modelData.value.toFixed(1)
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                color: root.settingsTheme.foreground
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(root.compact ? 15 : 13)
                                font.features: ({"tnum": 1})
                            }
                            GlassLabel { text: modelData.unit; color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9) }
                        }
                        Rectangle { visible: !root.compact && index < 2; Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(root.settingsTheme.foreground, 0.05) }
                    }
                }
            }
        }
        GlassLabel {
            objectName: "speedTestStatus"
            visible: SpeedTestService.running || ["error", "missing", "offline", "cancelled"].includes(SpeedTestService.state)
            Layout.fillWidth: true
            text: SpeedTestService.statusText
            wrapMode: Text.WordWrap
            color: ["error", "missing"].includes(SpeedTestService.state) ? root.settingsTheme.error : root.settingsTheme.contentMuted
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(10)
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
        Rectangle {
            visible: SpeedTestService.running
            Layout.fillWidth: true
            implicitHeight: 2
            radius: 1
            color: root.settingsTheme.surface
            Rectangle { width: parent.width * SpeedTestService.progress; height: parent.height; radius: 1; color: root.settingsTheme.accent }
        }
        ActionButton {
            objectName: "speedTestAction"
            Layout.fillWidth: true
            Layout.preferredHeight: SettingsStore.uiDensity === "compact" ? 36 : 38
            label: SpeedTestService.actionText
            symbol: SpeedTestService.running ? "\ue5cd" : "\ue9e4"
            enabled: SpeedTestService.running || (SpeedTestService.online && !SpeedTestService.checking)
            onClicked: {
                if (SpeedTestService.running) SpeedTestService.cancel();
                else SpeedTestService.start();
            }
        }
    }
}
