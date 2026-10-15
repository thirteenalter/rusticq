import QtQuick

Text {
    id: root

    property alias icon: root.text

    FontLoader {
        id: material
        source: "../assets/google.ttf"
    }

    font.family: material.name
    font.pixelSize: 14

    color: "#ebdbb2"

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
