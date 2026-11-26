import QtQuick
import QtQuick.Window
import QtQml.Models
import Quickshell
import "../config"

Region {
    id:root
    required property Item windowItem
    property real revision:0
    readonly property Instantiator builder:Instantiator {
        model:Store.quickControlInputItems
        delegate:Region {
            required property var modelData
            readonly property var rect:QuickControlStyle.hitRect(modelData,root.windowItem,root.revision)
            x:rect.x;y:rect.y;width:rect.width;height:rect.height
        }
        onObjectAdded:(index,object)=>root.regions.push(object)
        onObjectRemoved:(index,object)=>{const position=root.regions.indexOf(object);if(position>=0)root.regions.splice(position,1);}
    }
}
