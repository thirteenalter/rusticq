import QtQuick
import "../config"

Item {
    id: root
    property bool showBackdrop: true
    implicitHeight: Theme.barVertical ? 256 : 116
    Rectangle {
        visible: root.showBackdrop
        anchors.fill: parent
        radius: Theme.rowRadius
        gradient: Gradient {
            GradientStop { position:0; color:Theme.mix(Theme.background,Theme.accent,.4) }
            GradientStop { position:1; color:Theme.background }
        }
    }
    Item {
        anchors.centerIn: parent
        width: Theme.barVertical ? 68 : parent.width-24
        height: Theme.barVertical ? parent.height-24 : 64
        BarSurface {
            objectName: "barPreviewOuter"
            barLayer: "outer"
            anchors.fill: parent
            baseColor: Theme.barBaseBackground
            baseBorderColor: Theme.borderaccent
            baseBorderWidth: Theme.barBaseBorderWidth
            baseRadius: Theme.barBaseCornerRadius
        }
        Repeater {
            model:3
            delegate: Item {
                required property int index
                width: Theme.barVertical ? parent.width : parent.width/3-6
                height: Theme.barVertical ? parent.height/3-6 : parent.height
                x: Theme.barVertical ? 0 : index*(width+9)
                y: Theme.barVertical ? index*(height+9) : 0
                BarSurface {
                    objectName: "barPreviewSegment"
                    anchors.fill: parent
                    barLayer:"segment"
                    baseColor:SettingsStore.barMode === "separated" ? Theme.surface : "transparent"
                    baseBorderWidth:SettingsStore.barMode === "separated" ? 1 : 0
                    baseRadius:12
                }
                BarSurface {
                    objectName:"barPreviewModule"
                    anchors.centerIn: parent
                    width:Math.min(parent.width-8,92);height:32
                    baseRadius:16
                    baseColor:index===1 ? "transparent" : Theme.borderaccent
                    GlassLabel {
                        anchors.centerIn: parent
                        text: parent.parent.index===0 ? "1   2   3" : parent.parent.index===1 ? "12:34" : "Wi-Fi"
                        color:Theme.foreground
                        font.family:Fonts.poppins.name
                        font.pixelSize:Fonts.scale(10)
                    }
                }
            }
        }
    }
}
