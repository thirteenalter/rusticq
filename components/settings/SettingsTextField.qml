import QtQuick
import QtQuick.Controls.Basic
import "../../config"

TextField {
    id: root
    required property var design
    implicitHeight: 32
    color: design.foreground
    placeholderTextColor: design.muted
    selectionColor: design.accent
    font.family: Fonts.poppins.name
    font.pixelSize: 13
    selectByMouse: true
    maximumLength: 400
    leftPadding: 10
    rightPadding: 10
    background: Rectangle {
        color: root.design.background
        radius: 7
        border.width: 1
        border.color: root.activeFocus ? root.design.accent : root.design.line
    }
}
