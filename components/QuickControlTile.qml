import QtQuick
import QtQuick.Layouts
import "../config"

QuickControlSurface {
    id:root
    property string title:""
    property string subtitle:""
    property string symbol:""
    property bool toggleAvailable:true
    property string iconLabel:"Toggle "+title
    signal toggleRequested()
    signal detailsRequested()
    implicitHeight:QuickControlStyle.compact ? 76 : 88
    hovered:details.containsMouse
    pressed:details.pressed
    RowLayout {
        anchors.fill:parent;anchors.margins:Theme.controlPadding;spacing:QuickControlStyle.gap
        QuickControlIconButton {objectName:"tileToggle";symbol:root.symbol;label:root.iconLabel;selected:root.selected;enabled:root.toggleAvailable;radius:width/2;onClicked:root.toggleRequested()}
        Item {
            Layout.fillWidth:true;Layout.fillHeight:true
            ColumnLayout {anchors.fill:parent;spacing:2
                QuickControlLabel {Layout.fillWidth:true;text:root.title;font.family:Fonts.poppinsSB.name;elide:Text.ElideRight}
                QuickControlLabel {Layout.fillWidth:true;text:root.subtitle;color:Theme.contentMuted;font.pixelSize:Fonts.scale(9);maximumLineCount:2;wrapMode:Text.Wrap;elide:Text.ElideRight}
            }
            MouseArea {id:details;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:root.detailsRequested()}
        }
        Item {
            Layout.preferredWidth:12;Layout.fillHeight:true
            Icon {anchors.centerIn:parent;icon:"\ue5cc";color:Theme.contentMuted;font.pixelSize:Fonts.scale(16)}
            MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.detailsRequested()}
        }
    }
    activeFocusOnTab:true
    Accessible.role:Accessible.Button
    Accessible.name:root.title+", "+root.subtitle+", details"
    Accessible.onPressAction:detailsRequested()
    Keys.onReturnPressed:detailsRequested()
    Keys.onSpacePressed:detailsRequested()
}
