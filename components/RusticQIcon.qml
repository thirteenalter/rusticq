import QtQuick

Item {
    id: root
    property int iconSize: 24
    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        anchors.fill: parent
        source: "../assets/rusticq-app-icon.svg"
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        sourceSize.width: Math.max(32, Math.round(width * 2))
        sourceSize.height: Math.max(32, Math.round(height * 2))
    }
}
