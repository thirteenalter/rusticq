import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

SettingsSection {
    heading: "Bar padding editor"
    description: "Space inside the bar, independent from outer margins and icon gaps. Saved separately for each layout."
    symbol: "\ue9f6"
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Editing: " + SettingsStore.barMode + " · " + SettingsStore.barPosition
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
        ActionButton { objectName: "bar-padding-reset"; label: "Reset mode"; onClicked: SettingsStore.resetBarPadding() }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: width < 440 ? 1 : 2
        columnSpacing: Theme.sectionGap
        rowSpacing: Theme.sectionGap
        Repeater {
            model: [{key: "top", label: "Top"}, {key: "bottom", label: "Bottom"}, {key: "left", label: "Left"}, {key: "right", label: "Right"}]
            delegate: Rectangle {
                id: card
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: fields.implicitHeight + Theme.sectionPadding * 2
                radius: Theme.rowRadius
                color: Theme.background
                ColumnLayout {
                    id: fields
                    x: Theme.sectionPadding; y: Theme.sectionPadding
                    width: Math.max(0, card.width - Theme.sectionPadding * 2)
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: card.modelData.label; Layout.fillWidth: true; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
                        Text { objectName: "bar-padding-" + card.modelData.key + "-label"; text: SettingsStore.paddingFor(card.modelData.key) + " px"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    }
                    SettingRangeSlider {
                        objectName: "bar-padding-" + card.modelData.key
                        Layout.fillWidth: true
                        maximum: 32
                        value: SettingsStore.paddingFor(card.modelData.key)
                        activeFocusOnTab: true
                        Accessible.name: card.modelData.label + " bar padding"
                        onPreview: next => SettingsStore.setBarPadding(card.modelData.key, next, false)
                        onCommit: next => SettingsStore.setBarPadding(card.modelData.key, next, true)
                        Keys.onLeftPressed: SettingsStore.setBarPadding(card.modelData.key, SettingsStore.paddingFor(card.modelData.key) - 1)
                        Keys.onRightPressed: SettingsStore.setBarPadding(card.modelData.key, SettingsStore.paddingFor(card.modelData.key) + 1)
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: "0–32 px on each side. Top/Bottom changes bar height; Left/Right changes sidebar width. Reset restores defaults for the current edge and layout."
        color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        wrapMode: Text.WordWrap
    }
}
