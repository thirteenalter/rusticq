import QtQuick
import "../config"

Rectangle {
    id: root
    default property alias content: container.data
    property int horizontalPadding: 20
    property int verticalPadding: 10
    color: Theme.borderaccent
    radius: height / 2
    // Avoid childrenRect -> centered children -> parent implicit-size cycles.
    implicitWidth: container.implicitWidth + horizontalPadding * 2
    implicitHeight: container.implicitHeight + verticalPadding * 2

    Item {
        id: container
        // The Pill children are overlays anchored inside the Pill;
        // measure their own implicit dimensions, not childrenRect geometry.
        implicitWidth: children.length ? children[0].implicitWidth : 28
        implicitHeight: children.length ? children[0].implicitHeight : 20
        anchors.centerIn: parent
    }
}
