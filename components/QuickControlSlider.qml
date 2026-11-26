import QtQuick
import QtQuick.Layouts
import "../config"

ColumnLayout {
    id: root
    property string label: ""
    property string symbol: "\ue050"
    property real value: 0
    property real maximumValue: 1
    property real stepSize: .02
    property real observedMaximum: maximumValue
    readonly property real rangeMaximum: Math.max(maximumValue,observedMaximum)
    onValueChanged: observedMaximum=Math.max(observedMaximum,value)
    onMaximumValueChanged: observedMaximum=Math.max(observedMaximum,maximumValue)
    property bool adjustable: true
    property bool muted: false
    property bool iconEnabled: adjustable
    property bool iconInteractive: true
    property string valueText: adjustable ? Math.round(value*100)+"%" : "Unavailable"
    signal userChanged(real nextValue)
    signal iconClicked()
    spacing: 5
    function submit(fraction) {if(adjustable)userChanged(Math.max(0,Math.min(rangeMaximum,fraction*rangeMaximum)));}
    RowLayout {
        visible:root.label.length>0
        Layout.fillWidth:true
        QuickControlLabel {Layout.fillWidth:true;text:root.label;font.family:Fonts.poppinsSB.name}
        QuickControlLabel {text:root.valueText;color:Theme.contentMuted;font.pixelSize:Fonts.scale(10)}
    }
    RowLayout {
        Layout.fillWidth:true
        spacing:QuickControlStyle.gap
        QuickControlIconButton {visible:root.iconInteractive;symbol:root.symbol;label:root.muted ? "Unmute "+(root.label || "volume") : root.label || "Volume";enabled:root.iconEnabled;selected:root.muted;onClicked:root.iconClicked()}
        Icon {visible:!root.iconInteractive;Layout.preferredWidth:34;icon:root.symbol;color:Theme.contentMuted;font.pixelSize:Fonts.scale(18);horizontalAlignment:Text.AlignHCenter}
        QuickControlSurface {
            id:track
            objectName:"quickSliderTrack"
            Layout.fillWidth:true
            Layout.preferredHeight:QuickControlStyle.compact ? 30 : 34
            radius:height/2
            hovered:pointer.containsMouse
            activeFocusOnTab:true
            opacity:root.adjustable ? 1 : .4
            Accessible.role:Accessible.Slider
            Accessible.name:root.label || "Volume"
            function adjust(delta){if(root.adjustable)root.userChanged(Math.max(0,Math.min(root.rangeMaximum,root.value+delta)));}
            Keys.onLeftPressed:adjust(-root.stepSize)
            Keys.onRightPressed:adjust(root.stepSize)
            Keys.onPressed:event=>{
                if(root.adjustable && (event.key===Qt.Key_Home || event.key===Qt.Key_End)){
                    root.userChanged(event.key===Qt.Key_Home ? 0 : root.rangeMaximum);event.accepted=true;
                }
            }
            Rectangle {
                width:parent.width*Math.max(0,Math.min(1,root.value/root.rangeMaximum))
                height:parent.height;radius:parent.radius
                color:Qt.alpha(root.muted ? Theme.contentMuted : Theme.accent,.7)
                Behavior on width {enabled:QuickControlStyle.motion && !pointer.pressed;NumberAnimation{duration:Theme.motionFastDuration}}
            }
            MouseArea {id:pointer;anchors.fill:parent;hoverEnabled:true;enabled:root.adjustable;cursorShape:Qt.PointingHandCursor
                onPressed:mouse=>{track.forceActiveFocus();root.submit(mouse.x/Math.max(1,width));}
                onPositionChanged:mouse=>{if(pressed)root.submit(mouse.x/Math.max(1,width));}}
        }
    }
}
