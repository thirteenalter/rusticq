import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    HoverHandler { id: hover }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Icon { icon: WifiService.icon; Layout.alignment: Qt.AlignVCenter }
        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: hover.hovered
            text: !WifiService.enabled ? "Wi-Fi off" : WifiService.connected
                  ? WifiService.ssid : "Disconnected"
            font.family: Fonts.poppins.name
            font.pixelSize: 11
            color: Theme.foreground
            elide: Text.ElideRight
            Layout.maximumWidth: 150
        }
    }
}
