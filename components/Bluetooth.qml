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
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    HoverHandler { id: hover }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.cleanStyle ? Theme.barIconTextGap : 5
        Icon {
            icon: BluetoothService.icon
            font.pixelSize: Theme.barSymbolSize
            color: Theme.foreground
            Layout.minimumWidth: root.iconSlotWidth
            Layout.preferredWidth: root.iconSlotWidth
            Layout.maximumWidth: root.iconSlotWidth
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: root.forceDetails || (!root.cleanStyle && hover.hovered)
            text: !BluetoothService.enabled ? "Bluetooth off" : BluetoothService.connected
                  ? BluetoothService.deviceName : "Disconnected"
            font.family: Fonts.poppins.name
            font.weight: Font.Medium
            font.pixelSize: Theme.barTextSize
            color: Theme.foreground
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
