import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../config"

// Enam workspace mengikuti komposisi bar lama; bukan lagi teks placeholder.
Row {
    id: root
    property bool backgroundEnabled: true
    property int buttonSize: 23
    spacing: 6

    Repeater {
        model: 6

        Rectangle {
            id: workspaceButton
            required property int index
            readonly property int workspaceId: index + 1
            readonly property bool selected: Hyprland.focusedWorkspace !== null
                                              && Hyprland.focusedWorkspace.id === workspaceId
            width: root.buttonSize
            height: root.buttonSize
            radius: 8
            color: !root.backgroundEnabled ? "transparent" : selected ? Theme.accent : Theme.surface
            border.width: root.backgroundEnabled ? 1 : 0
            border.color: selected ? Theme.accent : Theme.borderaccent

            Text {
                anchors.centerIn: parent
                text: workspaceButton.workspaceId
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(11)
                color: workspaceButton.selected
                       ? (root.backgroundEnabled ? Theme.background : Theme.accent) : Theme.foreground
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Hyprland >=0.55 dispatches Lua expressions, older releases
                    // accept the old "workspace N" syntax.
                    const target = String(workspaceButton.workspaceId);
                    Hyprland.dispatch(Hyprland.usingLua
                        ? 'hl.dsp.focus({ workspace = "' + target + '" })'
                        : 'workspace ' + target);
                }
            }
        }
    }
}
