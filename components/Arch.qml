import QtQuick
import "../config"

// RusticQ launcher: Material 'network_intel_node' glyph, no Nerd Font/Font Awesome.
Rectangle {
    id: root
    property bool backgroundEnabled: true
    implicitWidth: Math.max(24, Theme.barSymbolSize + 8)
    implicitHeight: implicitWidth
    radius: 8
    color: backgroundEnabled ? Theme.surface : "transparent"
    border.width: backgroundEnabled ? 1 : 0
    border.color: Theme.borderaccent
    Icon {
        anchors.centerIn: parent
        icon: "\uf371" // terminal
        font.pixelSize: Theme.barSymbolSize
        color: Theme.accent
    }
}
