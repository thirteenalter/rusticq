import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 9
    readonly property var items: [
        {key:"rusticq", name:"RusticQ", icon:"\ue8b8"},
        {key:"arch", name:"Arch / AI", icon:"\uf371"},
        {key:"launcher", name:"App Launcher", icon:"\ue8b6"},
        {key:"menu", name:"Menu bar", icon:"\ue5d2"},
        {key:"workspaces", name:"Workspaces", icon:"\ue30b"},
        {key:"weather", name:"Weather", icon:"\ue430"},
        {key:"time", name:"Clock", icon:"\ue8b5"},
        {key:"date", name:"Calendar", icon:"\uebcc"},
        {key:"bluetooth", name:"Bluetooth", icon:"\ue1a7"},
        {key:"wifi", name:"Wi-Fi", icon:"\ue63e"},
        {key:"battery", name:"Battery", icon:"\uf304"},
        {key:"audio", name:"Volume", icon:"\ue050"},
        {key:"task", name:"Task View", icon:"\ue322"},
        {key:"quickModes", name:"Quick modes", icon:"\ue429"},
        {key:"quickControl", name:"Quick Control", icon:"\ue69b"},
        {key:"mic", name:"Microphone status", icon:"\ue029"},
        {key:"down", name:"Download speed", icon:"\ue5db"},
        {key:"up", name:"Upload speed", icon:"\ue5d8"}
    ]
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "For vertical bars: Left = top, Center = middle, Right = bottom"
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10
            Layout.fillWidth: true; wrapMode: Text.WordWrap
        }
        Rectangle {
            Layout.preferredHeight: 31; Layout.preferredWidth: 82; radius: 9; color: Theme.background
            Text { anchors.centerIn: parent; text: "Reset all"; font.pixelSize: 10; color: Theme.foreground; font.family: Fonts.poppinsSB.name }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetIconPlacements() }
        }
    }
    Repeater {
        model: root.items
        delegate: Rectangle {
            id: iconEntry
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 54
            radius: 10
            color: Theme.background
            RowLayout {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 9
                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    radius: 9; color: Qt.alpha(Theme.accent, .10)
                    Icon { anchors.centerIn: parent; icon: iconEntry.modelData.icon; color: Theme.accent; font.pixelSize: 17 }
                }
                Text {
                    text: iconEntry.modelData.name
                    Layout.fillWidth: true
                    color: Theme.foreground
                    elide: Text.ElideRight
                    font.family: Fonts.poppins.name
                    font.pixelSize: 11
                }
                Repeater {
                    model: [{value:"left", label:"Left"}, {value:"center", label:"Center"}, {value:"right", label:"Right"}]
                    delegate: Rectangle {
                        id: posOption
                        required property var modelData
                        readonly property bool chosen: SettingsStore.placementFor(iconEntry.modelData.key) === modelData.value
                        Layout.preferredWidth: 60; Layout.preferredHeight: 30
                        radius: 8
                        color: chosen ? Qt.alpha(Theme.accent, .17) : Theme.surface
                        border.width: chosen ? 1 : 0
                        border.color: Theme.accent
                        Text { anchors.centerIn: parent; text: posOption.modelData.label; font.pixelSize: 10; color: chosen ? Theme.accent : Theme.muted; font.family: Fonts.poppinsSB.name }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.setIconPlacement(iconEntry.modelData.key, posOption.modelData.value) }
                    }
                }
            }
        }
    }
}
