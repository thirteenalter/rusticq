import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import "../../../components/settings" as Suite
Suite.SettingsPreview {
    id:root
    property string kind:"bar"
    design:SettingsMaterial.forItem(root)
    implicitHeight:kind==="quickcontrol"?240:190
    Rectangle {
        id:rail
        visible:root.kind!=="quickcontrol"
        readonly property bool vertical:SettingsStore.barPosition==="left" || SettingsStore.barPosition==="right"
        x:vertical?(SettingsStore.barPosition==="right"?parent.width-width-12:12):12+Math.min(30,SettingsStore.marginFor("left",0)/3)
        y:SettingsStore.barPosition==="bottom"?parent.height-height-12-Math.min(20,SettingsStore.marginFor("bottom",0)/3):12+Math.min(20,SettingsStore.marginFor("top",0)/3)
        width:vertical?32:parent.width-24;height:vertical?parent.height-24:Math.max(24,Math.min(48,SettingsStore.barIconSize+SettingsStore.paddingFor("top")+SettingsStore.paddingFor("bottom")))
        radius:Math.min(14,(SettingsStore.barCornerRadius<0?14:SettingsStore.barCornerRadius))
        color:SettingsStore.barBackgroundEnabled?Qt.alpha(root.design.base || root.design.background,SettingsStore.barOpacity):"transparent"
        border.width:SettingsStore.barOutlineEnabled?1:0;border.color:root.design.line
        RowLayout {anchors.fill:parent;anchors.margins:7;spacing:SettingsStore.spacingGroup("left",9);visible:!rail.vertical
            Icon {icon:"\ue8b8";color:root.design.foreground}
            Repeater {model:4;delegate:Suite.SettingsLabel {required property int index;design:root.design;text:String(index+1);color:index===0?design.accent:design.muted}}
            Item {Layout.fillWidth:true}
            Suite.SettingsLabel {design:root.design;text:Qt.formatDateTime(new Date(),"ddd, d MMM  hh:mm");font.pixelSize:11}
            Item {Layout.fillWidth:true}
            Icon {icon:"\ue63e";color:root.design.foreground}
            Icon {icon:"\ue050";color:root.design.foreground}
            Icon {icon:"\ue8ac";color:root.design.foreground}
        }
    }
    Rectangle {
        visible:root.kind!=="quickcontrol"
        anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:30
        width:dockIcons.implicitWidth+26;height:48;radius:Math.min(16,14)
        color:Qt.alpha(root.design.base || root.design.background,.62);border.width:1;border.color:root.design.line
        RowLayout {id:dockIcons;anchors.centerIn:parent;spacing:15
            Repeater {model:["\ue2c7","\ueb8e","\ue80b","\ue8b8","\ue5c3"];delegate:Icon {required property string modelData;icon:modelData;font.pixelSize:27;color:root.design.foreground}}
        }
    }
    ColumnLayout {
        visible:root.kind==="quickcontrol";anchors.centerIn:parent;width:Math.min(340,parent.width-48);spacing:8
        RowLayout {Layout.fillWidth:true
            Repeater {model:["Wi-Fi","Bluetooth"];delegate:Rectangle {required property string modelData;Layout.fillWidth:true;height:52;radius:SettingsStore.quickControlComponentRadius;color:Qt.alpha(root.design.base || root.design.background,SettingsStore.quickControlSurfaceOpacity)
                Suite.SettingsLabel {anchors.centerIn:parent;design:root.design;text:modelData}
            }}
        }
        Suite.SettingsLabel {design:root.design;text:"Display & sound";font.pixelSize:12}
        Rectangle {Layout.fillWidth:true;height:28;radius:14;color:root.design.interactive;Rectangle {width:parent.width*.68;height:parent.height;radius:14;color:root.design.foreground}}
        RowLayout {Layout.fillWidth:true;Repeater {model:["Focus","DND","Night","Power"];delegate:Suite.SettingsButton {required property string modelData;design:root.design;text:modelData;Layout.fillWidth:true;enabled:false}}}
        Suite.SettingsLabel {design:root.design;text:SettingsStore.quickControlLayout+" · Advanced controls";font.pixelSize:12}
    }
}
