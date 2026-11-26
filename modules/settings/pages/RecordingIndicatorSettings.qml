import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

SettingsSection {
    id: settingsPageRoot
    readonly property var settingsTheme: SettingsMaterial.forItem(settingsPageRoot)
    heading: "Recording indicator"
    description: "A red recording light on every display. Its position is independent of the bar."
    symbol: "\ue04b"
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 48
            radius: settingsPageRoot.settingsTheme.glassRadius("card", settingsPageRoot.settingsTheme.rowRadius)
            color: settingsPageRoot.settingsTheme.glassColor("card", settingsPageRoot.settingsTheme.background)
            RecordingDot {
                objectName: "recordingIndicatorPreview"
                anchors.centerIn: parent
                width: SettingsStore.recordingIndicatorSize
                height: width
                blinking: SettingsStore.recordingIndicatorBlink
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            GlassLabel { text: "Indicator preview"; color: settingsPageRoot.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            GlassLabel { text: "Preview only · no recording is started"; color: settingsPageRoot.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12); wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
    }
    Repeater {
        model: [
            {label: "Show recording indicator", desc: "Appears only while RusticQ is recording", key: "recordingIndicatorEnabled", icon: "\ue04b"},
            {label: "Blink red dot", desc: "Turn off for a steady recording light", key: "recordingIndicatorBlink", icon: "\ue3a6"}
        ]
        delegate: SettingsToggle { objectName: modelData.key + "-toggle"; perBarMode: false }
    }
    GlassLabel { text: "Corner"; color: settingsPageRoot.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: [
                {key: "top-left", label: "Top left"}, {key: "top-right", label: "Top right"},
                {key: "bottom-left", label: "Bottom left"}, {key: "bottom-right", label: "Bottom right"}
            ]
            delegate: ActionButton {
                required property var modelData
                objectName: "recordingIndicatorCorner-" + modelData.key
                Layout.fillWidth: true
                label: modelData.label
                selected: SettingsStore.recordingIndicatorCorner === modelData.key
                color: selected || activeFocus ? Qt.alpha(settingsPageRoot.settingsTheme.accent, 0.16) : settingsPageRoot.settingsTheme.background
                onClicked: SettingsStore.setRecordingIndicatorCorner(modelData.key)
            }
        }
    }
    Repeater {
        model: [
            {key: "recordingIndicatorSize", label: "Dot size", minimum: 8, maximum: 24},
            {key: "recordingIndicatorOffsetX", label: "Horizontal inset", minimum: 0, maximum: 200},
            {key: "recordingIndicatorOffsetY", label: "Vertical inset", minimum: 0, maximum: 200}
        ]
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 5
            RowLayout {
                Layout.fillWidth: true
                GlassLabel { text: modelData.label; color: settingsPageRoot.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12); Layout.fillWidth: true }
                GlassLabel { text: SettingsStore[modelData.key] + " px"; color: settingsPageRoot.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
            }
            SettingRangeSlider {
                objectName: modelData.key + "-slider"
                Layout.fillWidth: true
                minimum: modelData.minimum
                maximum: modelData.maximum
                value: SettingsStore[modelData.key]
                step: 2
                onPreview: next => SettingsStore.updateRecordingIndicator(modelData.key, next, false)
                onCommit: next => SettingsStore.updateRecordingIndicator(modelData.key, next, true)
            }
        }
    }
}
