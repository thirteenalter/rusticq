import QtQuick
import QtQuick.Controls.Basic
import "../../config"
Button {
    id: root
    required property var design
    property bool primary: false
    implicitHeight: 32
    implicitWidth: Math.max(32,contentItem.implicitWidth+22)
    Accessible.name: text
    contentItem: Text { text: root.text;color: root.primary ? "white" : root.design.foreground;font.family: Fonts.poppins.name;font.pixelSize: Fonts.scale(13);horizontalAlignment: Text.AlignHCenter;verticalAlignment: Text.AlignVCenter;opacity: root.enabled?1:0.45 }
    background: Rectangle {
        radius: 7;color: root.primary?root.design.accent:root.down?root.design.selected:root.hovered?root.design.hover:root.design.interactive
        border.width: root.activeFocus?2:root.design.outlineWidth;border.color: root.activeFocus?root.design.accent:root.design.line
        Behavior on color { ColorAnimation { duration: root.design.duration } }
    }
}
