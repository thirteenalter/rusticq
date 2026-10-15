import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 54
    color: Theme.trsp

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 10
            color: Theme.surface
            Icon {
                anchors.centerIn: parent
                icon: Store.advancedVisible ? "\ue5c4" : "\ue8b8"
                font.pixelSize: 20
                color: Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                enabled: Store.advancedVisible
                cursorShape: Qt.PointingHandCursor
                onClicked: Store.advancedVisible = false
            }
        }
        Text {
            Layout.fillWidth: true
            text: Store.advancedVisible ? "Advance" : "Quick Control"
            font.family: Fonts.poppinsSB.name
            font.pixelSize: 18
            color: Theme.foreground
        }
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 10
            color: closeMouse.containsMouse ? Theme.accent : Theme.surface
            Icon {
                anchors.centerIn: parent
                icon: "\ue5cd"  // close
                font.pixelSize: 20
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Store.sidebarVisible = false
            }
        }
    }
}
