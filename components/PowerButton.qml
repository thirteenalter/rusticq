import QtQuick
import "../config"

Rectangle {
    id: root
    property var targetScreen: null
    implicitWidth: Math.max(40, Theme.barSymbolSize + 12)
    implicitHeight: Math.max(24, Theme.barSymbolSize + 8)
    color: Store.sidebarVisible && Store.sidebarScreen === targetScreen
           ? Qt.alpha(Theme.accent, 0.25) : Theme.borderaccent
    radius: height / 2

    Icon {
        anchors.centerIn: parent
        icon: "\ue69b" // stat_minus_1
        font.pixelSize: Theme.barSymbolSize
        color: Theme.foreground
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
