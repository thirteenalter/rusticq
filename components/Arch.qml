import QtQuick
import "../config"

// RusticQ launcher: Material 'network_intel_node' glyph, no Nerd Font/Font Awesome.
BarSurface {
    id: root
    property bool backgroundEnabled: true
    implicitWidth: Math.max(24, Theme.barSymbolSize + 8)
    implicitHeight: implicitWidth
    baseRadius: 8
    baseColor: backgroundEnabled ? Theme.surface : "transparent"
    baseBorderWidth: backgroundEnabled ? 1 : 0
    baseBorderColor: Theme.borderaccent
    Icon {
        anchors.centerIn: parent
        icon: "\uf371" // terminal
        font.pixelSize: Theme.barSymbolSize
        color: Theme.accent
    }
}
