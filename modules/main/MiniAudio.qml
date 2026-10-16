import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../config"
import "../../components"

Rectangle {
    id: root
    radius: Theme.sectionRadius
    color: "transparent"
    border.width: 0
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink.audio !== null
    property bool advancedOpen: false

    PwObjectTracker { objects: [root.sink] }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 12
                color: Qt.alpha(Theme.accent, 0.14)
                Icon { anchors.centerIn: parent; icon: root.available && root.sink.audio.muted ? "\ue04f" : "\ue050"; font.pixelSize: 19; color: Theme.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "Audio"; color: Theme.foreground; font.pixelSize: Theme.sectionTitleSize; font.family: Fonts.poppinsSB.name }
                Text { text: root.available ? (root.sink.audio.muted ? "Output muted" : "Default audio output") : "No active output device"; color: Theme.muted; font.pixelSize: 10; font.family: Fonts.poppins.name }
            }
            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 28
                radius: 9
                color: Qt.alpha(Theme.accent, 0.12)
                Text { anchors.centerIn: parent; text: root.available ? Math.round(root.sink.audio.volume * 100) + "%" : "--"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
            }
        }

        ControlSlider {
            Layout.fillWidth: true
            value: root.available ? Math.min(1, root.sink.audio.volume) : 0
            adjustable: root.available
            onUserChanged: (next) => { if (root.available) root.sink.audio.volume = next; }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 10
                color: Theme.surface
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { icon: root.available && root.sink.audio.muted ? "\ue050" : "\ue04f"; color: Theme.accent; font.pixelSize: 18 }
                    Text { text: root.available && root.sink.audio.muted ? "Unmute output" : "Mute output"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 12 }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.available
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sink.audio.muted = !root.sink.audio.muted
                }
            }
            Rectangle {
                Layout.preferredWidth: 118
                Layout.preferredHeight: 40
                radius: 10
                color: root.advancedOpen ? Qt.alpha(Theme.accent, 0.16) : Theme.surface
                border.width: 0
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { icon: root.advancedOpen ? "\ue5ce" : "\ue5cf"; color: Theme.accent; font.pixelSize: 17 }
                    Text { text: "Advanced"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.advancedOpen = !root.advancedOpen
                }
            }
        }

        Rectangle {
            visible: root.advancedOpen
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? advancedContent.implicitHeight + 20 : 0
            radius: 13
            color: Theme.surface
            border.width: 0
            clip: true
            ColumnLayout {
                id: advancedContent
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Text {
                    text: root.available ? "Quick levels" : "Audio output unavailable"
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: 11
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [25, 50, 75, 100]
                        delegate: Rectangle {
                            id: preset
                            required property int modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 9
                            color: root.available && Math.round(root.sink.audio.volume * 100) === modelData ? Qt.alpha(Theme.accent, 0.16) : Theme.background
                            border.width: 0
                            Text { anchors.centerIn: parent; text: preset.modelData + "%"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                            MouseArea {
                                anchors.fill: parent
                                enabled: root.available
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sink.audio.volume = preset.modelData / 100
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.available ? "Muted: " + (root.sink.audio.muted ? "yes" : "no") + " · Volume: " + Math.round(root.sink.audio.volume * 100) + "%" : "Connect or enable a PipeWire output device to control audio here."
                    color: Theme.muted
                    wrapMode: Text.WordWrap
                    font.family: Fonts.poppins.name
                    font.pixelSize: 10
                }
            }
        }
    }
}
