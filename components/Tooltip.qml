import QtQuick
import "../services/"
import "../config"

Rectangle {
    id: root

    property string text: ""

    visible: TooltipService.visible

    x: TooltipService.x
    y: TooltipService.y

    z: 99999

    radius: 8

    color: Theme.surface

    opacity: visible ? 1 : 0

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 10

    Text {
        id: label

        anchors.centerIn: parent

        color: Theme.foreground

        text: root.text
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }
}
