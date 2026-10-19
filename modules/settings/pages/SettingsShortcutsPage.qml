import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    id: root
    width: parent ? parent.width : 680
    spacing: 13
    property var entries: []
    property var managed: ({})
    property var availableActions: []
    property string actionFilter: ""
    property string selectedBarKey: "rusticq"
    readonly property var barGroups: [
        {key: "rusticq", name: "RusticQ"}, {key: "arch", name: "AI"},
        {key: "launcher", name: "Launcher"}, {key: "menu", name: "Menus"},
        {key: "workspaces", name: "Workspaces"}, {key: "weather", name: "Weather"},
        {key: "time", name: "Clock"}, {key: "date", name: "Calendar"},
        {key: "bluetooth", name: "Bluetooth"}, {key: "wifi", name: "Network"},
        {key: "battery", name: "Battery"}, {key: "audio", name: "Audio"},
        {key: "task", name: "Task"}, {key: "quickModes", name: "Quick Modes"},
        {key: "quickControl", name: "Quick Control"}, {key: "mic", name: "Microphone"}
    ]
    readonly property var barActions: availableActions.filter(a => a.bar_keys && a.bar_keys.indexOf(selectedBarKey) >= 0)
    readonly property var matchingActions: availableActions.filter(a => (a.name + " " + a.key + " " + a.category).toLowerCase().includes(actionFilter.toLowerCase()))
    readonly property var selectedAction: availableActions.find(a => a.key === action)
    property var remaps: ({})
    property var selectedSource: null
    property string editKey: ""
    property string selectedRemapId: ""
    property string filterText: ""
    property string combo: "SUPER + SHIFT + R"
    property string pendingVerb: ""
    property string pendingSelectedAction: ""
    property string commandVerb: ""
    property var pendingCommand: []
    readonly property bool recoveryCombo: combo.replace(/\s/g, "").toUpperCase() === "SUPER+ESCAPE" || combo.replace(/\s/g, "").toUpperCase() === "SUPER+BACKSPACE"
    property string action: "settings"
    property string feedback: ""
    property bool successful: true
    property bool busy: false
    property var shortcutArchives: ({count:0, latest:"", defaults_present:false, directory:""})
    property string lastBackupDir: ""
    readonly property string helper: Quickshell.shellPath("scripts/rustiq-desktop-integration.py")
    readonly property var visibleEntries: entries.filter(e => (e.key + " " + e.label + " " + e.origin).toLowerCase().includes(filterText.toLowerCase()))
    Component.onCompleted: { refresh(); actionProc.exec(["python3", helper, "actions"]); }
    function refresh() { if (!listProc.running) listProc.exec(["python3", helper, "bindings"]); if (!statusProc.running) statusProc.exec(["python3", helper, "status"]); }
    function change(verb, selectedAction) {
        if (busy || commandProc.running) return;
        if (["shortcut", "shortcut-revert", "remap", "remap-revert"].indexOf(verb) >= 0) {
            pendingVerb = verb;
            pendingSelectedAction = selectedAction || "";
            const description = verb === "shortcut" ? "Apply shortcut override" :
                verb === "shortcut-revert" ? "Restore selected shortcut" :
                verb === "remap" ? "Change existing Omarchy binding" : "Restore existing Omarchy binding";
            const target = verb === "shortcut" ? combo + " → " + action :
                verb === "shortcut-revert" ? (selectedAction || action) :
                verb === "remap" ? (selectedSource ? selectedSource.key + " → " + editKey : editKey) :
                (selectedAction || selectedRemapId);
            const frozen = buildCommand(verb, selectedAction);
            if (!frozen.length) { successful = false; feedback = "Select a valid binding first."; return; }
            pendingCommand = frozen;
            Store.requestShortcutConfirmation(description, target,
                verb === "shortcut" && recoveryCombo);
            return;
        }
        executeCommand(verb, selectedAction);
    }
    function buildCommand(verb, selectedAction) {
        const cmd = ["python3", helper, verb];
        if (verb === "shortcut") cmd.push("--key", combo, "--action", action);
        if (verb === "shortcut-revert") cmd.push("--action", selectedAction || action);
        if (verb === "remap") {
            if (!selectedSource || !selectedSource.source_hash) return [];
            cmd.push("--file", selectedSource.file, "--line", String(selectedSource.line), "--hash", selectedSource.source_hash, "--key", editKey);
        }
        if (verb === "remap-revert") {
            if (!(selectedAction || selectedRemapId)) return [];
            cmd.push("--id", selectedAction || selectedRemapId);
        }
        return cmd;
    }
    function executeCommand(verb, selectedAction, prepared) {
        if (busy || commandProc.running) return;
        const cmd = prepared || buildCommand(verb, selectedAction);
        if (!cmd.length) return;
        busy = true;
        commandVerb = verb;
        feedback = "";
        commandProc.exec(cmd);
    }
    Connections {
        target: Store
        function onShortcutBackupApproved() {
            if (!root.pendingVerb || root.busy) return;
            const verb = root.pendingVerb;
            const target = root.pendingSelectedAction;
            const cmd = root.pendingCommand;
            root.pendingVerb = "";
            root.pendingSelectedAction = "";
            root.pendingCommand = [];
            root.executeCommand(verb, target, cmd);
        }
    }
    Process {
        id: actionProc
        stdout: StdioCollector { onStreamFinished: {
            try { const data = JSON.parse(text); if (data.ok) root.availableActions = data.actions || []; else root.feedback = data.message; }
            catch (e) { root.feedback = "Unable to load action registry: " + e; }
        } }
    }
    Process {
        id: listProc
        stdout: StdioCollector { onStreamFinished: {
            try { const data = JSON.parse(text); if (data.ok) root.entries = data.bindings || []; else root.feedback = data.message; }
            catch (e) { root.feedback = "Failed reading bindings: " + e; }
        } }
    }
    Process {
        id: statusProc
        stdout: StdioCollector { onStreamFinished: {
            try { const data = JSON.parse(text); if (data.ok) { root.managed = data.shortcuts || {}; root.remaps = data.remaps || {}; root.shortcutArchives = data.shortcut_archives || root.shortcutArchives; } }
            catch (e) { root.feedback = String(e); }
        } }
    }
    Process {
        id: commandProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const data = JSON.parse(text);
                root.successful = !!data.ok;
                if (data.backup_dir) root.lastBackupDir = data.backup_dir;
                if (data.ok && data.count !== undefined && data.directory) {
                    root.feedback = data.message || ("Verified " + data.count + " user snapshots and " + (data.default_files || 0) + " Omarchy files.");
                } else if (data.ok && data.backup_verified) {
                    root.feedback = "Backup VERIFIED (" + data.backup_files + " dotfiles, " + data.default_backup_files + " default files). " + (data.message || "Operation completed.") + " Saved: " + data.backup_dir;
                } else root.feedback = data.message || (data.ok ? "Operation completed." : "Operation failed. See command output.");
            }
            catch (e) { root.successful = false; root.feedback = String(e); }
        } }
        stderr: StdioCollector { onStreamFinished: {
            if (this.text.trim().length && !root.feedback.length) { root.successful = false; root.feedback = this.text.trim().slice(-450); }
        } }
        onExited: (code, status) => {
            if (code !== 0 && !root.feedback.length) { root.successful = false; root.feedback = "Backup or shortcut command exited with code " + code; }
            root.busy = false; Qt.callLater(root.refresh);
        }
    }
    SettingsSection {
        heading: "Top bar button shortcuts"
        description: "Every interactive top-bar button is mapped to its real action. Select the button, choose an action, then assign a key below. This works across Left / Center / Right bar layouts."
        symbol: "\ue312"
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 6; columnSpacing: 6
            Repeater {
                model: root.barGroups
                delegate: Rectangle {
                    id: barGroup
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 9
                    color: root.selectedBarKey === modelData.key ? Qt.alpha(Theme.accent, 0.18) : Theme.background
                    border.color: Theme.accent
                    border.width: root.selectedBarKey === modelData.key ? 1 : 0
                    Text {
                        anchors.centerIn: parent
                        text: barGroup.modelData.name
                        color: root.selectedBarKey === barGroup.modelData.key ? Theme.accent : Theme.foreground
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: Fonts.scale(10)
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedBarKey = barGroup.modelData.key;
                            if (root.barActions.length) root.action = root.barActions[0].key;
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Choose the exact action for " + (root.barGroups.find(g => g.key === root.selectedBarKey) || {name:""}).name + ":"
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2; rowSpacing: 6; columnSpacing: 6
            Repeater {
                model: root.barActions
                delegate: Rectangle {
                    id: barAction
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 9
                    color: root.action === modelData.key ? Qt.alpha(Theme.accent, 0.18) : Theme.background
                    border.width: root.action === modelData.key ? 1 : 0
                    border.color: Theme.accent
                    Text {
                        anchors.centerIn: parent; width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: barAction.modelData.name + (root.managed[barAction.modelData.key] ? " · " + root.managed[barAction.modelData.key] : "")
                        color: root.action === barAction.modelData.key ? Theme.accent : Theme.foreground
                        font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.action = barAction.modelData.key
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Download / upload speed are read-only status indicators, not clickable buttons. For system activity use System Monitor."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
    }
    SettingsSection {
        heading: "Keyboard shortcuts"
        description: "Assign any action from the top bar, menus, Settings, Quick Modes, workspaces or dock. Original Omarchy lines remain intact."
        symbol: "\ue312"
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Choose a RusticQ action and a key, then apply. Existing shortcuts on that key are temporarily masked; original source lines remain untouched."; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 43; radius: 10; color: Theme.background
            TextInput { anchors.fill: parent; anchors.margins: 11; verticalAlignment: TextInput.AlignVCenter; text: root.combo; color: Theme.foreground; selectByMouse: true; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); onTextEdited: root.combo = text }
        }
        Text { visible: root.recoveryCombo; Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Recovery shortcut: the confirmation dialog will require explicit acknowledgment before backup + apply."
            color: Theme.warning; font.pixelSize: Fonts.scale(10) }
        Text { text: "Action · " + (root.selectedAction ? root.selectedAction.name + " / " + root.selectedAction.category : root.action); color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 41; radius: 9; color: Theme.background
            TextInput {
                anchors.fill: parent; anchors.margins: 10
                verticalAlignment: TextInput.AlignVCenter; color: Theme.foreground
                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                onTextEdited: root.actionFilter = text
                Text { anchors.verticalCenter: parent.verticalCenter; visible: parent.text.length === 0; text: "Find Settings pages, bar icons, menus, quick modes, workspaces..."; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
            }
        }
        GridLayout {
            Layout.fillWidth: true; columns: 2; rowSpacing: 7; columnSpacing: 7
            Repeater { model: root.matchingActions.slice(0, 80); delegate: Rectangle {
                id: actionItem
                required property var modelData
                Layout.fillWidth: true; Layout.preferredHeight: 46; radius: 9
                color: root.action === modelData.key ? Qt.alpha(Theme.accent, .16) : Theme.background
                border.width: root.action === modelData.key ? 1 : 0; border.color: Theme.accent
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 1
                    Text { text: actionItem.modelData.name; Layout.alignment: Qt.AlignHCenter; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                    Text { text: actionItem.modelData.category; Layout.alignment: Qt.AlignHCenter; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.action = actionItem.modelData.key }
            } }
        }
        Text { Layout.fillWidth: true; visible: root.matchingActions.length > 80; text: "Showing 80 of " + root.matchingActions.length + " actions. Search to find the rest."; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 39; radius: 9; color: Theme.accent
                Text { anchors.centerIn: parent; text: "Apply override"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.change("shortcut") }
            }
            Rectangle { Layout.preferredWidth: 151; Layout.preferredHeight: 39; radius: 9; color: Theme.background
                Text { anchors.centerIn: parent; text: "Restore selected"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.change("shortcut-revert", root.action) }
            }
        }
        Text { Layout.fillWidth: true; visible: root.feedback.length > 0; text: root.feedback; wrapMode: Text.WordWrap; color: root.successful ? Theme.accent : Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: backupInformation.implicitHeight + 24
            color: Theme.background; radius: 11
            border.width: 1
            border.color: root.shortcutArchives.defaults_present && root.shortcutArchives.count > 0 ? Theme.borderaccent : Theme.warning
            ColumnLayout {
                id: backupInformation
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12
                spacing: 9
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Icon { icon: "\ue8b8"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                    Text { Layout.fillWidth: true; text: "Automatic Omarchy & dotfiles backup"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: root.shortcutArchives.count === 0 ?
                        "NO BACKUP YET — create the first verified backup now or choose Apply override and confirm. No change is allowed without a valid snapshot." :
                        root.shortcutArchives.count + " user snapshots · Full default Omarchy: " + (root.shortcutArchives.defaults_present ? "present" : "NOT SAVED") + ". Every Apply / Restore takes a new dotfiles snapshot."
                    color: root.shortcutArchives.count === 0 ? Theme.warning : Theme.muted
                    font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 9; color: Theme.accent
                        Text { anchors.centerIn: parent; text: root.busy && root.commandVerb === "create-shortcut-backup" ? "Creating…" : "Create backup now"; color: Theme.background; font.pixelSize: Fonts.scale(10) }
                        MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor
                            onClicked: root.change("create-shortcut-backup") }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 9; color: Theme.surface
                        Text { anchors.centerIn: parent; text: root.busy && root.commandVerb === "verify-shortcut-backups" ? "Verifying…" : "Verify backup"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
                        MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor
                            onClicked: root.change("verify-shortcut-backups") }
                    }
                }
                Text { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
                    text: "Backup directory: " + (root.shortcutArchives.directory || "~/.local/state/rusticq/integration/backup/shortcut-history")
                    color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9) }
                Text { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
                    visible: !!root.lastBackupDir || !!root.shortcutArchives.latest
                    text: "Latest snapshot: " + (root.lastBackupDir || root.shortcutArchives.latest)
                    color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9) }
            }
        }
    }
    SettingsSection {
        heading: "Edit an existing shortcut"
        description: "Select an Omarchy/user shortcut below, then choose its replacement key. Only static, one-line o.bind definitions can be changed automatically."
        symbol: "\ue3c9"
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: root.selectedRemapId ? "Managed remap selected. Restore it individually to reveal the original key." :
                root.selectedSource ? (root.selectedSource.label + "  ·  " + root.selectedSource.key + "  ·  " + root.selectedSource.origin + ":" + root.selectedSource.line) :
                "Click a row in Detected bindings to select the source line."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 43; radius: 10; color: Theme.background
            TextInput {
                anchors.fill: parent; anchors.margins: 11
                text: root.editKey; selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12)
                onTextEdited: root.editKey = text
                Text { visible: parent.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "New combination (e.g. SUPER + SHIFT + G)"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Rectangle {
                id: remapApply; Layout.fillWidth: true; Layout.preferredHeight: 39; radius: 9
                readonly property bool available: !root.busy && root.selectedSource !== null && !!root.selectedSource.source_hash && !root.selectedRemapId
                color: available ? Theme.accent : Theme.borderaccent
                Text { anchors.centerIn: parent; text: "Apply new key"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; enabled: remapApply.available; cursorShape: Qt.PointingHandCursor; onClicked: root.change("remap") }
            }
            Rectangle {
                id: remapRestore; Layout.preferredWidth: 152; Layout.preferredHeight: 39; radius: 9; color: Theme.background
                Text { anchors.centerIn: parent; text: "Revert selected"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; enabled: !root.busy && root.selectedRemapId.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: root.change("remap-revert") }
            }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Source file and line are fingerprinted and backed up. Revert removes only this override, not other changes. Complex/dynamic Lua bindings stay read-only."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
    }
    SettingsSection {
        heading: "Detected bindings (" + root.visibleEntries.length + ")"
        description: "Select a key to override. Entries show source and line; original Lua lines are saved for audit and remain untouched."
        symbol: "\ue8b6"
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 39; radius: 9; color: Theme.background
            TextInput { anchors.fill: parent; anchors.margins: 10; verticalAlignment: TextInput.AlignVCenter; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); onTextEdited: root.filterText = text
                Text { anchors.verticalCenter: parent.verticalCenter; visible: parent.text.length === 0; text: "Search key, action, or source..."; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
            }
        }
        Repeater {
            model: root.visibleEntries.slice(0, 100)
            delegate: Rectangle {
                id: bindingItem
                required property var modelData
                Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 9; color: Theme.background
                RowLayout { anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 11; spacing: 9
                    Text { text: bindingItem.modelData.key; Layout.preferredWidth: 155; elide: Text.ElideRight; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                    ColumnLayout { Layout.fillWidth: true; spacing: 1
                        Text { text: bindingItem.modelData.label; Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
                        Text { text: bindingItem.modelData.origin + (bindingItem.modelData.line ? " · line " + bindingItem.modelData.line : "") + (bindingItem.modelData.original_key ? " · original " + bindingItem.modelData.original_key : ""); color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9) }
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                    root.combo = bindingItem.modelData.key;
                    if (bindingItem.modelData.action) root.action = bindingItem.modelData.action;
                    root.selectedRemapId = bindingItem.modelData.remap_id || "";
                    root.selectedSource = (bindingItem.modelData.origin === "user" || bindingItem.modelData.origin === "omarchy") ? bindingItem.modelData : null;
                    root.editKey = root.selectedRemapId ? bindingItem.modelData.key : root.selectedSource ? root.selectedSource.key : "";
                } }
            }
        }
        Text { Layout.fillWidth: true; text: "Reverting a single override reveals that original Lua binding again. Omarchy default files are never overwritten."; wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        Text { Layout.fillWidth: true; visible: root.visibleEntries.length > 100; text: "Showing first 100 entries. Narrow the search to find other shortcuts."; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        Text { Layout.fillWidth: true; visible: root.visibleEntries.length === 0; text: "No matching bindings found."; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
    }
}
