import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../components"
import "../../config"
import "../../services"

// A useful RusticQ settings/view/share menu, inspired by the familiar
// macOS menu bar. No claims of controlling another application's Edit menu.
// Keyboard focus belongs to this menu's PopupWindow, never the desktop bar.
FocusScope {
    id: root
    function focusedScreen() {
        const focus = Hyprland.focusedMonitor;
        if (focus) for (let i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === focus.name) return Quickshell.screens[i];
        return Quickshell.screens.length ? Quickshell.screens[0] : null;
    }
    property string section: "view"
    property string currentSection: section
    property int selectedIndex: 0
    focus: true
    onSectionChanged: currentSection = section
    onCurrentSectionChanged: {
        selectedIndex = 0;
        Qt.callLater(function() { entryList.contentY = 0; });
    }
    onSelectedIndexChanged: Qt.callLater(ensureSelectedVisible)
    signal actionFinished()
    signal sectionNavigated(string sectionKey)
    anchors.fill: parent
    readonly property var sections: [
        {key: "file", title: "File", enabled: SettingsStore.modeIconVisible("showMenuFile")},
        {key: "edit", title: "Edit", enabled: SettingsStore.modeIconVisible("showMenuEdit")},
        {key: "view", title: "View", enabled: SettingsStore.modeIconVisible("showMenuView")},
        {key: "share", title: "Share", enabled: SettingsStore.modeIconVisible("showMenuShare")},
        {key: "shell", title: "Shell", enabled: SettingsStore.modeIconVisible("showMenuShell")},
        {key: "tools", title: "Tools", enabled: SettingsStore.modeIconVisible("showMenuTools")}
    ].filter(item => item.enabled)
    readonly property var entries: currentSection === "file" ? [
        {title: "Home folder", desc: "Open your home directory", icon: "\ue2c7", action: "file-home"},
        {title: "Downloads", desc: "Browse downloads", icon: "\ue2c4", action: "file-downloads"},
        {title: "RusticQ config", desc: "Open current shell directory", icon: "\ue8b8", action: "file-config"}
    ] : currentSection === "shell" ? [
        {title: "Open terminal", desc: "Use an installed terminal emulator", icon: "\ueb8e", action: "shell-terminal"},
        {title: "System monitor", desc: "Live CPU, GPU, RAM, disk and network", icon: "\uef43", action: "shell-monitor"},
        {title: "Power menu", desc: "Keyboard accessible system actions", icon: "\ue8ac", action: "shell-power"}
    ] : currentSection === "tools" ? [
        {title: "Settings", desc: "Personalize RusticQ", icon: "\ue8b8", action: "tools-settings"},
        {title: "Screenshot region", desc: "Capture a selected area", icon: "\ue3c2", action: "tools-region"}
    ] : currentSection === "edit" ? [
        { title: "Appearance settings", desc: "Themes and Aether source", icon: "\ue40a", action: "appearance" },
        { title: "Bar settings", desc: "Position, modules and menus", icon: "\ue8b8", action: "bar" },
        { title: "AI settings", desc: "Choose cloud provider", icon: "\uea4a", action: "ai" }
    ] : currentSection === "share" ? [
        { title: "Screenshot screen", desc: "Save PNG in Pictures/Screenshots", icon: "\ue3af", action: "full" },
        { title: "Screenshot region", desc: "Select area using slurp", icon: "\ue3c2", action: "region" },
        { title: ScreenRecorder.active ? "Stop recording" : "Record screen", desc: ScreenRecorder.active ? "Save current video" : "Select a monitor and record MP4", icon: "\ue04b", action: ScreenRecorder.active ? "stop" : "start-screen" },
        { title: "Record region", desc: "Choose an area before recording", icon: "\ue3c2", action: "start-region" },
        { title: "Record with audio", desc: "Monitor video and default audio input", icon: "\ue029", action: "start-audio" },
        { title: "Screen sharing portal", desc: "Check the automatic live/meeting selector", icon: "\ue30b", action: "portal-check" },
        { title: "Open recordings", desc: "Videos/RusticQ", icon: "\ue2c7", action: "record-folder" },
        { title: "Open screenshots", desc: "View saved captures", icon: "\ue2c7", action: "folder" }
    ] : [
        {title: "Compact", desc: "Tight controls", icon: "\ue5d1", action: "compact"},
        {title: "Clean Compact", desc: "Minimal buttons", icon: "\ue5d1", action: "clean-compact"},
        {title: "Separated", desc: "Floating islands", icon: "\ue86c", action: "separated"},
        {title: "Professional", desc: "Solid desktop bar", icon: "\ue30b", action: "professional"},
        {title: "Simple", desc: "Essential actions only", icon: "\ue5d4", action: "simple"}
    ]
    function selectSection(key) {
        if (!sections.some(item => item.key === key)) return;
        currentSection = key;
        sectionNavigated(key);
    }
    // Left/right traverse only enabled sections; up/down traverse action rows.
    // All four directions wrap, so a keyboard-only user can reach every item.
    function switchSection(direction) {
        if (!sections.length) return;
        let current = sections.findIndex(item => item.key === currentSection);
        if (current < 0) current = 0;
        const next = (current + direction + sections.length) % sections.length;
        selectSection(sections[next].key);
    }
    function moveSelection(direction) {
        if (!entries.length) return;
        selectedIndex = (selectedIndex + direction + entries.length) % entries.length;
    }
    function ensureSelectedVisible() {
        if (!entryList || !entryList.visible || !entries.length) return;
        // Each row is 54px with 6px spacing, including the long Share menu.
        const rowTop = selectedIndex * 60;
        const rowBottom = rowTop + 54;
        if (rowTop < entryList.contentY) entryList.contentY = rowTop;
        else if (rowBottom > entryList.contentY + entryList.height)
            entryList.contentY = Math.min(Math.max(0, entryList.contentHeight - entryList.height), rowBottom - entryList.height);
    }
    function activateSelection() {
        if (entries.length && selectedIndex >= 0 && selectedIndex < entries.length)
            runAction(entries[selectedIndex].action);
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) { switchSection(-1); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { switchSection(1); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { moveSelection(-1); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { moveSelection(1); event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activateSelection(); event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            actionFinished(); event.accepted = true;
        }
    }
    Component.onCompleted: Qt.callLater(function() { root.forceActiveFocus(); })
    function runAction(action) {
        if (currentSection === "view") {
            SettingsStore.barMode = action;
            SettingsStore.save();
        } else if (currentSection === "edit") {
            Store.showSettings(action);
        } else if (currentSection === "file" || currentSection === "shell" || currentSection === "tools") {
            if (action === "shell-monitor") Store.systemMonitorVisible = true;
            else if (action === "shell-power") Store.togglePowerMenu(root.focusedScreen());
            else if (action === "tools-settings") Store.showSettings("bar");
            else if (action === "tools-region") Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/rustiq-capture.sh"), "region"]);
            else Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/rustiq-menu-action.sh"), action]);
        } else if (currentSection === "share" && ["start-screen", "start-region", "start-audio", "stop", "portal-check", "record-folder"].indexOf(action) !== -1) {
            ScreenRecorder.action(action === "record-folder" ? "folder" : action);
        } else {
            Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/rustiq-capture.sh"), action]);
        }
        root.actionFinished();
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 9
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "RusticQ / " + root.currentSection.charAt(0).toUpperCase() + root.currentSection.slice(1); font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13); color: Theme.foreground; Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 8
                color: Qt.alpha(Theme.accent, 0.10)
                Icon { anchors.centerIn: parent; icon: "\ue5d2"; color: Theme.accent; font.pixelSize: Fonts.scale(16) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            Repeater {
                model: root.sections
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 31
                    radius: 9
                    color: root.currentSection === modelData.key ? Qt.alpha(Theme.accent, .21) : Theme.surface
                    border.width: root.currentSection === modelData.key ? 1 : 0
                    border.color: Theme.accent
                    Text {
                        anchors.centerIn: parent
                        text: tab.modelData.title
                        font.family: Fonts.poppins.name
                        font.pixelSize: Fonts.scale(11)
                        color: root.currentSection === tab.modelData.key ? Theme.accent : Theme.foreground
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.selectSection(tab.modelData.key); root.forceActiveFocus(); }
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
        Flickable {
            id: entryList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: entryColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: entryColumn
                width: parent.width
                spacing: 6
                Repeater {
                    model: root.entries
                    delegate: Rectangle {
                        id: choice
                        required property var modelData
                        required property int index
                        readonly property bool selected: root.selectedIndex === index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        color: selected || choiceMouse.containsMouse ? Qt.alpha(Theme.accent, .16) : Theme.surface
                        radius: 11
                        border.width: selected || choiceMouse.containsMouse ? 1 : 0
                        border.color: Qt.alpha(Theme.accent, 0.32)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 10
                                color: Qt.alpha(Theme.accent, 0.12)
                                Icon { anchors.centerIn: parent; icon: choice.modelData.icon; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { Layout.fillWidth: true; text: choice.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11); elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: choice.modelData.desc; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9); elide: Text.ElideRight }
                            }
                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: 7
                                color: root.currentSection === "view" && SettingsStore.barMode === choice.modelData.action ? Qt.alpha(Theme.accent, 0.14) : "transparent"
                                Icon {
                                    anchors.centerIn: parent
                                    visible: root.currentSection === "view" && SettingsStore.barMode === choice.modelData.action
                                    icon: "\ue5ca"
                                    color: Theme.accent
                                    font.pixelSize: Fonts.scale(16)
                                }
                            }
                        }
                        MouseArea {
                            id: choiceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = choice.index
                            onClicked: { root.selectedIndex = choice.index; root.runAction(choice.modelData.action); }
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "← → category  ·  ↑ ↓ action  ·  Enter open  ·  Esc close"
            font.pixelSize: Fonts.scale(9)
            font.family: Fonts.poppins.name
            color: Theme.accent
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: root.currentSection === "share" ? (ScreenRecorder.active ? "Recording in progress · stop to finalize MP4" : "Captures saved locally · grim / slurp / wf-recorder") : "RusticQ shortcuts · not an application global menu"
            wrapMode: Text.WordWrap
            font.pixelSize: Fonts.scale(9)
            font.family: Fonts.poppins.name
            color: Theme.muted
        }
    }
}
