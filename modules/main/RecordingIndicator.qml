import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"
import "../../services"

// One small status light per display; it never changes focus or reserves space.
PanelWindow {
    id: root
    visible: SettingsStore.recordingIndicatorEnabled && ScreenRecorder.active && root.screen !== null
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}
    readonly property bool atTop: SettingsStore.recordingIndicatorCorner.indexOf("top-") === 0
    readonly property bool atRight: SettingsStore.recordingIndicatorCorner.endsWith("-right")
    readonly property real horizontalInset: Math.min(SettingsStore.recordingIndicatorOffsetX,
        Math.max(0, (screen ? screen.width : 1920) - implicitWidth))
    readonly property real verticalInset: Math.min(SettingsStore.recordingIndicatorOffsetY,
        Math.max(0, (screen ? screen.height : 1080) - implicitHeight))
    implicitWidth: SettingsStore.recordingIndicatorSize + 12
    implicitHeight: implicitWidth
    anchors {
        top: root.atTop
        bottom: !root.atTop
        right: root.atRight
        left: !root.atRight
    }
    margins {
        top: root.atTop ? root.verticalInset : 0
        bottom: !root.atTop ? root.verticalInset : 0
        right: root.atRight ? root.horizontalInset : 0
        left: !root.atRight ? root.horizontalInset : 0
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: width
        radius: width / 2
        color: Qt.alpha(Theme.error, 0.10)
        border.width: 1
        border.color: Qt.alpha(Theme.error, 0.22)
        opacity: statusDot.opacity
    }
    RecordingDot {
        id: statusDot
        anchors.centerIn: parent
        width: SettingsStore.recordingIndicatorSize
        height: width
        blinking: root.visible && SettingsStore.recordingIndicatorBlink
    }
}
