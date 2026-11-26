import QtQuick
import QtQuick.Layouts
import "../config"

ColumnLayout {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    property string settingKey: "animationStyle"
    Layout.fillWidth: true
    spacing: root.settingsTheme.sectionGap
    GridLayout {
        Layout.fillWidth: true
        columns: width < 460 ? 2 : 3
        rowSpacing: 8
        columnSpacing: 8
        Repeater {
            model: [{key:"float", label:"Float", symbol:"\ue5d8"},
                {key:"fade", label:"Fade", symbol:"\ue3ab"},
                {key:"slide", label:"Slide", symbol:"\ue5c8"},
                {key:"zoom", label:"Zoom", symbol:"\ue8ff"},
                {key:"spring", label:"Spring", symbol:"\ue9d9"}]
            delegate: ActionButton {
                required property var modelData
                objectName: root.settingKey + "-" + modelData.key
                Layout.fillWidth: true
                label: modelData.label
                symbol: modelData.symbol
                selected: SettingsStore[root.settingKey] === modelData.key
                onClicked: {
                    SettingsStore.setAnimationStyle(root.settingKey, modelData.key);
                    preview.replay();
                }
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 86
        radius: root.settingsTheme.glassRadius("card", root.settingsTheme.rowRadius)
        color: root.settingsTheme.glassColor("card", root.settingsTheme.background)
        clip: true
        Rectangle {
            id: previewBar
            anchors.centerIn: parent
            width: Math.max(120, parent.width - 44)
            height: 38
            radius: root.settingsTheme.glassRadius("card", 12)
            color: root.settingsTheme.glassColor("card", root.settingsTheme.surface)
            transform: Translate { x: preview.offsetX; y: preview.offsetY }
            RowLayout {
                anchors.centerIn: parent
                spacing: 16
                Icon { icon: "\ue8b6"; color: root.settingsTheme.accent; font.pixelSize: 18 }
                GlassLabel { text: "RusticQ"; color: root.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                Icon { icon: "\ue63e"; color: root.settingsTheme.foreground; font.pixelSize: 18 }
                Icon { icon: "\ue1a7"; color: root.settingsTheme.foreground; font.pixelSize: 18 }
            }
        }
        SurfaceMotion { id: preview; shown: true; target: previewBar; edge: SettingsStore.barPosition; style: SettingsStore[root.settingKey] }
    }
    ActionButton { label: "Preview animation"; symbol: "\ue037"; enabled: root.settingsTheme.motionEnabled; onClicked: preview.replay() }
}
