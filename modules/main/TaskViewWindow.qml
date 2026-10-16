import QtQuick
import Quickshell
import "../../config"

FloatingWindow {
    visible: Store.taskViewVisible
    title: "RusticQ · Task View"
    implicitWidth: 500
    implicitHeight: 630
    color: Theme.background
    SystemDashboard { anchors.fill: parent; anchors.margins: 4 }
}
