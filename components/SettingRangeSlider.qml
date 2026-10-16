import QtQuick
import "../config"

// Reusable integer slider, no hidden hard-coded maximum or clipped handle.
Item {
    id: slider
    property int minimum: 0
    property int maximum: 100
    property int value: 0
    property int step: 1
    signal preview(int next)
    signal commit(int next)
    implicitHeight: 26
    readonly property real ratio: Math.max(0, Math.min(1, (value - minimum) / Math.max(1, maximum - minimum)))
    function valueAt(pos) {
        const t = Math.max(0, Math.min(1, (pos - 9) / Math.max(1, width - 18)));
        const num = minimum + t * (maximum - minimum);
        return Math.max(minimum, Math.min(maximum, Math.round(num / Math.max(1, step)) * Math.max(1, step)));
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 8
        radius: 4
        color: Theme.background
        Rectangle {
            height: parent.height
            width: 9 + (parent.width - 18) * slider.ratio
            radius: 4
            color: Theme.accent
        }
    }
    Rectangle {
        width: 18
        height: 18
        radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: (parent.width - width) * slider.ratio
        color: Theme.foreground
        border.width: 2
        border.color: Theme.accent
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => slider.preview(slider.valueAt(mouse.x))
        onPositionChanged: mouse => { if (pressed) slider.preview(slider.valueAt(mouse.x)); }
        onReleased: mouse => slider.commit(slider.valueAt(mouse.x))
    }
}
