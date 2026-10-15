import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../config"

// Enam workspace mengikuti komposisi bar lama; bukan lagi teks placeholder.
Row {
    id: root
    spacing: 6

    Repeater {
        model: 6

        Rectangle {
            id: workspaceButton
            required property int index
            readonly property int workspaceId: index + 1
            readonly property bool selected: Hyprland.focusedWorkspace !== null
                                              && Hyprland.focusedWorkspace.id === workspaceId
            width: 23
            height: 23
            radius: 8
            color: selected ? Theme.accent : Theme.surface
            border.width: 1
            border.color: selected ? Theme.accent : Theme.borderaccent

            Text {
                anchors.centerIn: parent
                text: workspaceButton.workspaceId
                font.family: Fonts.poppins.name
                font.pixelSize: 11
                color: workspaceButton.selected ? Theme.background : Theme.foreground
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
