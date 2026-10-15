import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

Pill {
    id: root
    property bool showIcon: false
    color: "transparent"
    horizontalPadding: 7
    verticalPadding: 6

    RowLayout {
        spacing: Theme.barIconTextGap
        Icon {
            visible: root.showIcon
            icon: "\ue430"
            font.pixelSize: 14
            Layout.minimumWidth: Theme.barIconSlotSize
            Layout.preferredWidth: Theme.barIconSlotSize
            Layout.maximumWidth: Theme.barIconSlotSize
            Layout.preferredHeight: Theme.barIconSlotSize
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            // wttr.in %t already includes °C or °F; do not append a second degree.
            text: WeatherService.temperature !== "" ? WeatherService.temperature : "--°"
            color: Theme.foreground
            font.family: Fonts.poppins.name
            font.pixelSize: Theme.controlTextSize
        }
    }
}
