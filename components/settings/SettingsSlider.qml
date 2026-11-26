import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
RowLayout {
    id:root
    objectName:"settings-slider"
    Layout.fillWidth:true
    required property var design
    property real from:0
    property real to:100
    property real value:0
    property real stepSize:1
    property real displayScale:1
    property string suffix:""
    property string accessibleName:"Value"
    signal edited(real value)
    spacing:14
    Slider {
        id:slider;objectName:"settings-suite-slider";Layout.fillWidth:true;Layout.minimumWidth:75
        from:root.from;to:root.to;value:root.value;stepSize:root.stepSize
        Accessible.name:root.accessibleName
        onMoved:root.edited(value)
        background:Rectangle {x:slider.leftPadding;y:slider.height/2-3;width:slider.availableWidth;height:6;radius:3;color:root.design.line
            Rectangle {width:slider.visualPosition*parent.width;height:6;radius:3;color:root.design.accent}
        }
        handle:Rectangle {x:slider.leftPadding+slider.visualPosition*(slider.availableWidth-width);y:(slider.height-height)/2;width:17;height:17;radius:9;color:"#ffffff";border.width:slider.activeFocus?2:0;border.color:root.design.accent}
    }
    SettingsNumberInput {
        design:root.design
        accessibleName:root.accessibleName
        value:root.value*root.displayScale
        from:root.from*root.displayScale;to:root.to*root.displayScale
        stepSize:root.stepSize*root.displayScale
        suffix:root.suffix
        onEdited:value=>root.edited(value/root.displayScale)
    }
}
