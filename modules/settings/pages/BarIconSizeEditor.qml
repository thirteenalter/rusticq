import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

SettingsSection {
    heading: "Bar icon size"
    description: "Set an exact size in pixels. Icon slots and vertical rails grow with the icons."
    symbol: "\ue3c2"
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text { Layout.fillWidth: true; text: "Icon size · 12–32 px"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
        Rectangle {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 34
            radius: Theme.rowRadius
            color: Theme.background
            border.width: 1
            border.color: sizeInput.activeFocus ? Theme.accent : Theme.borderaccent
            TextInput {
                id: sizeInput
                objectName: "barIconSizeInput"
                anchors.fill: parent
                anchors.margins: 7
                text: String(SettingsStore.barIconSize)
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(12)
                selectByMouse: true
                activeFocusOnTab: true
                validator: IntValidator { bottom: 12; top: 32 }
                Accessible.name: "Bar icon size in pixels"
                function commit() {
                    if (acceptableInput) SettingsStore.setBarIconSize(Number(text));
                    text = Qt.binding(function() { return String(SettingsStore.barIconSize); });
                }
                onEditingFinished: commit()
            }
        }
        ActionButton { objectName: "barIconSizeReset"; label: "Reset"; onClicked: SettingsStore.setBarIconSize(16) }
    }
    SettingRangeSlider {
        objectName: "barIconSizeSlider"
        Layout.fillWidth: true
        minimum: 12; maximum: 32; step: 1
        value: SettingsStore.barIconSize
        onPreview: next => SettingsStore.setBarIconSize(next, false)
        onCommit: next => SettingsStore.setBarIconSize(next)
        activeFocusOnTab: true
        Accessible.name: "Bar icon size"
        Keys.onLeftPressed: SettingsStore.setBarIconSize(SettingsStore.barIconSize - 1)
        Keys.onRightPressed: SettingsStore.setBarIconSize(SettingsStore.barIconSize + 1)
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Repeater {
            model: ["\ue63e", "\ue1a7", "\ue8b5", "\ue050", "\ue7f4"]
            delegate: Icon { required property string modelData; icon: modelData; color: Theme.accent; font.pixelSize: Theme.barSymbolSize }
        }
        Item { Layout.fillWidth: true }
        Text { text: SettingsStore.barIconSize + " px"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
    }
}
