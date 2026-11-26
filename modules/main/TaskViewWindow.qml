import QtQuick
import Quickshell
import "../../config"
import "../../components"

FloatingWindow {
    id: root
    readonly property bool presented: motion.presented
    visible: presented
    SurfaceMotion { id: motion; shown: Store.taskViewVisible; target: root.contentItem; closedScale: 0.995 }
    title: "RusticQ · Task View"
    implicitWidth: 500
    implicitHeight: 630
    color: Theme.glassColor("window", Theme.background)
    SystemDashboard { anchors.fill: parent; anchors.margins: 0; transform: Translate { x: motion.offsetX; y: motion.offsetY } }
}
