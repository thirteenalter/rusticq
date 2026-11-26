import QtQuick
import QtQuick.Layouts
import "../config"

QuickControlSurface {
    id:root
    property string label:""
    property string value:""
    property string symbol:""
    property real level:0
    implicitHeight:QuickControlStyle.compact ? 70 : 78
    ColumnLayout {anchors.fill:parent;anchors.margins:8;spacing:3
        Icon {icon:root.symbol;color:Theme.accent;font.pixelSize:Fonts.scale(16)}
        QuickControlLabel {Layout.fillWidth:true;text:root.value;font.family:Fonts.poppinsSB.name;elide:Text.ElideRight;font.pixelSize:Fonts.scale(12)}
        QuickControlLabel {Layout.fillWidth:true;text:root.label;color:Theme.contentMuted;font.pixelSize:Fonts.scale(9);elide:Text.ElideRight}
        Rectangle {Layout.fillWidth:true;implicitHeight:2;radius:1;color:Qt.alpha(Theme.foreground,.1)
            Rectangle {width:parent.width*Math.max(0,Math.min(1,root.level));height:2;radius:1;color:Theme.accent}}
    }
}
