import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

Item {
    id: root
    property string kind: "mic"
    property bool vertical: false
    property bool showDetails: true
    readonly property bool muted: QuickModesService.active("mic")
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    RowLayout {
        id: content
        spacing: 5
        Icon {
            icon: root.kind === "mic" ? (root.muted ? "\ue02b" : "\ue029") : root.kind === "down" ? "\ue5db" : "\ue5d8"
            font.pixelSize: Fonts.scale(17)
            color: root.kind === "mic" && root.muted ? Theme.muted : Theme.accent
        }
        Text {
            visible: root.showDetails && !root.vertical
            text: root.kind === "mic" ? (QuickModesService.available("mic") ? (root.muted ? "Off" : "On") : "N/A") :
                  SystemMetrics.speed(root.kind === "down" ? SystemMetrics.rxPerSec : SystemMetrics.txPerSec)
            color: Theme.foreground
            font.family: Fonts.poppinsSB.name
            font.pixelSize: Fonts.scale(10)
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.kind === "mic" && QuickModesService.available("mic")
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: QuickModesService.toggle("mic")
    }
}
