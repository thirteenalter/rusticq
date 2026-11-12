import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../config"

// Shared by Advanced Audio in the popup and Quick Control.
ColumnLayout {
    id: root
    spacing: Theme.sectionGap
    // In Quickshell 0.3.1 AudioOutStream includes the Sink flag. Capture
    // streams (including our peak monitors) have the Source flag instead.
    readonly property var streamCandidates: Pipewire.nodes.values.filter(
        node => node.audio !== null && node.isStream && node.isSink)
    readonly property var playbackStreams: streamCandidates.filter(node => {
        const props = node.properties || ({});
        return String(props["stream.monitor"]) !== "true"
            && props["media.category"] !== "Monitor"
            && props["application.name"] !== "Quickshell Peak Detect"
            && node.name !== "quickshell-peak-monitor";
    })
    PwObjectTracker { objects: root.visible ? root.streamCandidates : [] }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Application audio mixer"
            color: Theme.foreground
            font.family: Fonts.poppinsSB.name
            font.pixelSize: Fonts.scale(11)
        }
        Text {
            text: root.playbackStreams.length + " streams"
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: Theme.helperTextSize
        }
    }
    Text {
        Layout.fillWidth: true
        text: root.playbackStreams.length ? "Audio bus · apps using speaker output"
              : "No applications are using audio output. Play audio in an app to see it here."
        wrapMode: Text.WordWrap
        color: Theme.muted
        font.family: Fonts.poppins.name
        font.pixelSize: Theme.helperTextSize
    }
    Repeater {
        id: streams
        objectName: "applicationAudioStreams"
        model: root.visible ? root.playbackStreams : []
        delegate: Rectangle {
            id: appStream
            required property var modelData
            readonly property var audioNode: modelData
            readonly property var metadata: audioNode.properties || ({})
            readonly property string appName: String(metadata["application.name"]
                || metadata["application.process.binary"] || audioNode.description
                || audioNode.nickname || audioNode.name || "Audio stream")
            readonly property string mediaName: String(metadata["media.name"] || "")
            readonly property bool nativeChannelsKnown: {
                if (!audioNode.ready || !audioNode.audio) return false;
                const channels = audioNode.audio.channels;
                if (!channels || !channels.length) return false;
                for (let i = 0; i < channels.length; ++i)
                    if (channels[i] === PwAudioChannel.Unknown) return false;
                return true;
            }
            readonly property string captureTarget: String(metadata["object.serial"] || audioNode.name || "")
            readonly property real level: audioNode.audio && !audioNode.audio.muted
                ? Math.max(0, Math.min(1, nativeChannelsKnown ? appPeak.peak || 0 : fallbackPeak.peak)) : 0
            Layout.fillWidth: true
            implicitHeight: streamContent.implicitHeight + 16
            radius: Theme.rowRadius
            color: Theme.surface

            PwNodePeakMonitor {
                id: appPeak
                objectName: "appNativePeak"
                node: appStream.nativeChannelsKnown ? appStream.audioNode : null
                enabled: root.visible && appStream.visible && appStream.nativeChannelsKnown
            }
            Process {
                id: fallbackPeak
                property real peak: 0
                property bool failed: false
                command: ["python3", Quickshell.shellPath("scripts/rusticq-audio-peak.py"), appStream.captureTarget]
                running: root.visible && appStream.visible && appStream.audioNode.ready
                         && !appStream.nativeChannelsKnown && appStream.captureTarget.length > 0
                onRunningChanged: if (!running) peak = 0
                stdout: SplitParser {
                    onRead: data => {
                        const value = Number(data);
                        fallbackPeak.failed = !isFinite(value);
                        fallbackPeak.peak = isFinite(value) ? Math.max(0, Math.min(1, value)) : 0;
                    }
                }
                onExited: (code, status) => {
                    fallbackPeak.peak = 0;
                    fallbackPeak.failed = code !== 0;
                }
            }

            ColumnLayout {
                id: streamContent
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Icon { icon: "\ue050"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                    Text {
                        Layout.fillWidth: true
                        text: appStream.appName
                        color: Theme.foreground
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: Theme.helperTextSize
                        elide: Text.ElideRight
                    }
                    Text {
                        text: appStream.audioNode.audio ? Math.round(appStream.audioNode.audio.volume * 100) + "%" : "--"
                        color: Theme.muted
                        font.family: Fonts.poppins.name
                        font.pixelSize: Theme.helperTextSize
                    }
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 27
                        radius: 7
                        color: appStream.audioNode.audio && appStream.audioNode.audio.muted
                               ? Qt.alpha(Theme.accent, 0.20) : Theme.background
                        enabled: !!appStream.audioNode.audio
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: (appStream.audioNode.audio && appStream.audioNode.audio.muted ? "Unmute " : "Mute ") + appStream.appName
                        function toggleMute() {
                            if (appStream.audioNode.audio)
                                appStream.audioNode.audio.muted = !appStream.audioNode.audio.muted;
                        }
                        Accessible.onPressAction: toggleMute()
                        Keys.onReturnPressed: toggleMute()
                        Keys.onSpacePressed: toggleMute()
                        Icon {
                            anchors.centerIn: parent
                            icon: appStream.audioNode.audio && appStream.audioNode.audio.muted ? "\ue04f" : "\ue050"
                            color: Theme.accent
                            font.pixelSize: Fonts.scale(15)
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.toggleMute() }
                    }
                }
                Text {
                    visible: appStream.mediaName.length > 0 && appStream.mediaName !== appStream.appName
                    Layout.fillWidth: true
                    text: appStream.mediaName
                    elide: Text.ElideRight
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(9)
                }
                ControlSlider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    value: appStream.audioNode.audio ? Math.min(1, appStream.audioNode.audio.volume) : 0
                    adjustable: !!appStream.audioNode.audio
                    onUserChanged: value => { if (appStream.audioNode.audio) appStream.audioNode.audio.volume = value; }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: !appStream.nativeChannelsKnown && fallbackPeak.failed ? "Level unavailable" : "Level · live"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9); Layout.fillWidth: true }
                    Text { text: Math.round(appStream.level * 100) + "%"; color: Theme.accent; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9) }
                }
                Rectangle {
                    objectName: "applicationAudioMeter"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 3
                    color: Theme.background
                    Rectangle {
                        width: parent.width * appStream.level
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        Behavior on width { NumberAnimation { duration: 85 } }
                    }
                }
            }
        }
    }
}
