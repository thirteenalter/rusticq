import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

Item {
    id: root
    property int iconSlotWidth: 14
    property bool cleanStyle: false
    readonly property color statusColor: BatteryService.percentage <= 15 && !BatteryService.charging
        ? Theme.error : Theme.foreground
    visible: BatteryService.available
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight

    HoverHandler { id: hover }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.cleanStyle ? Theme.barIconTextGap : 5

        Icon {
            Layout.minimumWidth: root.iconSlotWidth
            Layout.preferredWidth: root.iconSlotWidth
            Layout.maximumWidth: root.iconSlotWidth
            Layout.alignment: Qt.AlignVCenter
            icon: BatteryService.icon
            font.pixelSize: root.cleanStyle ? 16 : 14
            color: root.statusColor
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: BatteryService.percentage + "%" + (BatteryService.charging ? " +" : "")
            visible: true
            color: root.statusColor
            font.family: Fonts.poppins.name
            font.pixelSize: root.cleanStyle ? Theme.controlTextSize : 11
        }
    }
}
