import QtQuick
import "../config"

// Glyph-free brandmark: stays legible without an external Nerd Font.
Rectangle {
    implicitWidth: 24
    implicitHeight: 24
    radius: 8
    color: Theme.surface
    border.color: Theme.borderaccent

    Text {
        anchors.centerIn: parent
        text: "A"
        font.family: Fonts.poppinsB.name
        font.pixelSize: 14
        color: Theme.accent
    }
}
