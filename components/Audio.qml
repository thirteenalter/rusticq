import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../config"

Item {
    id: root
    signal activated()
    property int iconSlotWidth: 14
    property bool cleanStyle: false
    property bool showValue: true
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink.audio !== null
    readonly property int percentage: available ? Math.round(sink.audio.volume * 100) : 0
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    PwObjectTracker { objects: [root.sink] }
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.cleanStyle ? Theme.barIconTextGap : 5
        Icon {
            icon: !root.available || root.sink.audio.muted ? "\ue04f" : root.percentage <= 1 ? "\ue04e" : root.percentage < 55 ? "\ue04d" : "\ue050"
            font.pixelSize: Theme.barSymbolSize
            color: Theme.foreground
            Layout.preferredWidth: root.iconSlotWidth
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            visible: root.showValue
            Layout.preferredWidth: visible ? implicitWidth : 0
            text: root.available ? root.percentage + "%" : "–"
            font.family: Fonts.poppins.name
            font.weight: Font.Medium
            font.pixelSize: Theme.barTextSize
            color: Theme.foreground
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
