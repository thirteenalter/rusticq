import QtQuick
import "../"
Rectangle {
    required property var design
    property string symbol: "\ue8b8"
    property int categoryIndex: 0
    property int iconSize: 27
    implicitWidth: iconSize;implicitHeight: iconSize;radius: 7
    color: design.preferences.iconStyle==="neutral" ? design.interactive : ["#568ff5","#8b6dd8","#c16da8","#53a477","#db9b43","#54a5b4"][Math.abs(categoryIndex)%6]
    Icon { anchors.centerIn: parent;icon: parent.symbol;color: "white";font.pixelSize: parent.iconSize*0.7 }
}
