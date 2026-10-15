import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

Item {
    id: root
    property int iconSlotWidth: 14
    property bool cleanStyle: false
    readonly property color statusColor: root.cleanStyle && WifiService.connected && WifiService.strength <= 25
        ? Theme.warning : Theme.foreground
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    HoverHandler { id: hover }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.cleanStyle ? Theme.barIconTextGap : 5

        Icon {
            icon: WifiService.icon
            font.pixelSize: root.cleanStyle ? 16 : 14
            color: root.statusColor
            Layout.minimumWidth: root.iconSlotWidth
            Layout.preferredWidth: root.iconSlotWidth
            Layout.maximumWidth: root.iconSlotWidth
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: hover.hovered
            text: !WifiService.enabled ? "Wi-Fi off" : WifiService.connected
                  ? WifiService.ssid : "Disconnected"
            font.family: Fonts.poppins.name
            font.pixelSize: root.cleanStyle ? Theme.controlTextSize : 11
            color: root.statusColor
            elide: Text.ElideRight
            Layout.maximumWidth: 150
        }
    }
}
