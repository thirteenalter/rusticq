import QtQuick
import "../config"

// RusticQ launcher: Material 'terminal' glyph, no Nerd Font/Font Awesome.
Rectangle {
    id: root
    property bool backgroundEnabled: true
    implicitWidth: 24
    implicitHeight: 24
    radius: 8
    color: backgroundEnabled ? Theme.surface : "transparent"
    border.width: backgroundEnabled ? 1 : 0
    border.color: Theme.borderaccent
    Icon {
        anchors.centerIn: parent
        icon: "\ueb8e" // terminal
        font.pixelSize: 17
        color: Theme.accent
    }
}
