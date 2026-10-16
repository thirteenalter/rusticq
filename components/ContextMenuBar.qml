import QtQuick
import QtQuick.Layouts
import "../config"

// Optional RusticQ-only menu; not a DBus global menu for the active app.
Item {
    id: root
    property bool vertical: false
    signal menuRequested(string section, var sourceItem)
    implicitWidth: vertical ? 40 : menuRow.implicitWidth
    implicitHeight: vertical ? 36 : 26

    RowLayout {
        id: menuRow
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: ["Edit", "View", "Share"]
            delegate: Rectangle {
                id: menuButton
                required property string modelData
                Layout.preferredWidth: label.implicitWidth + 14
                Layout.preferredHeight: 26
                radius: 7
                color: mouse.containsMouse ? Theme.surface : "transparent"
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: menuButton.modelData
                    color: Theme.foreground
                    font.family: Fonts.poppins.name
                    font.pixelSize: 11
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.menuRequested(menuButton.modelData.toLowerCase(), menuButton)
                }
            }
        }
    }
    Rectangle {
        id: verticalTrigger
        anchors.fill: parent
        visible: root.vertical
        radius: 9
        color: verticalMouse.containsMouse ? Theme.surface : "transparent"
        Icon { anchors.centerIn: parent; icon: "\ue5d2"; font.pixelSize: 20; color: Theme.accent }
        MouseArea {
            id: verticalMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.menuRequested("view", verticalTrigger)
        }
    }
}
