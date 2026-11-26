import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import "../../../services"
import ".."

SettingsSection {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    heading: "Night Light"
    description: "Choose how yellow the screen becomes. Lower temperatures are warmer."
    symbol: "\ue51c"
    property int draftTemperature: SettingsStore.nightLightTemperature
    Connections {
        target: SettingsStore
        function onNightLightTemperatureChanged() { root.draftTemperature = SettingsStore.nightLightTemperature; }
    }
    RowLayout {
        Layout.fillWidth: true
        GlassLabel { text: "Warmth"; Layout.fillWidth: true; color: root.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
        GlassLabel { objectName: "night-light-temperature-label"; text: root.draftTemperature + " K"; color: root.settingsTheme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
    }
    SettingRangeSlider {
        objectName: "night-light-temperature"
        Layout.fillWidth: true
        minimum: 2000; maximum: 6000; step: 100
        value: root.draftTemperature
        activeFocusOnTab: true
        Accessible.name: "Night Light color temperature"
        onPreview: next => root.draftTemperature = next
        onCommit: next => QuickModesService.setNightLightTemperature(next)
        Keys.onLeftPressed: QuickModesService.setNightLightTemperature(Math.max(2000, SettingsStore.nightLightTemperature - 100))
        Keys.onRightPressed: QuickModesService.setNightLightTemperature(Math.min(6000, SettingsStore.nightLightTemperature + 100))
    }
    RowLayout {
        Layout.fillWidth: true
        GlassLabel { text: "More yellow"; Layout.fillWidth: true; color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
        GlassLabel { text: "Less yellow"; color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [{value: 3000, label: "Warm"}, {value: 4000, label: "Balanced"}, {value: 5000, label: "Mild"}]
            delegate: ActionButton {
                required property var modelData
                objectName: "night-light-preset-" + modelData.value
                Layout.fillWidth: true
                label: modelData.label
                selected: SettingsStore.nightLightTemperature === modelData.value
                onClicked: QuickModesService.setNightLightTemperature(modelData.value)
            }
        }
    }
    ActionButton {
        objectName: "night-light-toggle"
        Layout.fillWidth: true
        label: QuickModesService.busy ? "Applying…" : QuickModesService.active("night") ? "Turn off Night Light" : "Turn on Night Light"
        selected: QuickModesService.active("night")
        enabled: QuickModesService.available("night") && !QuickModesService.busy
        onClicked: QuickModesService.toggle("night")
    }
    GlassLabel {
        Layout.fillWidth: true
        text: QuickModesService.error || QuickModesService.detail("night").split("\n")[0]
        color: QuickModesService.error ? root.settingsTheme.error : root.settingsTheme.muted
        font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        wrapMode: Text.WordWrap
    }
    GlassLabel {
        Layout.fillWidth: true
        text: "Changes apply while Night Light is on. When off, your choice is saved for the next use."
        color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        wrapMode: Text.WordWrap
    }
    Component.onCompleted: QuickModesService.refresh()
}
