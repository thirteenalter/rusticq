import QtQuick
import QtQuick.Layouts
import "../../../services"
import "../components"
import "../../../components/settings" as Suite

Suite.SettingsPreview {
    id: root
    required property var palette
    property string page: "appearance"
    design:palette
    implicitHeight: 230
    property int previewMode:0
    radius: 12
    clip: true
    property int selectedWindow: 0
    property bool playing: false
    readonly property real rounding: Number(HyprlandConfigService.value("decoration:rounding") || 0)
    readonly property real gap: Math.min(22, Number(HyprlandConfigService.value("general:gaps_in") || 0))
    readonly property real outerGap: Math.min(20,Number(HyprlandConfigService.value("general:gaps_out") || 0)/2)
    readonly property string layout: String(HyprlandConfigService.value("general:layout") || "dwindle")
    readonly property real ratio: Math.max(0.2, Math.min(0.8, Number(HyprlandConfigService.value(layout === "master" ? "master:mfact" : "dwindle:default_split_ratio") || 1) / (layout === "master" ? 1 : 2)))
    HyprSettingsLabel { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 12; palette: root.palette; text: "Interactive preview · drag or select a window"; font.pixelSize: 10; color: palette.muted }
    Item {
        id: desktop
        anchors.fill: parent
        anchors.margins: 16 + root.outerGap
        anchors.topMargin: 45
        anchors.rightMargin: root.width>620?230:16
        Repeater {
            model: 3
            Rectangle {
                id: previewWindow
                required property int index
                property real shiftX: 0
                property real shiftY: 0
                visible: root.previewMode===0 || (root.previewMode===1 && index<2) || (root.previewMode===2 && index===0)
                x: (root.previewMode===1?index*desktop.width*0.28:index === 0 ? 0 : desktop.width * root.ratio + root.gap) + shiftX
                y: (root.previewMode===1?index*28:index < 2 ? 0 : desktop.height / 2 + root.gap / 2) + shiftY
                width: root.previewMode===2?desktop.width:root.previewMode===1?desktop.width*0.68:index === 0 ? desktop.width * root.ratio : Math.max(10, desktop.width * (1 - root.ratio) - root.gap)
                height: root.previewMode===1?desktop.height*0.72:index === 0 ? desktop.height : Math.max(10, desktop.height / 2 - root.gap / 2)
                radius: Math.min(root.rounding, 20)
                color: root.selectedWindow === index ? root.palette.group : root.palette.background
                opacity: {
                    const value=HyprlandConfigService.value(root.selectedWindow === index ? "decoration:active_opacity" : "decoration:inactive_opacity");
                    const alpha=value===null || value===undefined ? 1 : Number(value);
                    return alpha*(root.selectedWindow !== index && HyprlandConfigService.value("decoration:dim_inactive") === true ? 1-Number(HyprlandConfigService.value("decoration:dim_strength") || 0) : 1);
                }
                border.width: Math.min(6, Number(HyprlandConfigService.value("general:border_size") || 0))
                border.color: root.palette.compositorColor(HyprlandConfigService.value(root.selectedWindow === index ? "general:col.active_border" : "general:col.inactive_border"),root.selectedWindow === index ? root.palette.accent : root.palette.line)
                Rectangle {
                    z: -1
                    visible: HyprlandConfigService.value("decoration:shadow:enabled") === true
                    readonly property real spread: Math.min(10,Number(HyprlandConfigService.value("decoration:shadow:range") || 0)/2)
                    readonly property color shadowColor: root.palette.compositorColor(HyprlandConfigService.value("decoration:shadow:color"),"#000000")
                    x: -spread; y: 3; width: parent.width+spread*2; height: parent.height+spread
                    radius: parent.radius+spread
                    color: Qt.alpha(shadowColor,shadowColor.a*0.18)
                }
                Row {x:10;y:8;spacing:5;Repeater {model:["#ef746e","#e9bc5d","#77c675"];delegate:Rectangle {required property string modelData;width:7;height:7;radius:4;color:modelData}}}
                HyprSettingsLabel { anchors.centerIn: parent; palette: root.palette; text: root.selectedWindow === index ? "Active window" : "Window " + (index + 1); font.pixelSize: 11 }
                MouseArea {
                    anchors.fill: parent
                    property point initial
                    onPressed: mouse => { root.selectedWindow = previewWindow.index; initial = Qt.point(mouse.x, mouse.y); }
                    onPositionChanged: mouse => { if (pressed) { previewWindow.shiftX += mouse.x - initial.x; previewWindow.shiftY += mouse.y - initial.y; } }
                    onDoubleClicked: { previewWindow.shiftX = 0; previewWindow.shiftY = 0; }
                }
            }
        }
    }
    ColumnLayout {
        visible:root.width>620
        anchors.right:parent.right;anchors.top:parent.top;anchors.bottom:parent.bottom;anchors.margins:18
        width:190;spacing:10
        HyprSettingsLabel {palette:root.palette;text:"Quick Preview";font.bold:true;font.pixelSize:13}
        Suite.SettingsSegmentedControl {design:root.palette;Layout.fillWidth:true;model:["Tiled","Float","Full"];currentIndex:root.previewMode;onSelected:index=>root.previewMode=index}
        RowLayout {Layout.fillWidth:true
            Repeater {model:["dwindle","master"]
                delegate:Suite.SettingsButton {required property string modelData;design:root.palette;text:modelData==="dwindle"?"Dwindle":"Master";Layout.fillWidth:true;enabled:HyprlandConfigService.editable;onClicked:HyprlandConfigService.setOption("general:layout",modelData)}
            }
        }
        Item {Layout.fillHeight:true}
        HyprSettingsLabel {palette:root.palette;text:"Local preview · review before Apply";font.pixelSize:11;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:palette.muted}
    }
}
