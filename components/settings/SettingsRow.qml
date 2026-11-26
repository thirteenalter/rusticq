import QtQuick
import QtQuick.Layouts
import "../"
Item {
    id: root
    required property var design
    property string label: ""
    property string description: ""
    property string symbol: ""
    property bool separator: true
    property real controlWidth:Math.min(330,width*0.5)
    default property alias controls: controlsRow.data
    // Width belongs to the page layout. Do not feed the responsive control
    // width back into its parent's implicit width during layout negotiation.
    implicitWidth:0
    implicitHeight:Math.max(root.design.rowHeight,contentRow.implicitHeight)+(root.separator?1:0)
    Layout.fillWidth:true
    RowLayout {
        id:contentRow
        anchors.fill:parent;anchors.bottomMargin:root.separator?1:0;spacing:12
        Icon {visible:!!root.symbol;icon:root.symbol;color:root.design.foreground;font.pixelSize:22}
        ColumnLayout {
            Layout.fillWidth:true;Layout.minimumWidth:0;spacing:2
            SettingsLabel {design:root.design;text:root.label;Layout.fillWidth:true}
            SettingsLabel {visible:!!root.description;design:root.design;text:root.description;color:design.muted;font.pixelSize:12;Layout.fillWidth:true;wrapMode:Text.WordWrap}
        }
        RowLayout {
            id:controlsRow;spacing:8
            Layout.preferredWidth:root.controlWidth;Layout.maximumWidth:root.controlWidth
            Item {Layout.fillWidth:true;visible:!controlsRow.children.some(c=>c.objectName==="settings-slider")}
        }
    }
    Rectangle {visible:root.separator;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:1;color:root.design.line}
}
