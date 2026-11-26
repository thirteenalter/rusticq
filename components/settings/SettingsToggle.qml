import QtQuick
import QtQuick.Controls.Basic
import "../../config"

Switch {
    id: root
    required property var design
    spacing: 8
    font.family: Fonts.poppins.name
    font.pixelSize: 13
    indicator: Rectangle {
        x: root.leftPadding; y: (root.height-height)/2
        implicitWidth: 38; implicitHeight: 23; radius: 12
        color: root.checked ? root.design.accent : root.design.background
        border.width: 1; border.color: root.activeFocus ? root.design.accent : root.design.line
        Rectangle {x:root.checked?18:3;y:3;width:17;height:17;radius:9;color:"white";Behavior on x {NumberAnimation {duration:root.design.duration}}}
    }
    contentItem: Text {
        text: root.text; font: root.font; color: root.design.foreground
        leftPadding: root.indicator.width + root.spacing
        verticalAlignment: Text.AlignVCenter
    }
}
