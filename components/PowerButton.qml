import QtQuick
import "../config"

Rectangle {
    id: root
    property var targetScreen: null
    implicitWidth: 40
    implicitHeight: 24
    color: Store.sidebarVisible && Store.sidebarScreen === targetScreen
           ? Qt.alpha(Theme.accent, 0.25) : Theme.borderaccent
    radius: height / 2

    Rectangle {
        anchors.centerIn: parent
        width: 20
        height: 2
        radius: 1
        color: Theme.foreground
        opacity: 0.75
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Store.sidebarVisible && Store.sidebarScreen === root.targetScreen) {
                Store.sidebarVisible = false;
            } else {
                Store.sidebarScreen = root.targetScreen;
                Store.sidebarVisible = true;
            }
        }
    }
}
