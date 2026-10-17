import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

Item {
    id: root
    signal activated()
    property int iconSlotWidth: 14
    property bool cleanStyle: false
    property bool forceDetails: false
    readonly property color statusColor: WifiService.ethernetConnected ? Theme.foreground :
        (root.cleanStyle && WifiService.connected && WifiService.strength <= 25 ? Theme.warning : Theme.foreground)
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    HoverHandler { id: hover }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.cleanStyle ? Theme.barIconTextGap : 5

        Icon {
            icon: WifiService.ethernetConnected ? "\ue1e2" : WifiService.icon
            font.pixelSize: Theme.barSymbolSize
            color: root.statusColor
            Layout.minimumWidth: root.iconSlotWidth
            Layout.preferredWidth: root.iconSlotWidth
            Layout.maximumWidth: root.iconSlotWidth
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: root.forceDetails || (!root.cleanStyle && hover.hovered)
            text: WifiService.ethernetConnected ? "Ethernet" : !WifiService.enabled ? "Wi-Fi off" : WifiService.connected
                  ? WifiService.ssid : "Disconnected"
            font.family: Fonts.poppins.name
            font.weight: Font.Medium
            font.pixelSize: Theme.barTextSize
            color: root.statusColor
            elide: Text.ElideRight
            Layout.maximumWidth: 150
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
