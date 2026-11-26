import QtQuick
import "../config"

QuickControlSurface {
    id: root
    property string symbol: ""
    property string label: ""
    signal clicked()
    implicitWidth: 34
    implicitHeight: 34
    radius: QuickControlStyle.iconRadius
    hovered: pointer.containsMouse
    pressed: pointer.pressed
    opacity: enabled ? 1 : .4
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if(enabled)clicked()
    Keys.onSpacePressed: if(enabled)clicked()
    Keys.onReturnPressed: if(enabled)clicked()
    Icon {anchors.centerIn:parent;icon:root.symbol;color:root.selected ? Theme.accent : Theme.foreground;font.pixelSize:Fonts.scale(18)}
    MouseArea {id:pointer;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{root.forceActiveFocus();root.clicked();}}
}
