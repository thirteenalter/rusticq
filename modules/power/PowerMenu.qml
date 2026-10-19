import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../config"
import "../../components"

// Beta 1: one focused-monitor floating layer. Keyboard first; destructive
// actions require a second explicit confirmation in this same window.
PanelWindow {
    id: root
    screen: Store.powerScreen
    visible: Store.powerMenuVisible
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    property int selectedIndex: 0
    property string confirmation: ""
    property string errorMessage: ""
    property bool busy: actionProcess.running
    // One pixel grid for both header and *every* action. Qt RowLayout used to
    // distribute spare width differently for long and short labels, moving the
    // title and shortcut numeral horizontally from one option to the next.
    readonly property int iconColumnX: 12
    readonly property int iconColumnWidth: 40
    readonly property int textColumnX: iconColumnX + iconColumnWidth + 12
    readonly property int shortcutColumnWidth: 24
    readonly property int shortcutRightInset: 12
    readonly property var actions: [
        {id:"screensaver", title:"Screensaver", icon:"\ue30b", hint:"Omarchy animated ASCII screensaver"},
        {id:"lock", title:"Lock", icon:"\ue899", hint:"RusticQ Native Lock · WlSessionLock/PAM"},
        {id:"suspend", title:"Suspend", icon:"\uef44", hint:"Sleep until resumed"},
        {id:"logout", title:"Logout", icon:"\ue9ba", hint:"Exit Hyprland session"},
        {id:"reboot", title:"Reboot", icon:"\ue042", hint:"Restart your computer"},
        {id:"shutdown", title:"Shutdown", icon:"\ue8ac", hint:"Power off your computer"}
    ]
    function close() { Store.powerMenuVisible = false; confirmation = ""; errorMessage = ""; }
    function choose(index) {
        if (busy || index < 0 || index >= actions.length) return;
        selectedIndex = index;
        const action = actions[index].id;
        if (confirmation !== action) {
            confirmation = action;
            errorMessage = "";
            return;
        }
        actionProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-power-action.py"), action]);
    }
    onVisibleChanged: if (visible) {
        selectedIndex = 0;
        confirmation = "";
        errorMessage = "";
        Qt.callLater(function() { keyboard.forceActiveFocus(); });
    }
    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.close()
    }
    Process {
        id: actionProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text.trim());
                if (result.ok) root.close();
                else root.errorMessage = result.message || "Power action failed";
            } catch(e) {root.errorMessage = "Power helper failed: " + String(e);}
        } }
        onExited: (code, status) => {if (code !== 0 && !root.errorMessage) root.errorMessage = "Power command exited with " + code; }
    }
    FocusScope {
        id: keyboard
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; }
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                root.selectedIndex = (root.selectedIndex + root.actions.length - 1) % root.actions.length;
                root.confirmation = ""; event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                root.selectedIndex = (root.selectedIndex + 1) % root.actions.length;
                root.confirmation = ""; event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.choose(root.selectedIndex); event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
                root.selectedIndex = event.key - Qt.Key_1;
                root.confirmation = ""; event.accepted = true;
            }
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha("#07090b", 0.60)
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }
        Rectangle {
            id: menuCard
            // Identical frame treatment to MiniLauncher/search: no bright outline.
            width: Math.min(420, Math.max(300, parent.width - 48))
            height: menuContent.implicitHeight + 34
            anchors.centerIn: parent
            radius: Theme.sectionRadius
            color: Theme.background
            border.color: Theme.borderaccent
            border.width: 1
            scale: root.visible ? 1 : .96
            opacity: root.visible ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }
            ColumnLayout {
                id: menuContent
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 17
                spacing: 8
                // Fixed positions: header and option labels share exactly the same x.
                Item {
                    id: headingRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Rectangle {
                        x: root.iconColumnX + (root.iconColumnWidth - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        color: Qt.alpha(Theme.accent, .16)
                        radius: 11
                        Icon { anchors.centerIn: parent; icon: "\ue8ac"; color: Theme.accent; font.pixelSize: Fonts.scale(21) }
                    }
                    Column {
                        x: root.textColumnX
                        width: Math.max(80, headingRow.width - root.textColumnX - root.shortcutColumnWidth - root.shortcutRightInset)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: "System"
                            color: Theme.foreground
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: Fonts.scale(16)
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: "Choose a session action"
                            color: Theme.muted
                            font.pixelSize: Fonts.scale(10)
                            elide: Text.ElideRight
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        id: item
                        required property var modelData
                        required property int index
                        readonly property bool chosen: root.selectedIndex === index
                        readonly property bool awaiting: root.confirmation === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 49
                        radius: 11
                        color: chosen ? Qt.alpha(Theme.accent, .16) : (pointer.containsMouse ? Theme.surface : "transparent")
                        border.color: awaiting ? Theme.warning : chosen ? Qt.alpha(Theme.accent, .65) : "transparent"
                        border.width: awaiting || chosen ? 1 : 0
                        // No RowLayout here: label length must never change x positions.
                        Icon {
                            x: root.iconColumnX
                            width: root.iconColumnWidth
                            height: 40
                            anchors.verticalCenter: parent.verticalCenter
                            icon: item.modelData.icon
                            color: item.awaiting ? Theme.warning : item.chosen ? Theme.accent : Theme.foreground
                            font.pixelSize: Fonts.scale(20)
                        }
                        Column {
                            x: root.textColumnX
                            width: Math.max(80, item.width - root.textColumnX - root.shortcutColumnWidth - root.shortcutRightInset)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: item.modelData.title
                                color: Theme.foreground
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(12)
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: item.awaiting ? "Press Enter / click again to confirm" : item.modelData.hint
                                color: item.awaiting ? Theme.warning : Theme.muted
                                font.pixelSize: Fonts.scale(9)
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: root.shortcutRightInset
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.shortcutColumnWidth
                            horizontalAlignment: Text.AlignRight
                            text: String(item.index + 1)
                            color: item.chosen ? Theme.accent : Theme.muted
                            font.pixelSize: Fonts.scale(11)
                        }
                        MouseArea {
                            id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: {root.selectedIndex = item.index; root.confirmation = "";}
                            onClicked: root.choose(item.index)
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: root.errorMessage.length ? root.errorMessage : "↑ ↓ move · 1–6 quick select · Enter confirm · Esc close"
                    color: root.errorMessage.length ? Theme.error : Theme.muted
                    horizontalAlignment: Text.AlignHCenter; font.pixelSize: Fonts.scale(10)
                }
            }
        }
    }
}
