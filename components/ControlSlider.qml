import QtQuick
import "../config"

Item {
    id: root
    property real value: 0
    property bool adjustable: true
    signal userChanged(real nextValue)
    implicitHeight: 28
    implicitWidth: 160
    function submit(x) {
        if (!adjustable) return;
        userChanged(Math.max(0, Math.min(1, x / Math.max(1, track.width))));
    }
    Rectangle {
        id: track
        width: parent.width
        height: 7
        radius: 4
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.surface
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: 4
            color: root.adjustable ? Theme.accent : Theme.muted
        }
    }
    Rectangle {
        x: track.width * Math.max(0, Math.min(1, root.value)) - width/2
        anchors.verticalCenter: parent.verticalCenter
        width: 15; height: 15; radius: 8
        color: Theme.foreground
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.adjustable
        cursorShape: Qt.PointingHandCursor
        onPressed: root.submit(mouse.x)
        onPositionChanged: if (pressed) root.submit(mouse.x)
    }
}
