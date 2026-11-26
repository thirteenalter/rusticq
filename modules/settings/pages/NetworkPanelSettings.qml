import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

SettingsSection {
    id: settingsPageRoot
    readonly property var settingsTheme: SettingsMaterial.forItem(settingsPageRoot)
    objectName: "networkPanelSettings"
    heading: "Network Panel"
    description: "Speed test appearance in the network popup. Tests run only when requested."
    symbol: "\ue9e4"
    Repeater {
        model: [
            {key:"showSpeedTestPanel", label:"Show Speed Test Panel", desc:"Show in Advanced Wi-Fi", icon:"\ue9e4"},
            {key:"showSpeedometerGauge", label:"Show Speedometer Gauge", desc:"Hide the gauge to give metrics the available width", icon:"\ue1b8"},
            {key:"speedTestGaugeAnimation", label:"Enable Gauge Animation", desc:"Smooth real measurements; follows global motion", icon:"\ue9d9"},
            {key:"speedTestGaugeGlow", label:"Enable Gauge Glow", desc:"Subtle arc glow when RAGE effects allow it", icon:"\ue518"},
            {key:"showSpeedTestTime", label:"Show Last Test Time", desc:"Last completed test in this shell session", icon:"\ue8b5"}
        ]
        SettingsToggle { objectName: modelData.key; enabled: modelData.key === "showSpeedTestPanel" || SettingsStore.showSpeedTestPanel }
    }
    GlassLabel { text:"Speed Test Panel Style"; color:settingsPageRoot.settingsTheme.foreground; font.family:Fonts.poppinsSB.name; font.pixelSize:Fonts.scale(12) }
    RowLayout {
        Layout.fillWidth: true
        spacing: settingsPageRoot.settingsTheme.inlineGap
        Repeater {
            model: [{key:"classic",label:"Classic Gauge"}, {key:"modern",label:"Modern Arc"}, {key:"compact",label:"Compact"}]
            ActionButton {
                required property var modelData
                objectName: "speedTestStyle_" + modelData.key
                Layout.fillWidth: true
                label: modelData.label
                selected: SettingsStore.speedTestPanelStyle === modelData.key
                onClicked: SettingsStore.setNetworkPanelSetting("speedTestPanelStyle",modelData.key,true)
            }
        }
    }
}
