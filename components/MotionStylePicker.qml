import QtQuick
import QtQuick.Layouts
import "../config"

ColumnLayout {
    id: root
    property string settingKey: "animationStyle"
    Layout.fillWidth: true
    spacing: Theme.sectionGap
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
        radius: Theme.rowRadius
        color: Theme.background
        clip: true
        Rectangle {
            id: previewBar
            anchors.centerIn: parent
            width: Math.max(120, parent.width - 44)
            height: 38
            radius: 12
            color: Theme.surface
            transform: Translate { x: preview.offsetX; y: preview.offsetY }
            RowLayout {
                anchors.centerIn: parent
                spacing: 16
                Icon { icon: "\ue8b6"; color: Theme.accent; font.pixelSize: 18 }
                Text { text: "RusticQ"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                Icon { icon: "\ue63e"; color: Theme.foreground; font.pixelSize: 18 }
                Icon { icon: "\ue1a7"; color: Theme.foreground; font.pixelSize: 18 }
            }
        }
        SurfaceMotion { id: preview; shown: true; target: previewBar; edge: SettingsStore.barPosition; style: SettingsStore[root.settingKey] }
    }
    ActionButton { label: "Preview animation"; symbol: "\ue037"; enabled: Theme.motionEnabled; onClicked: preview.replay() }
}
