import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import "../../../config"
import "../../../components"
import ".."

SettingsSection {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    heading: "Timer & alarm sound"
    description: "Choose a sound, repeat behaviour and an independent volume up to 125%."
    symbol: "\ue050"
    property int draftVolume: SettingsStore.clockSoundVolume
    Connections {
        target: SettingsStore
        function onClockSoundVolumeChanged() { root.draftVolume = SettingsStore.clockSoundVolume; }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ActionButton {
            objectName: "clock-sound-toggle"
            Layout.fillWidth: true
            label: SettingsStore.clockSoundEnabled ? "Sound on" : "Sound off"
            symbol: SettingsStore.clockSoundEnabled ? "\ue050" : "\ue04f"
            selected: SettingsStore.clockSoundEnabled
            onClicked: { SettingsStore.clockSoundEnabled = !SettingsStore.clockSoundEnabled; SettingsStore.save(); }
        }
        ActionButton {
            objectName: "clock-sound-test"
            Layout.fillWidth: true
            label: Store.clockSoundPlaying ? "Stop sound" : "Test sound"
            enabled: SettingsStore.clockSoundEnabled && (Store.clockSoundPlaying || !Store.clockAlertKind)
            onClicked: {
                if (Store.clockSoundPlaying) {
                    if (Store.clockAlertKind) Store.dismissClockAlert();
                    else Store.clockSoundStopped();
                }
                else Store.clockSoundRequested(false);
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: ["chime", "bell", "digital"]
            delegate: ActionButton {
                required property string modelData
                objectName: "clock-sound-" + modelData
                Layout.fillWidth: true
                label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                selected: SettingsStore.clockSound === modelData
                onClicked: SettingsStore.setClockSound(modelData, "")
            }
        }
    }
    ActionButton {
        objectName: "clock-sound-file"
        Layout.fillWidth: true
        label: "Choose audio file…"
        symbol: "\ue2c7"
        selected: SettingsStore.clockSound === "custom"
        onClicked: soundPicker.open()
    }
    GlassLabel {
        visible: SettingsStore.clockSound === "custom"
        Layout.fillWidth: true
        text: SettingsStore.clockSoundFile.split("/").pop()
        textFormat: Text.PlainText
        color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        elide: Text.ElideMiddle
    }
    RowLayout {
        Layout.fillWidth: true
        GlassLabel { text: "Clock volume"; Layout.fillWidth: true; color: root.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
        GlassLabel { objectName: "clock-sound-volume-label"; text: root.draftVolume + "%"; color: root.settingsTheme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
    }
    SettingRangeSlider {
        objectName: "clock-sound-volume"
        Layout.fillWidth: true
        minimum: 0; maximum: 125; step: 5
        value: root.draftVolume
        activeFocusOnTab: true
        Accessible.name: "Clock sound volume, maximum 125 percent"
        onPreview: next => root.draftVolume = next
        onCommit: next => SettingsStore.setClockSoundVolume(next)
        Keys.onLeftPressed: SettingsStore.setClockSoundVolume(Math.max(0, SettingsStore.clockSoundVolume - 5))
        Keys.onRightPressed: SettingsStore.setClockSoundVolume(Math.min(125, SettingsStore.clockSoundVolume + 5))
    }
    ActionButton {
        objectName: "clock-sound-loop"
        Layout.fillWidth: true
        label: SettingsStore.clockSoundLoop ? "Repeat until stopped" : "Play once"
        symbol: "\ue040"
        selected: SettingsStore.clockSoundLoop
        onClicked: { SettingsStore.clockSoundLoop = !SettingsStore.clockSoundLoop; SettingsStore.save(); }
    }
    GlassLabel {
        Layout.fillWidth: true
        text: Store.clockSoundError || "Clock sounds play even in Silent mode. Volume boosts this sound only; system mute still applies."
        color: Store.clockSoundError ? root.settingsTheme.error : root.settingsTheme.muted
        font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        wrapMode: Text.WordWrap
    }
    FileDialog {
        id: soundPicker
        title: "Choose a clock sound"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Audio files (*.wav *.ogg *.flac *.mp3)"]
        onAccepted: {
            const url = selectedFile.toString();
            if (url.startsWith("file://")) SettingsStore.setClockSound("custom", decodeURIComponent(url.slice(7)));
        }
    }
}
