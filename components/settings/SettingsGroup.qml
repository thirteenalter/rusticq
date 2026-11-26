import QtQuick
import QtQuick.Layouts
import "../../config"

ColumnLayout {
    id: root
    required property var design
    property string title: ""
    property string description: ""
    property string symbol: ""
    property bool expanded: true
    property real contentSpacing: Theme.sectionGap
    readonly property string search:SettingsMaterial.highlightForItem(root)
    readonly property bool highlighted:!!search && !!title && (title.toLowerCase().includes(search.toLowerCase()) || search.toLowerCase().includes(title.toLowerCase()))
    onHighlightedChanged:if(highlighted)Qt.callLater(function(){if(root && root.highlighted)SettingsMaterial.reveal(root);})
    default property alias controls: content.data
    spacing: 8
    Layout.fillWidth: true
    ColumnLayout {
        visible: !!root.title
        Layout.fillWidth:true;spacing:3
        SettingsLabel { design:root.design;text:root.title;font.pixelSize:16;font.bold:true;Layout.fillWidth:true }
        SettingsLabel { visible:!!root.description;design:root.design;text:root.description;color:design.muted;font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true }
    }
    SettingsGlassSurface {
        visible:root.expanded;Layout.fillWidth:true;design:root.design
        color:root.highlighted?Qt.alpha(root.design.accent,0.14):(root.design.group===undefined?root.design.surface:root.design.group)
        implicitHeight:content.implicitHeight+Theme.sectionPadding*2
        ColumnLayout {
            id:content;objectName:"surfaceContent"
            x:Theme.sectionPadding;y:Theme.sectionPadding;width:Math.max(0,parent.width-Theme.sectionPadding*2)
            spacing:root.contentSpacing
        }
    }
}
