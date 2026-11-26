import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id:root
    required property var design
    property string title:"Advanced"
    property bool expanded:false
    default property alias content:body.data
    Layout.fillWidth:true;spacing:12
    SettingsButton {design:root.design;text:root.title+(root.expanded?" ⌃":" ⌄");onClicked:root.expanded=!root.expanded;Accessible.name:root.title}
    ColumnLayout {id:body;visible:root.expanded;Layout.fillWidth:true;spacing:20}
}
