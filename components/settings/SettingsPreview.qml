import QtQuick
import "../../config"
SettingsGlassSurface {
    id:root
    property string previewKind:"desktop"
    implicitHeight:200
    clip:true
    color:design.background
    Image {anchors.fill:parent;source:SettingsStore.wallpaperPath?"file://"+SettingsStore.wallpaperPath:"";fillMode:Image.PreserveAspectCrop;asynchronous:true;sourceSize.width:1000}
    Canvas {
        anchors.fill:parent;visible:!SettingsStore.wallpaperPath
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onPaint:{const c=getContext("2d");c.reset();c.fillStyle=root.design.light?"#bdcddd":"#142638";c.fillRect(0,0,width,height);for(let n=0;n<4;n++){c.fillStyle=Qt.alpha(root.design.light?"#7e98b1":"#7494b4",0.10+n*0.025);c.beginPath();c.moveTo(0,height);c.lineTo(0,height*(0.3+n*0.12));c.bezierCurveTo(width*.3,0,width*.55,height,width,height*(.35+n*.15));c.lineTo(width,height);c.closePath();c.fill();}}
    }
}
