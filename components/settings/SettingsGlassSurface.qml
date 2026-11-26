import QtQuick

Rectangle {
    id: root
    required property var design
    property string material: "group"
    color: material==="window" ? (design.windowColor===undefined?design.background:design.windowColor) : material==="sidebar" ? (design.sidebar===undefined?design.surface:design.sidebar) : material==="popover" ? (design.popover===undefined?design.background:design.popover) : material==="interactive" ? (design.interactive===undefined?design.surface:design.interactive) : (design.group===undefined?design.surface:design.group)
    radius: material==="window" ? (design.windowRadius===undefined?design.sectionRadius:design.windowRadius) : material==="sidebar" ? 0 : material==="interactive" ? 7 : 12
    border.width: material==="sidebar" ? 0 : (design.outlineWidth===undefined?1:design.outlineWidth)
    border.color: material==="window" ? (design.outline===undefined?design.borderaccent:design.outline) : (design.line===undefined?design.borderaccent:design.line)
    Rectangle {
        anchors.top: parent.top;anchors.left: parent.left;anchors.right: parent.right
        anchors.leftMargin: root.radius;anchors.rightMargin: root.radius
        height: 1
        visible: root.design.glassEnabled && (root.design.outlineWidth===undefined?1:root.design.outlineWidth)>0
        color: Qt.alpha("white",root.material==="window" ? 0.20 : 0.07)
    }
}
