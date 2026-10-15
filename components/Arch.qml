import QtQuick
import "../config"

// Glyph-free brandmark: stays legible without an external Nerd Font.
Rectangle {
    property bool backgroundEnabled: true
    implicitWidth: 24
    implicitHeight: 24
    radius: 8
    color: backgroundEnabled ? Theme.surface : "transparent"
    border.width: backgroundEnabled ? 1 : 0
    border.color: Theme.borderaccent

    Text {
        anchors.centerIn: parent
        text: "A"
        font.family: Fonts.poppinsB.name
        font.pixelSize: 14
        color: Theme.accent
    }
}
