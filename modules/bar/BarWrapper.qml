import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../config"
import "../../components"

PanelWindow {
    id: sideWindow
    anchors.top: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    margins.right: 10
    margins.top: 50
    margins.bottom: 50

    color: "transparent"
    implicitWidth: 400

    HyprlandFocusGrab {
        active: true
        windows: [sideWindow]
        onCleared: Store.sidebarVisible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: 20
        border.width: 1
        border.color: Theme.borderaccent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            BarHeader {}
            BarMain {}

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                radius: 12
                color: Theme.surface

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        icon: Store.advancedVisible ? "\ue5c4" : "\ue429"
                        font.pixelSize: 16
                        color: Theme.accent
                    }
                    Text {
                        text: Store.advancedVisible ? "BACK TO QUICK CONTROL" : "ADVANCE"
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: 11
                        color: Theme.foreground
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: Store.advancedVisible = !Store.advancedVisible
                }
            }
        }
    }
}
