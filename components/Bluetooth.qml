import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

Item {
    id: root
    property int iconSlotWidth: 14
    property bool cleanStyle: false
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    HoverHandler { id: hover }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.cleanStyle ? Theme.barIconTextGap : 5
        Icon {
            icon: BluetoothService.icon
            font.pixelSize: root.cleanStyle ? 16 : 14
            color: Theme.foreground
            Layout.minimumWidth: root.iconSlotWidth
            Layout.preferredWidth: root.iconSlotWidth
            Layout.maximumWidth: root.iconSlotWidth
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: hover.hovered
            text: !BluetoothService.enabled ? "Bluetooth off" : BluetoothService.connected
                  ? BluetoothService.deviceName : "Disconnected"
            font.family: Fonts.poppins.name
            font.pixelSize: root.cleanStyle ? Theme.controlTextSize : 11
            color: Theme.foreground
            elide: Text.ElideRight
            Layout.maximumWidth: 150
        }
    }
}
