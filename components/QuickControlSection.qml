import QtQuick
import QtQuick.Layouts
import "../config"

RowLayout {
    property string title:""
    property string detail:""
    Layout.fillWidth:true
    QuickControlLabel {Layout.fillWidth:true;text:parent.title;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(12)}
    QuickControlLabel {visible:parent.detail.length>0;text:parent.detail;color:Theme.contentMuted;font.pixelSize:Fonts.scale(9)}
}
