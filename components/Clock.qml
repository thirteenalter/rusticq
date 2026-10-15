import QtQuick
import Quickshell
import "../config"

Pill {
    color: "transparent"
    horizontalPadding: 6
    verticalPadding: 6

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.pixelSize: 13
        font.family: Fonts.poppins.name
        color: Theme.foreground
    }
}
