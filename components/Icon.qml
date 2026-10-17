import QtQuick
import "../config"

Text {
    id: root

    property alias icon: root.text

    FontLoader {
        id: material
        source: "../assets/google.ttf"
    }

    font.family: material.status === FontLoader.Ready ? material.name : "Material Symbols Rounded"
    font.pixelSize: Fonts.scale(14)

    color: Theme.foreground

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
