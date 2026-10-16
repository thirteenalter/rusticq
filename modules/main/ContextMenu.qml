import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../../config"

// A useful RusticQ settings/view/share menu, inspired by the familiar
// macOS menu bar. No claims of controlling another application's Edit menu.
Item {
    id: root
    property string section: "view"
    property string currentSection: section
    onSectionChanged: currentSection = section
    signal actionFinished()
    anchors.fill: parent
    readonly property var sections: [
        {key: "file", title: "File", enabled: SettingsStore.showMenuFile},
        {key: "edit", title: "Edit", enabled: SettingsStore.showMenuEdit},
        {key: "view", title: "View", enabled: SettingsStore.showMenuView},
        {key: "share", title: "Share", enabled: SettingsStore.showMenuShare},
        {key: "shell", title: "Shell", enabled: SettingsStore.showMenuShell},
        {key: "tools", title: "Tools", enabled: SettingsStore.showMenuTools}
    ].filter(item => item.enabled)
    readonly property var entries: currentSection === "file" ? [
        {title: "Home folder", desc: "Open your home directory", icon: "\ue2c7", action: "file-home"},
        {title: "Downloads", desc: "Browse downloads", icon: "\ue2c4", action: "file-downloads"},
        {title: "RusticQ config", desc: "Open current shell directory", icon: "\ue8b8", action: "file-config"}
    ] : currentSection === "shell" ? [
        {title: "Open terminal", desc: "Use an installed terminal emulator", icon: "\ueb8e", action: "shell-terminal"},
        {title: "System monitor", desc: "Launch btop or htop in a terminal", icon: "\uef43", action: "shell-monitor"}
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
        { title: "Open screenshots", desc: "View saved captures", icon: "\ue2c7", action: "folder" }
    ] : [
        {title: "Compact", desc: "Tight controls", icon: "\ue5d1", action: "compact"},
        {title: "Clean Compact", desc: "Minimal buttons", icon: "\ue5d1", action: "clean-compact"},
        {title: "Separated", desc: "Floating islands", icon: "\ue86c", action: "separated"},
        {title: "Professional", desc: "Solid desktop bar", icon: "\ue30b", action: "professional"},
        {title: "Simple", desc: "Essential actions only", icon: "\ue5d4", action: "simple"}
    ]
    function runAction(action) {
        if (currentSection === "view") {
            SettingsStore.barMode = action;
            SettingsStore.save();
        } else if (currentSection === "edit") {
            Store.showSettings(action);
        } else if (currentSection === "file" || currentSection === "shell" || currentSection === "tools") {
            if (action === "tools-settings") Store.showSettings("bar");
            else if (action === "tools-region") Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/rustiq-capture.sh"), "region"]);
            else Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/rustiq-menu-action.sh"), action]);
        } else {
            // Only trusted constant action names are passed to the helper.
            // The helper checks grim/slurp and never uploads screenshots.
            Quickshell.execDetached(["sh", Qt.resolvedUrl("../../scripts/rustiq-capture.sh").toString().replace("file://", ""), action]);
        }
        root.actionFinished();
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text { text: "RusticQ / " + root.currentSection.charAt(0).toUpperCase() + root.currentSection.slice(1); font.family: Fonts.poppinsSB.name; font.pixelSize: 13; color: Theme.foreground; Layout.fillWidth: true }
            Icon { icon: "\ue5d2"; color: Theme.accent; font.pixelSize: 18 }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: root.sections
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 29
                    radius: 8
                    color: root.currentSection === modelData.key ? Qt.alpha(Theme.accent, .21) : Theme.surface
                    Text {
                        anchors.centerIn: parent
                        text: tab.modelData.title
                        font.family: Fonts.poppins.name
                        font.pixelSize: 11
                        color: root.currentSection === tab.modelData.key ? Theme.accent : Theme.foreground
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentSection = tab.modelData.key }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: entryColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: entryColumn
                width: parent.width
                spacing: 5
                Repeater {
                    model: root.entries
                    delegate: Rectangle {
                        id: choice
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 49
                        color: choiceMouse.containsMouse ? Qt.alpha(Theme.accent, .16) : Theme.surface
                        radius: 9
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11; anchors.rightMargin: 10
                            spacing: 9
                            Icon { icon: choice.modelData.icon; color: Theme.accent; font.pixelSize: 18 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text { text: choice.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
                                Text { text: choice.modelData.desc; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 9 }
                            }
                            Icon { visible: root.currentSection === "view" && SettingsStore.barMode === choice.modelData.action; icon: "\ue5ca"; color: Theme.accent }
                        }
                        MouseArea {
                            id: choiceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runAction(choice.modelData.action)
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.currentSection === "share" ? "Captures stay on this computer · grim / slurp" : "RusticQ shortcuts · not an application global menu"
            wrapMode: Text.WordWrap
            font.pixelSize: 9
            font.family: Fonts.poppins.name
            color: Theme.muted
        }
    }
}
