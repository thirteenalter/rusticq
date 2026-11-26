import QtQuick
import "../config"

// Preserve installed icon colors; broken desktop-entry paths get a neutral
// fallback instead of leaving an invisible application target.
Item {
    id: root
    property alias source: image.source
    signal unavailable(string failedSource)
    Image {
        id: image
        anchors.fill:parent
        asynchronous:true
        cache:true
        fillMode:Image.PreserveAspectFit
        sourceSize:Qt.size(root.width,root.height)
        visible:status===Image.Ready
        onStatusChanged:if(status===Image.Error)root.unavailable(String(source))
    }
    Icon {
        anchors.centerIn:parent
        visible:image.status!==Image.Ready
        icon:"\ue5c3"
        color:Theme.contentMuted
        font.pixelSize:Math.min(root.width,root.height)*0.8
    }
}
