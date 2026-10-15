import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../config"
import "../../components"

Rectangle {
    id: root
    radius: Theme.sectionRadius
    color: Qt.alpha(Theme.foreground, 0.02)
    border.color: Theme.borderaccent
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink.audio !== null
    PwObjectTracker { objects: [root.sink] }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Icon { icon: "\ue050"; font.pixelSize: 20; color: Theme.accent }
            Text { text: "Audio"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: Theme.sectionTitleSize; font.family: Fonts.poppinsSB.name }
            Text { text: root.available ? Math.round(root.sink.audio.volume * 100) + "%" : "Unavailable"; color: Theme.muted; font.pixelSize: Theme.controlTextSize; font.family: Fonts.poppins.name }
        }
        ControlSlider {
            Layout.fillWidth: true
            value: root.available ? Math.min(1, root.sink.audio.volume) : 0
            adjustable: root.available
            onUserChanged: (next) => { if (root.available) root.sink.audio.volume = next; }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 10
            color: Theme.surface
            RowLayout {
                anchors.centerIn: parent
                spacing: 9
                Icon { icon: root.available && root.sink.audio.muted ? "\ue04f" : "\ue050"; color: Theme.accent; font.pixelSize: 18 }
                Text { text: root.available && root.sink.audio.muted ? "Unmute output" : "Mute output"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 12 }
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.available
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sink.audio.muted = !root.sink.audio.muted
            }
        }
    }
}
