import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

Rectangle {
    id:root
    QuickControlInputBridge {target:root;active:QuickControlStyle.modular}
    Layout.fillWidth: true
    Layout.preferredHeight: QuickControlStyle.modular ? 42 : 54
    color: Theme.trsp

    RowLayout {
        visible: !QuickControlStyle.modular
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        spacing: Theme.inlineGap

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: QuickControlStyle.modular ? QuickControlStyle.iconRadius : Theme.glassRadius("card", 10)
            color: QuickControlStyle.modular ? QuickControlStyle.surface(false,false,false) : Theme.glassColor("card", Theme.surface)
            Icon {
                anchors.centerIn: parent
                icon: Store.advancedVisible ? "\ue5c4" : "\ue69b" // stat_minus_1
                font.pixelSize: Fonts.scale(20)
                color: Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                enabled: Store.advancedVisible
                cursorShape: Qt.PointingHandCursor
                onClicked: Store.advancedVisible = false
            }
        }
        GlassLabel {
            Layout.fillWidth: true
            text: Store.advancedVisible ? "Advanced" : "Quick Control"
            font.family: Fonts.poppinsSB.name
            font.pixelSize: Fonts.scale(QuickControlStyle.modular ? 16 : 18)
            color: Theme.foreground
        }
        Rectangle {
            visible: !Store.advancedVisible
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: QuickControlStyle.modular ? QuickControlStyle.iconRadius : Theme.glassRadius("card", 10)
            color: QuickControlStyle.modular ? QuickControlStyle.surface(Store.quickReorderMode,false,false) : Theme.glassColor("card", Store.quickReorderMode ? Qt.alpha(Theme.accent, 0.18) : Theme.surface)
            Icon { anchors.centerIn: parent; icon: "\ue8d5"; font.pixelSize: Fonts.scale(19); color: Store.quickReorderMode ? Theme.accent : Theme.muted }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Store.quickReorderMode = !Store.quickReorderMode
            }
        }
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: QuickControlStyle.modular ? QuickControlStyle.iconRadius : Theme.glassRadius("card", 10)
            color: QuickControlStyle.modular ? QuickControlStyle.surface(false,closeMouse.containsMouse,false) : Theme.glassColor("card", closeMouse.containsMouse ? Theme.accent : Theme.surface)
            Icon {
                anchors.centerIn: parent
                icon: "\ue5cd"  // close
                font.pixelSize: Fonts.scale(20)
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Store.sidebarVisible = false
            }
        }
    }
    RowLayout {
        visible:QuickControlStyle.modular
        anchors.fill:parent
        spacing:QuickControlStyle.gap
        QuickControlIconButton {visible:Store.advancedVisible;symbol:"\ue5c4";label:"Back to Quick Control";onClicked:Store.advancedVisible=false}
        QuickControlLabel {Layout.fillWidth:true;text:Store.advancedVisible ? "Advanced" : "Quick Control";font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(16);elide:Text.ElideRight}
        QuickControlIconButton {objectName:"quickReorderButton";visible:!Store.advancedVisible;symbol:"\ue8d5";label:"Reorder modules";selected:Store.quickReorderMode;onClicked:Store.quickReorderMode=!Store.quickReorderMode}
        QuickControlIconButton {symbol:"\ue5cd";label:"Close Quick Control";onClicked:Store.sidebarVisible=false}
    }
}
