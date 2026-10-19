import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../config"
import "../../components"
import "../quickcontrol"

PanelWindow {
    id: sideWindow
    anchors.top: true
    anchors.right: true
    anchors.bottom: false
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    margins.right: 10
    margins.top: 50

    color: "transparent"
    implicitWidth: 400
    implicitHeight: Math.max(340, Math.min(sideWindow.screen ? Math.max(340, sideWindow.screen.height - 85) : 690,
                                             Math.min(780, quickCards.preferredContentHeight + 119)))

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
            QuickControlCards { id: quickCards }

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
                        font.pixelSize: Fonts.scale(16)
                        color: Theme.accent
                    }
                    Text {
                        text: Store.advancedVisible ? "BACK TO QUICK CONTROL" : "ADVANCE"
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: Fonts.scale(11)
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
