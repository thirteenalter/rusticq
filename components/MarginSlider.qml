import QtQuick
import "../config"

// Stable geometry: track and thumb share the same width reference.
Item {
    id: slider
    property int value: 0
    property int maximum: 32
    signal preview(int next)
    signal commit(int next)
    function valueAt(px) {
        return Math.max(0, Math.min(maximum, Math.round(((px - 8) / Math.max(1, width - 16)) * maximum)));
    }
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 9; radius: 5; color: Theme.background
        Rectangle {
            height: parent.height; radius: 5; color: Theme.accent
            width: Math.max(4, (parent.width - 16) * slider.value / slider.maximum + 8)
        }
    }
    Rectangle {
        width: 16; height: 16; radius: 8; color: Theme.foreground
        border.width: 2; border.color: Theme.accent
        anchors.verticalCenter: parent.verticalCenter
        x: (parent.width - width) * slider.value / slider.maximum
    }
    MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onPressed: mouse => slider.preview(slider.valueAt(mouse.x))
        onPositionChanged: mouse => { if (pressed) slider.preview(slider.valueAt(mouse.x)); }
        onReleased: mouse => slider.commit(slider.valueAt(mouse.x))
    }
}
