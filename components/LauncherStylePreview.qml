import QtQuick
import Quickshell
import "../config"

// The actual frontend, scaled down. This model only exposes a few installed
// entries for illustration; it has no index, provider process or execution.
Item {
    id:root
    property string style:"spotlight"
    property var entries:[]
    implicitHeight:155
    clip:true
    Rectangle {anchors.fill:parent;radius:Theme.rowRadius;color:Theme.glassColor("card",Theme.background)}
    QtObject {
        id:previewModel
        property string query:"Search applications"
        property var allApps:root.entries
        property var rows:root.entries
        property var frequent:root.entries.slice(0,3)
        property var favorites:[]
        property var recent:[]
        property var recentCommands:[]
        property var categories:[{key:"all",label:"All"},{key:"favorites",label:"Favorites"},{key:"recent",label:"Recent"}]
        property string category:"all"
        property bool toolsMode:false
        property bool searchBusy:false
        property bool calculatorMode:false
        property bool catalogAll:false
        property bool keyboardNavigation:false
        property int selectedIndex:0
        property string calculatorResult:""
        property string calculatorError:""
        property string toolMessage:""
        property bool toolError:false
        property var selected:root.entries.length ? root.entries[0] : null
        function textOf(value){return value===undefined || value===null ? "" : String(value);}
        function iconSource(entry){const icon=textOf(entry.icon);return icon.startsWith("/") ? "file://"+icon : Quickshell.iconPath(icon,true);}
        function pinned(entry){return false;}
    }
    LauncherView {
        id:preview
        style:root.style;controller:previewModel;interactive:false
        screenWidth:1600;screenHeight:1000;inputAnchor:Qt.point(300,180)
        width:implicitWidth;height:implicitHeight
        readonly property real ratio:Math.min((root.width-12)/Math.max(1,width),(root.height-12)/Math.max(1,height))
        transformOrigin:Item.TopLeft;scale:ratio
        x:(root.width-width*ratio)/2;y:(root.height-height*ratio)/2
    }
}
