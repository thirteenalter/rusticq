import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Io
import "../../config"
import "../../components"

// Separate advanced page, reached through the footer. Never replaces the
// classic Gruvbox UI; the regular control page is restored with Back.
Flickable {
    id: root
    clip: true
    contentHeight: advanceContent.implicitHeight + 10
    boundsBehavior: Flickable.StopAtBounds

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var player: Mpris.players.values.length ? Mpris.players.values[0] : null
    readonly property var outputDevices: Pipewire.nodes.values.filter(
        (node) => node.audio !== null && node.isSink && !node.isStream)
    readonly property var inputDevices: Pipewire.nodes.values.filter(
        (node) => node.audio !== null && !node.isSink && !node.isStream)
    property bool audioExpanded: true
    property bool screenExpanded: false
    property bool mediaExpanded: true
    property real brightness: 0
    property int pendingBrightness: 50
    property bool brightnessAvailable: false
    property string brightnessError: ""

    PwObjectTracker { objects: [root.sink, root.source].concat(root.outputDevices, root.inputDevices).filter(node => node !== null) }
    Process {
        id: brightnessRead
        command: ["brightnessctl", "-c", "backlight", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = this.text.trim();
                const matched = result.match(/(\d+)%/);
                if (matched) {
                    root.brightness = Math.max(0, Math.min(1, Number(matched[1]) / 100));
                    root.brightnessAvailable = true;
                    root.brightnessError = "";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.brightnessAvailable = false;
                root.brightnessError = "brightnessctl unavailable or no backlight device";
            }
        }
    }
    Process {
        id: brightnessWrite
        command: ["brightnessctl", "-c", "backlight", "set", "50%"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) root.brightnessError = "Backlight permission denied";
        }
    }
    Timer {
        id: readTimer
        interval: 5000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: if (!brightnessRead.running && !brightnessWrite.running) brightnessRead.running = true
    }
    Timer {
        // Debounce drag updates to avoid spawning a process for every pixel.
        id: brightnessDebounce
        interval: 130
        onTriggered: {
            if (brightnessWrite.running) {
                restart();
                return;
            }
            brightnessWrite.command = ["brightnessctl", "-c", "backlight", "set", root.pendingBrightness + "%"];
            brightnessWrite.running = true;
        }
    }
    function setBrightness(level) {
        if (!brightnessAvailable) return;
        pendingBrightness = Math.round(Math.max(0.01, Math.min(1, level)) * 100);
        brightness = pendingBrightness / 100;
        brightnessDebounce.restart();
    }

    ColumnLayout {
        id: advanceContent
        width: root.width
        spacing: 10

        Text {
            text: "Advanced controls"
            font.family: Fonts.poppinsSB.name
            font.pixelSize: 18
            color: Theme.foreground
            Layout.leftMargin: 10
            Layout.topMargin: 6
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.bottomMargin: 4
            text: "Audio, screen, monitors and media"
            font.family: Fonts.poppins.name
            font.pixelSize: 11
            color: Theme.muted
        }

        Rectangle {
            id: audioCard
            Layout.fillWidth: true
            Layout.preferredHeight: root.audioExpanded ? audioInner.implicitHeight + 28 : 64
            radius: 18; clip: true
            color: Qt.alpha(Theme.foreground, 0.025)
            border.color: Theme.borderaccent
            ColumnLayout {
                id: audioInner
                anchors.fill: parent; anchors.margins: 14
                spacing: 9
                SectionHeader {
                    title: "Audio"
                    iconName: "\ue050"
                    expanded: root.audioExpanded
                    onToggleRequested: root.audioExpanded = !root.audioExpanded
                }
                ColumnLayout {
                    visible: root.audioExpanded
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Icon {
                            icon: root.sink && root.sink.audio && root.sink.audio.muted ? "\ue04f" : "\ue050"
                            font.pixelSize: 19
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                enabled: root.sink !== null && root.sink.audio !== null
                                onClicked: root.sink.audio.muted = !root.sink.audio.muted
                            }
                        }
                        Text { text: "Output"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: 12; font.family: Fonts.poppins.name }
                        Text {
                            text: root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) + "%" : "N/A"
                            color: Theme.muted; font.pixelSize: 12
                        }
                    }
                    ControlSlider {
                        Layout.fillWidth: true
                        value: root.sink && root.sink.audio ? Math.min(1, root.sink.audio.volume) : 0
                        adjustable: root.sink && root.sink.audio
                        onUserChanged: (next) => { if (root.sink && root.sink.audio) root.sink.audio.volume = next; }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Icon {
                            icon: root.source && root.source.audio && root.source.audio.muted ? "\ue02b" : "\ue029"
                            font.pixelSize: 19
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                enabled: root.source !== null && root.source.audio !== null
                                onClicked: root.source.audio.muted = !root.source.audio.muted
                            }
                        }
                        Text { text: "Microphone"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: 12; font.family: Fonts.poppins.name }
                        Text {
                            text: root.source && root.source.audio ? Math.round(root.source.audio.volume * 100) + "%" : "N/A"
                            color: Theme.muted; font.pixelSize: 12
                        }
                    }
                    ControlSlider {
                        Layout.fillWidth: true
                        value: root.source && root.source.audio ? Math.min(1, root.source.audio.volume) : 0
                        adjustable: root.source && root.source.audio
                        onUserChanged: (next) => { if (root.source && root.source.audio) root.source.audio.volume = next; }
                    }
                    Text {
                        text: "Output device"
                        color: Theme.muted; font.pixelSize: 11; font.family: Fonts.poppinsSB.name
                    }
                    Repeater {
                        model: root.outputDevices
                        delegate: Rectangle {
                            id: outputDevice
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 30
                            radius: 8; color: Pipewire.defaultAudioSink === modelData ? Qt.alpha(Theme.accent, 0.15) : Theme.surface
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                Text {
                                    Layout.fillWidth: true
                                    text: outputDevice.modelData.description || outputDevice.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: 10; font.family: Fonts.poppins.name; color: Theme.foreground
                                }
                                Icon {
                                    icon: "\ue5ca"; font.pixelSize: 16; color: Theme.accent
                                    visible: Pipewire.defaultAudioSink === outputDevice.modelData
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pipewire.preferredDefaultAudioSink = outputDevice.modelData
                            }
                        }
                    }
                    Text {
                        text: "Input device · microphone"
                        color: Theme.muted; font.pixelSize: 11; font.family: Fonts.poppinsSB.name
                    }
                    Text {
                        visible: root.inputDevices.length === 0
                        text: "No microphone capture source found"
                        font.pixelSize: 10; color: Theme.muted; font.family: Fonts.poppins.name
                    }
                    Repeater {
                        model: root.inputDevices
                        delegate: Rectangle {
                            id: inputDevice
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 8
                            color: Pipewire.defaultAudioSource === modelData ? Qt.alpha(Theme.accent, 0.15) : Theme.surface
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                Icon { icon: "\ue029"; font.pixelSize: 16; color: Theme.accent; Layout.preferredWidth: 20 }
                                Text {
                                    Layout.fillWidth: true
                                    text: inputDevice.modelData.description || inputDevice.modelData.nickname || inputDevice.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: 10; font.family: Fonts.poppins.name; color: Theme.foreground
                                }
                                Icon {
                                    icon: "\ue5ca"; font.pixelSize: 16; color: Theme.accent
                                    Layout.preferredWidth: 20
                                    visible: Pipewire.defaultAudioSource === inputDevice.modelData
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pipewire.preferredDefaultAudioSource = inputDevice.modelData
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.screenExpanded ? 180 + monitorControls.implicitHeight : 64
            radius: 18; clip: true
            color: Qt.alpha(Theme.foreground, 0.025)
            border.color: Theme.borderaccent
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14
                spacing: 8
                SectionHeader {
                    title: "Screen"
                    iconName: "\ue30b"
                    expanded: root.screenExpanded
                    onToggleRequested: root.screenExpanded = !root.screenExpanded
                }
                ColumnLayout {
                    visible: root.screenExpanded
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Icon { icon: "\ue3ab"; font.pixelSize: 19 }
                        Text { text: "Brightness"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: 12; font.family: Fonts.poppins.name }
                        Text { text: root.brightnessAvailable ? Math.round(root.brightness * 100) + "%" : "N/A"; color: Theme.muted; font.pixelSize: 12 }
                    }
                    ControlSlider {
                        Layout.fillWidth: true
                        value: root.brightness
                        adjustable: root.brightnessAvailable
                        onUserChanged: (next) => root.setBrightness(next)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.brightnessError || "Backlight via brightnessctl (laptop displays)"
                        color: root.brightnessError ? Theme.error : Theme.muted
                        font.family: Fonts.poppins.name; font.pixelSize: 10; wrapMode: Text.WordWrap
                    }
                    BarMonitors {
                        id: monitorControls
                        Layout.fillWidth: true
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.mediaExpanded ? 158 : 64
            radius: 18; clip: true
            color: Qt.alpha(Theme.foreground, 0.025)
            border.color: Theme.borderaccent
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14
                spacing: 8
                SectionHeader {
                    title: "Media"
                    iconName: "\ue3a1"
                    expanded: root.mediaExpanded
                    onToggleRequested: root.mediaExpanded = !root.mediaExpanded
                }
                ColumnLayout {
                    visible: root.mediaExpanded
                    Layout.fillWidth: true
                    spacing: 5
                    Text {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackTitle || root.player.identity) : "No media player"
                        elide: Text.ElideRight
                        color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: root.player ? (root.player.trackArtist || root.player.identity) : "Open a music player to use media controls"
                        color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 18
                        Icon {
                            icon: "\ue045"; font.pixelSize: 24
                            opacity: root.player && root.player.canGoPrevious ? 1 : 0.4
                            MouseArea { anchors.fill: parent; enabled: root.player && root.player.canGoPrevious; cursorShape: Qt.PointingHandCursor; onClicked: root.player.previous() }
                        }
                        Icon {
                            icon: root.player && root.player.isPlaying ? "\ue034" : "\ue037"
                            font.pixelSize: 27; color: Theme.accent
                            opacity: root.player && root.player.canTogglePlaying ? 1 : 0.4
                            MouseArea { anchors.fill: parent; enabled: root.player && root.player.canTogglePlaying; cursorShape: Qt.PointingHandCursor; onClicked: root.player.togglePlaying() }
                        }
                        Icon {
                            icon: "\ue044"; font.pixelSize: 24
                            opacity: root.player && root.player.canGoNext ? 1 : 0.4
                            MouseArea { anchors.fill: parent; enabled: root.player && root.player.canGoNext; cursorShape: Qt.PointingHandCursor; onClicked: root.player.next() }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 12
            color: Theme.surface
            border.width: 1; border.color: Theme.borderaccent
            RowLayout {
                anchors.centerIn: parent; spacing: 9
                Icon { icon: "\ue8b8"; font.pixelSize: 19; color: Theme.accent }
                Text {
                    text: "SEE FULL SETTINGS"
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: 12
                    color: Theme.foreground
                }
                Icon { icon: "\ue5cc"; font.pixelSize: 18; color: Theme.accent }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: Store.showSettings("appearance")
            }
        }
    }
}
