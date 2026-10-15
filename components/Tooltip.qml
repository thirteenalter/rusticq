import QtQuick
import "../services/"

Rectangle {
    id: root

    property string text: ""

    visible: TooltipService.visible

    x: TooltipService.x
    y: TooltipService.y

    z: 99999

    radius: 8

    color: "#3c3836"

    opacity: visible ? 1 : 0

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 10

    Text {
        id: label

        anchors.centerIn: parent

        color: "#ebdbb2"

        text: root.text
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }
}
