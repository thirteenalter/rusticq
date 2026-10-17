import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../config"
import "../../components"

// Compact single audio card; height is measured from content, not the popup.
Rectangle {
    id: root
    implicitWidth: 350
    implicitHeight: content.implicitHeight + 24
    radius: Theme.sectionRadius
    color: "transparent"
    border.width: 0
    property bool advancedOpen: false
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool available: sink !== null && sink.audio !== null
    readonly property var outputDevices: Pipewire.nodes.values.filter(n => n.audio !== null && n.isSink && !n.isStream)
    readonly property var inputDevices: Pipewire.nodes.values.filter(n => n.audio !== null && !n.isSink && !n.isStream)
    PwObjectTracker { objects: [root.sink, root.source].concat(root.outputDevices, root.inputDevices).filter(n => n !== null) }
    ColumnLayout {
        id: content
        x: 12; y: 12; width: parent.width - 24
        spacing: 12
        RowLayout {
            Layout.fillWidth: true; spacing: 9
            Rectangle { Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 10; color: Qt.alpha(Theme.accent, .13)
                Icon { anchors.centerIn: parent; icon: root.available && root.sink.audio.muted ? "\ue04f" : "\ue050"; font.pixelSize: 18; color: Theme.accent }
            }
            ColumnLayout { Layout.fillWidth: true; spacing: 1
                Text { text: "Audio"; color: Theme.foreground; font.pixelSize: Fonts.scale(13); font.family: Fonts.poppinsSB.name }
                Text { text: root.available ? (root.sink.description || "Default audio output") : "Output unavailable"; Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.muted; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppins.name }
            }
            Text { text: root.available ? Math.round(root.sink.audio.volume * 100) + "%" : "--"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
        }
        ControlSlider { Layout.fillWidth: true; Layout.preferredHeight: 28
            value: root.available ? Math.min(1, root.sink.audio.volume) : 0
            adjustable: root.available
            onUserChanged: next => { if (root.available) root.sink.audio.volume = next; }
        }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 10; color: Theme.surface
                RowLayout { anchors.centerIn: parent; spacing: 7
                    Icon { icon: root.available && root.sink.audio.muted ? "\ue050" : "\ue04f"; font.pixelSize: 16; color: Theme.accent }
                    Text { text: root.available && root.sink.audio.muted ? "Unmute" : "Mute output"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
                }
                MouseArea { anchors.fill: parent; enabled: root.available; cursorShape: Qt.PointingHandCursor; onClicked: root.sink.audio.muted = !root.sink.audio.muted }
            }
            Rectangle { Layout.preferredWidth: 118; Layout.preferredHeight: 36; radius: 10; color: root.advancedOpen ? Qt.alpha(Theme.accent,.16) : Theme.surface
                RowLayout { anchors.centerIn: parent; spacing: 6
                    Icon { icon: root.advancedOpen ? "\ue5ce" : "\ue5cf"; color: Theme.accent; font.pixelSize: 17 }
                    Text { text: "Advanced"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.advancedOpen = !root.advancedOpen }
            }
        }
        ColumnLayout { visible: root.advancedOpen; Layout.fillWidth: true; spacing: 9
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
            RowLayout { Layout.fillWidth: true
                Text { text: "Microphone"; Layout.fillWidth: true; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                Text { text: root.source && root.source.audio ? Math.round(root.source.audio.volume * 100) + "%" : "N/A"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
            }
            ControlSlider { Layout.fillWidth: true; Layout.preferredHeight: 26
                value: root.source && root.source.audio ? Math.min(1, root.source.audio.volume) : 0
                adjustable: !!(root.source && root.source.audio)
                onUserChanged: next => { if (root.source && root.source.audio) root.source.audio.volume = next; }
            }
            Text { text: "Output device"; color: Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
            Repeater { model: root.outputDevices
                delegate: Rectangle { id: output; required property var modelData; Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8
                    color: Pipewire.defaultAudioSink === modelData ? Qt.alpha(Theme.accent,.16) : Theme.surface
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        Text { Layout.fillWidth: true; text: output.modelData.description || output.modelData.name; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                        Icon { visible: Pipewire.defaultAudioSink === output.modelData; icon: "\ue5ca"; color: Theme.accent; font.pixelSize: 16 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Pipewire.preferredDefaultAudioSink = output.modelData }
                }
            }
            Text { text: "Input device · microphone"; color: Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
            Text { visible: root.inputDevices.length === 0; text: "No microphone available"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
            Repeater { model: root.inputDevices
                delegate: Rectangle { id: input; required property var modelData; Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8
                    color: Pipewire.defaultAudioSource === modelData ? Qt.alpha(Theme.accent,.16) : Theme.surface
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 7
                        Icon { icon: "\ue029"; color: Theme.accent; font.pixelSize: 16 }
                        Text { Layout.fillWidth: true; text: input.modelData.description || input.modelData.name; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                        Icon { visible: Pipewire.defaultAudioSource === input.modelData; icon: "\ue5ca"; color: Theme.accent; font.pixelSize: 16 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Pipewire.preferredDefaultAudioSource = input.modelData }
                }
            }
        }
    }
}
