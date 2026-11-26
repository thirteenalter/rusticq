import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
RowLayout {
    id:root
    required property var design
    property var model:[]
    property int currentIndex:0
    signal selected(int index)
    spacing:3
    Repeater {model:root.model
        delegate:SettingsButton {required property var modelData;required property int index;design:root.design;text:String(modelData);Layout.fillWidth:true;onClicked:root.selected(index)
            background:Rectangle {radius:8;color:index===root.currentIndex?root.design.selected:parent.hovered?root.design.hover:"transparent";border.width:index===root.currentIndex?1:0;border.color:root.design.line}
        }
    }
}
