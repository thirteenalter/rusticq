import QtQuick
import QtQuick.Controls.Basic
import "../../config"
import "../"
TextField {
    id: root
    required property var design
    implicitHeight: 36
    placeholderText: "Search settings…"
    leftPadding: 34;rightPadding: 12
    font.family: Fonts.poppins.name;font.pixelSize: Fonts.scale(13)
    color: design.foreground;placeholderTextColor: design.muted;selectionColor: design.accent
    selectByMouse: true
    Accessible.name: "Search all settings"
    background: Rectangle { color: root.design.interactive;radius: 8;border.width: 1;border.color: root.activeFocus?root.design.accent:root.design.outline }
    Icon { x: 10;anchors.verticalCenter: parent.verticalCenter;icon: "\ue8b6";color: root.design.muted;font.pixelSize: 18 }
}
