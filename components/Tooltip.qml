import QtQuick
import "../services/"
import "../config"

GlassSurface {
    Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
    border.color: Theme.glassBorder("tooltip", "black")
    border.width: Theme.glassBorderWidth("tooltip", 0)
    surfaceRole: "tooltip"
    id: root

    property string text: ""

    visible: motion.presented
    SurfaceMotion { id: motion; shown: TooltipService.visible; target: root; edge: "top"; closedScale: 1 }

    x: TooltipService.x
    y: TooltipService.y + motion.offsetY

    z: 99999

    radius: Theme.glassRadius("tooltip", 8)

    color: Theme.glassColor("tooltip", Theme.surface)


    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 10

    GlassLabel {
        id: label

        anchors.centerIn: parent

        color: Theme.foreground

        text: root.text
    }

}
