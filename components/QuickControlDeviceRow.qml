import QtQuick
import QtQuick.Layouts
import "../config"

QuickControlSurface {
    id:root
    property string label:""
    property string symbol:"\ue050"
    signal clicked()
    implicitHeight:40
    // Device lists are flat. Selection uses icon/check; only interaction fills.
    color:pointer.containsMouse || activeFocus ? QuickControlStyle.surface(false,true,pointer.pressed) : "transparent"
    border.width:activeFocus ? 1 : 0
    activeFocusOnTab:true
    Accessible.role:Accessible.Button
    Accessible.name:label+(selected ? ", selected" : "")
    Accessible.onPressAction:clicked()
    Keys.onReturnPressed:clicked()
    Keys.onSpacePressed:clicked()
    RowLayout {anchors.fill:parent;spacing:QuickControlStyle.gap
        Icon {icon:root.symbol;color:root.selected ? Theme.accent : Theme.contentMuted;font.pixelSize:Fonts.scale(18)}
        QuickControlLabel {Layout.fillWidth:true;text:root.label;elide:Text.ElideRight}
        Icon {visible:root.selected;icon:"\ue5ca";color:Theme.accent;font.pixelSize:Fonts.scale(17)}
    }
    MouseArea {id:pointer;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:root.clicked()}
}
