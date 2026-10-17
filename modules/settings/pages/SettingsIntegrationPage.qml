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
    spacing: 14
    property var info: ({permanent:false, shortcut_managed:false, compatibility:{}})
    property string message: ""
    property bool lastOk: true
    property bool backupAttempted: false
    property bool backupBusy: false
    property string typedConfirmation: ""
    property bool busy: false
    property string pendingAction: ""
    readonly property string helper: Quickshell.shellPath("scripts/rustiq-desktop-integration.py")
    readonly property string dependencyHelper: Quickshell.shellPath("scripts/rusticq-dependencies.py")
    property var dependencyInfo: ({ok:false, items:[], missing_core:0, missing_optional:0})
    property string dependencyFilter: ""
    property string selectedDependency: ""
    property string dependencyConfirmation: ""
    property string dependencyMessage: ""
    property bool dependencyBusy: false
    property bool dependencyLastOk: true

    Component.onCompleted: { refresh(); refreshDependencies(); }
    function refreshDependencies() {
        if (!dependencyStatusProc.running)
            dependencyStatusProc.exec(["python3", dependencyHelper, "status"]);
    }
    function requestDependencyInstall() {
        if (dependencyBusy || dependencyActionProc.running || selectedDependency.length === 0
            || dependencyConfirmation !== "INSTALL") return;
        dependencyBusy = true;
        dependencyActionProc.exec(["python3", dependencyHelper, "launch", selectedDependency,
                                   "--confirm", "INSTALL " + selectedDependency]);
    }
    function refresh() {
        if (!statusProc.running) statusProc.exec(["python3", helper, "status"]);
    }
    function invoke(verb, args) {
        if (busy || actionProc.running) return;
        busy = true;
        pendingAction = verb;
        const cmd = ["python3", helper, verb];
        for (let i = 0; i < args.length; i++) cmd.push(args[i]);
        actionProc.exec(cmd);
    }
    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    if (parsed.ok) {
                        root.info = parsed;
                        if (parsed.compatibility && parsed.compatibility.omarchy_detected && !parsed.permanent && !parsed.omarchy_backup_ready && !root.backupAttempted) {
                            root.backupAttempted = true;
                            root.backupBusy = true;
                            backupProc.exec(["python3", root.helper, "backup-omarchy"]);
                        }
                    }
                } catch (e) { root.message = "Unable to inspect Hyprland configuration: " + e; }
            }
        }
    }
    Process {
        id: backupProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(text);
                root.lastOk = result.ok === true;
                root.message = result.message || "Omarchy backup returned no message";
            } catch (e) {
                root.lastOk = false;
                root.message = "Automatic Omarchy backup failed: " + String(e);
            }
        } }
        onExited: (code, status) => {
            root.backupBusy = false;
            Qt.callLater(root.refresh);
        }
    }
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text);
                    root.lastOk = result.ok === true;
                    root.message = result.message || "No status was returned";
                } catch (e) {
                    root.lastOk = false;
                    root.message = "Unable to parse integration result: " + String(e);
                }
            }
        }
        onExited: (code, status) => {
            root.busy = false;
            root.typedConfirmation = "";
            Qt.callLater(root.refresh);
        }
    }

    // Dependency changes are separate from permanent Omarchy replacement.
    // Merely opening Settings runs pacman -Q (read-only), never an installer.
    Process {
        id: dependencyStatusProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text);
                if (result.ok === true) root.dependencyInfo = result;
                else {
                    root.dependencyLastOk = false;
                    root.dependencyMessage = result.message || "Dependency scan failed";
                }
            } catch (e) {
                root.dependencyLastOk = false;
                root.dependencyMessage = "Dependency scan failed: " + String(e);
            }
        } }
    }
    Process {
        id: dependencyActionProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text);
                root.dependencyLastOk = result.ok === true;
                root.dependencyMessage = result.message || "No dependency install status returned";
            } catch (e) {
                root.dependencyLastOk = false;
                root.dependencyMessage = "Cannot open dependency installer: " + String(e);
            }
        } }
        onExited: (code, status) => { root.dependencyBusy = false; Qt.callLater(root.refreshDependencies); }
    }

    SettingsSection {
        heading: "Required & optional dependencies"
        description: "Core packages are installed by the local setup script. Install extra tools individually from a confirmed terminal. Opening this page never installs packages."
        symbol: "\ue869"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.dependencyInfo.ok === true
                    ? ("Core missing: " + root.dependencyInfo.missing_core + "  ·  Optional missing: " + root.dependencyInfo.missing_optional)
                    : "Checking installed packages..."
                color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
            }
            Rectangle {
                Layout.preferredWidth: 80; Layout.preferredHeight: 32; radius: 9
                color: Theme.background
                Text { anchors.centerIn: parent; text: "Refresh"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshDependencies() }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10
            color: Theme.background
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8
                Icon { icon: "\ue8b6"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                TextInput {
                    Layout.fillWidth: true
                    color: Theme.foreground
                    font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                    text: root.dependencyFilter
                    onTextEdited: root.dependencyFilter = text
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.text.length === 0
                        text: "Filter packages or features..."
                        color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                    }
                }
            }
        }
        Repeater {
            model: (root.dependencyInfo.items || []).filter(function(item) {
                const q = root.dependencyFilter.toLowerCase().trim();
                return q.length === 0 || (item.name + " " + item.id + " " + item.package + " " + item.description).toLowerCase().indexOf(q) >= 0;
            })
            delegate: Rectangle {
                id: dependencyRow
                required property var modelData
                readonly property bool installed: modelData.installed === true
                readonly property bool selected: root.selectedDependency === modelData.id
                readonly property string searchable: (modelData.name + " " + modelData.id + " " + modelData.description + " " + modelData.package).toLowerCase()
                visible: root.dependencyFilter.trim().length === 0 || searchable.indexOf(root.dependencyFilter.toLowerCase().trim()) >= 0
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 64 : 0
                radius: 11
                color: selected ? Qt.alpha(Theme.accent, 0.13) : Theme.background
                border.width: selected ? 1 : 0
                border.color: Theme.accent
                RowLayout {
                    anchors.fill: parent; anchors.margins: 9; spacing: 10
                    Icon { icon: dependencyRow.installed ? "\ue5ca" : "\ue8b8"; color: dependencyRow.installed ? Theme.success : Theme.accent; font.pixelSize: Fonts.scale(18) }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text {
                            text: dependencyRow.modelData.name + "  ·  " + dependencyRow.modelData.package
                            color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11)
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: (dependencyRow.modelData.group === "core" ? "CORE · " : "OPTIONAL · ") + dependencyRow.modelData.description
                            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                    Text {
                        text: dependencyRow.installed ? "Installed" : (dependencyRow.selected ? "Selected" : "Install")
                        color: dependencyRow.installed ? Theme.success : Theme.accent
                        font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !dependencyRow.installed && !root.dependencyBusy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.selectedDependency = dependencyRow.modelData.id;
                        root.dependencyConfirmation = "";
                    }
                }
            }
        }
        Text {
            visible: root.selectedDependency.length > 0
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Selected: " + root.selectedDependency + ". Type INSTALL below, then review and approve the exact command in the terminal. Omarchy uses its own update flow first."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        Rectangle {
            visible: root.selectedDependency.length > 0
            Layout.fillWidth: true; Layout.preferredHeight: visible ? 39 : 0
            radius: 10; color: Theme.background
            TextInput {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: root.dependencyConfirmation
                onTextEdited: root.dependencyConfirmation = text
                color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                selectByMouse: true
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.text.length === 0
                    text: "Type INSTALL to authorize opening terminal"
                    color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                }
            }
        }
        Rectangle {
            id: dependencyCommit
            visible: root.selectedDependency.length > 0
            Layout.fillWidth: true; Layout.preferredHeight: visible ? 39 : 0
            radius: 11
            readonly property bool canInstall: root.selectedDependency.length > 0 && root.dependencyConfirmation === "INSTALL" && !root.dependencyBusy
            color: canInstall ? Theme.accent : Theme.borderaccent
            Text {
                anchors.centerIn: parent
                text: root.dependencyBusy ? "Opening terminal..." : "Open interactive installer"
                color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11)
            }
            MouseArea {
                anchors.fill: parent; enabled: dependencyCommit.canInstall
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.requestDependencyInstall()
            }
        }
        Text {
            visible: root.dependencyMessage.length > 0
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: root.dependencyMessage
            color: root.dependencyLastOk ? Theme.success : Theme.foreground
            font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "System services (NetworkManager, BlueZ, PipeWire) are not enabled automatically. Quickshell must already run inside a Hyprland session. See docs/DEPENDENCIES.md."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
    }

    SettingsSection {
        heading: "Make RusticQ permanent"
        description: "Only for detected Omarchy Quattro devices. Automatically back up startup and configuration before permanent replacement; restore later."
        symbol: "\ue8b8"
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: warningCol.implicitHeight + 25
            color: Qt.alpha(Theme.accent, 0.09)
            radius: 11
            ColumnLayout {
                id: warningCol
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12
                spacing: 7
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Icon { icon: "\ue002"; color: Theme.accent; font.pixelSize: Fonts.scale(19) }
                    Text { text: "Read before replacing Omarchy Shell"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); Layout.fillWidth: true }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "This disables the built-in Omarchy Shell after your next login, including Omarchy's bar, overlays and shell-dependent menus/services. RusticQ may not fully replace Omarchy's lock, polkit, or screen sharing components. You retain a backup and an offline revert command."
                    color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "On detection, a backup of Omarchy default Hyprland Lua and your current Hyprland config is created automatically. /usr/share/omarchy is never edited; no Omarchy package is removed."
                    color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.info.permanent ? "Installed for next login" : "Not installed permanently"
            color: root.info.permanent ? Theme.accent : Theme.muted
            font.family: Fonts.poppinsSB.name
            font.pixelSize: Fonts.scale(12)
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: root.info.compatibility && root.info.compatibility.omarchy_detected && root.info.compatibility.launcher_intercept_supported ?
                "Omarchy Quattro detected · " + (root.info.omarchy_backup_ready ? "automatic backup ready" : (root.backupBusy ? "creating backup now..." : "backup pending")) :
                "Omarchy Quattro startup has not been verified. No automatic backup or permanent install will run."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
            text: "Backups: " + (root.info.backup_dir || "~/.local/state/rusticq/integration/backup")
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
            text: "Recovery from a TTY: python3 ~/.local/share/rusticq/shell/scripts/rustiq-desktop-integration.py revert --confirm 'RESTORE OMARCHY'"
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 43
            radius: 11; color: Theme.background
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                Icon { icon: "\ue873"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                TextInput {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.typedConfirmation
                    color: Theme.foreground
                    font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                    selectByMouse: true
                    onTextEdited: root.typedConfirmation = text
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.text.length === 0
                        text: root.info.permanent ? "Type RESTORE OMARCHY" : "Type ENABLE RUSTICQ"
                        color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 9
            Rectangle {
                id: commitButton
                Layout.fillWidth: true; Layout.preferredHeight: 41
                // Always evaluate to a boolean, even while the status response lacks compatibility fields.
                readonly property bool canRun: !root.busy
                    && !root.backupBusy
                    && (root.info.permanent === true
                        || (root.info.compatibility !== undefined
                            && root.info.compatibility !== null
                            && root.info.compatibility.omarchy_detected === true
                            && root.info.compatibility.launcher_intercept_supported === true
                            && root.info.omarchy_backup_ready === true))
                    && root.typedConfirmation === (root.info.permanent === true ? "RESTORE OMARCHY" : "ENABLE RUSTICQ")
                color: canRun ? Theme.accent : Theme.borderaccent
                radius: 11
                RowLayout { anchors.centerIn: parent; spacing: 7
                    Icon { icon: root.info.permanent ? "\ue863" : "\ue8b8"; font.pixelSize: Fonts.scale(17); color: Theme.background }
                    Text { text: root.info.permanent ? "Restore Omarchy shell" : "Install RusticQ for next login"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: commitButton.canRun ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.canRun
                    onClicked: root.invoke(root.info.permanent ? "revert" : "enable", ["--confirm", root.typedConfirmation])
                }
            }
            Rectangle {
                Layout.preferredWidth: 77; Layout.preferredHeight: 41
                radius: 11; color: Theme.background
                Text { anchors.centerIn: parent; text: "Refresh"; color: Theme.foreground; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppins.name }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
        }
    }
    Rectangle {
        visible: root.message.length > 0
        Layout.fillWidth: true; Layout.preferredHeight: Math.max(49, actionMessage.implicitHeight + 24)
        radius: 11; color: root.lastOk ? Qt.alpha(Theme.accent, .12) : Qt.alpha(Theme.foreground, .08)
        Text {
            id: actionMessage
            width: parent.width - 24
            x: 12; y: 12
            text: root.message
            wrapMode: Text.WordWrap
            color: Theme.foreground
            font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
    }
}
