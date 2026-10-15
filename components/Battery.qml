import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

Item {
    id: root
    visible: BatteryService.available
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight

    HoverHandler { id: hover }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Icon {
            Layout.alignment: Qt.AlignVCenter
            icon: BatteryService.icon
            color: BatteryService.percentage <= 15 && !BatteryService.charging
                   ? Theme.error : Theme.foreground
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: BatteryService.percentage + "%" + (BatteryService.charging ? " +" : "")
            visible: true
            color: Theme.foreground
            font.family: Fonts.poppins.name
            font.pixelSize: 11
        }
    }
}
