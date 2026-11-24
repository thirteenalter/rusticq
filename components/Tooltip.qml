import QtQuick
import "../services/"
import "../config"

Rectangle {
    id: root

    property string text: ""

    visible: motion.presented
    SurfaceMotion { id: motion; shown: TooltipService.visible; target: root; edge: "top"; closedScale: 1 }

    x: TooltipService.x
    y: TooltipService.y + motion.offsetY

    z: 99999

    radius: 8

    color: Theme.surface


    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 10

    Text {
        id: label

        anchors.centerIn: parent

        color: Theme.foreground

        text: root.text
    }

}
