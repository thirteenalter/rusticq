import QtQuick
import "../config"

Text {
    id: root

    property alias icon: root.text

    FontLoader {
        id: material
        source: "../assets/google.ttf"
    }

    font.family: material.name
    font.pixelSize: 14

    color: Theme.foreground

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
