import QtQuick
import "../config"

Rectangle {
    id: dot
    objectName: "recordingDot"
    property bool blinking: false
    property real pulseOpacity: 1
    readonly property bool animating: pulse.running
    implicitWidth: 12
    implicitHeight: implicitWidth
    radius: Math.min(width, height) / 2
    color: Theme.error
    opacity: pulseOpacity
    SequentialAnimation {
        id: pulse
        running: dot.visible && dot.blinking && Theme.motionEnabled
        loops: Animation.Infinite
        NumberAnimation { target: dot; property: "pulseOpacity"; from: 1; to: 0.2; duration: 500 }
        NumberAnimation { target: dot; property: "pulseOpacity"; from: 0.2; to: 1; duration: 500 }
        onStopped: dot.pulseOpacity = 1
    }
}
