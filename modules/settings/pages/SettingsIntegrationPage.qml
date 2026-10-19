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
    property string backupIntegrity: "Not verified yet"
    property string typedConfirmation: ""
    property bool busy: false
    property string pendingAction: ""
    property var integrationInfo: ({state:"not_installed", percent:0, phase:"Checking installed integration", changes:[]})
    property bool showFileReport: true
    readonly property string shellUpdateHelper: Quickshell.shellPath("scripts/rusticq-shell-updates.py")
    property var shellUpdateStatus: ({installed:false, installed_tag:"", state:"idle", progress:0, phase:"", release:{}, changed:[], backups:0})
    property string shellUpdateMessage: ""
    property bool shellUpdateOk: true
    property bool shellUpdateBusy: false
    property string shellUpdateAction: ""
    property string shellUpdateConfirm: ""
    property string shellReleaseTag: ""
    property bool shellUpdateCheckBusy: false
    property bool shellUpdateCheckedOnce: false
    property string shellUpdateTarget: "dev"
    readonly property bool shellUpdateTargetReady: shellUpdateTarget === "dev" ? !!shellUpdateStatus.dev_ready : !!shellUpdateStatus.installed
    readonly property int shellUpdateTargetBackups: shellUpdateTarget === "dev" ? (shellUpdateStatus.backups_dev || 0) : (shellUpdateStatus.backups_installed || 0)
    Timer {
        id: githubPeriodicCheck
        interval: 3600000
        repeat: true
        running: root.visible
        onTriggered: root.shellUpdateCheck()
    }
    function shellUpdateRefresh() {
        if (!shellUpdateStatusProc.running) shellUpdateStatusProc.exec(["python3", shellUpdateHelper, "status"]);
    }
    function shellUpdateCheck() {
        if (shellUpdateBusy || shellUpdateCheckBusy || shellUpdateCheckProc.running) return;
        shellUpdateCheckBusy = true;
        shellUpdateMessage = "Checking GitHub Releases…";
        const cmd = ["python3", shellUpdateHelper, "check"];
        if (shellReleaseTag.trim().length > 0) cmd.push("--tag", shellReleaseTag.trim());
        shellUpdateCheckProc.exec(cmd);
    }
    function shellUpdateApply() {
        if (shellUpdateBusy || shellUpdateAction.length === 0 || shellUpdateActionProc.running) return;
        const phrase = shellUpdateAction === "reapply-local" ? "REAPPLY LOCAL" :
                       shellUpdateAction === "rollback" ? "ROLLBACK SHELL" : "UPDATE SHELL";
        if (shellUpdateConfirm !== phrase) return;
        shellUpdateBusy = true;
        shellUpdateMessage = "Preparing a verified shell update…";
        const cmd = ["python3", shellUpdateHelper, shellUpdateAction, "--confirm", phrase, "--target", shellUpdateTarget];
        if (shellUpdateAction === "update-shell" && shellReleaseTag.trim().length > 0)
            cmd.push("--tag", shellReleaseTag.trim());
        shellUpdateActionProc.exec(cmd);
    }
    Timer {
        id: shellUpdatePoll
        interval: 800
        repeat: true
        running: root.shellUpdateBusy
        onTriggered: root.shellUpdateRefresh()
    }
    Process {
        id: shellUpdateStatusProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text);
                if (result.ok === true) {
                    root.shellUpdateStatus = result;
                    if (!root.shellUpdateCheckedOnce && !root.shellUpdateBusy && !root.shellUpdateCheckBusy) {
                        root.shellUpdateCheckedOnce = true;
                        Qt.callLater(root.shellUpdateCheck);
                    }
                }
            } catch (e) { root.shellUpdateMessage = "Update status unreadable: " + e; }
        } }
    }
    Process {
        id: shellUpdateCheckProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text);
                root.shellUpdateOk = result.ok === true;
                root.shellUpdateMessage = result.message || "No GitHub Release result";
                if (result.release) root.shellUpdateStatus = Object.assign({}, root.shellUpdateStatus, {release:result.release, checked_tag:result.release.tag, update_available:result.update_available});
            } catch (e) { root.shellUpdateOk = false; root.shellUpdateMessage = "GitHub response error: " + e; }
        } }
        onExited: (code, status) => { root.shellUpdateCheckBusy = false; root.shellUpdateRefresh(); }
    }
    Process {
        id: shellUpdateActionProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text);
                root.shellUpdateOk = result.ok === true;
                root.shellUpdateMessage = result.message || "Shell updater did not return a message";
            } catch (e) { root.shellUpdateOk = false; root.shellUpdateMessage = "Shell update returned unreadable output: " + e; }
        } }
        onExited: (code, status) => {
            root.shellUpdateBusy = false;
            root.shellUpdateConfirm = "";
            root.shellUpdateAction = "";
            root.shellUpdateRefresh();
            Qt.callLater(root.refreshIntegrationProgress);
        }
    }
    function refreshIntegrationProgress() {
        if (!progressProc.running) progressProc.exec(["python3", helper, "integration-progress"]);
    }
    Timer {
        id: integrationPoll
        interval: 650; repeat: true
        running: root.busy
        onTriggered: root.refreshIntegrationProgress()
    }
    Process {
        id: progressProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text.trim());
                if (result && typeof result.percent === "number") root.integrationInfo = result;
            } catch(e) { root.message = "Could not read installation progress: " + String(e); }
        } }
    }
    readonly property string helper: Quickshell.shellPath("scripts/rustiq-desktop-integration.py")
    readonly property string dependencyHelper: Quickshell.shellPath("scripts/rusticq-dependencies.py")
    property var dependencyInfo: ({ok:false, items:[], missing_core:0, missing_optional:0})
    property string dependencyFilter: ""
    property string selectedDependency: ""
    property string dependencyConfirmation: ""
    property string selectedDependencyAction: "install"
    property string dependencyMessage: ""
    property bool dependencyBusy: false
    property bool dependencyLastOk: true

    // Diagnostics and user-initiated JSON snapshots share the existing Settings page.
    // They never run sudo, write Hyprland config or enable background services.
    readonly property string doctorHelper: Quickshell.shellPath("scripts/rusticq-doctor.py")
    readonly property string guardHelper: Quickshell.shellPath("scripts/rusticq-config-guard.py")
    property string doctorSummary: "Not checked yet"
    property string guardSummary: "Not checked yet"
    property string guardMessage: ""
    property bool guardBusy: false
    Component.onCompleted: { refresh(); refreshDependencies(); refreshSafeTools(); shellUpdateRefresh(); }
    function refreshSafeTools() {
        if (!doctorProc.running) doctorProc.exec(["python3", doctorHelper, "status", "--json"]);
        if (!guardStatusProc.running) guardStatusProc.exec(["python3", guardHelper, "status"]);
    }
    function makeConfigBackup() {
        if (guardBusy || snapshotProc.running) return;
        guardBusy = true;
        snapshotProc.exec(["python3", guardHelper, "backup", "--kind", "settings"]);
    }
    function refreshDependencies() {
        if (!dependencyStatusProc.running)
            dependencyStatusProc.exec(["python3", dependencyHelper, "status"]);
    }
    function requestDependencyInstall() {
        if (dependencyBusy || dependencyActionProc.running || selectedDependency.length === 0
            || dependencyConfirmation !== (selectedDependencyAction === "remove" ? "REMOVE " + selectedDependency : "INSTALL")) return;
        dependencyBusy = true;
        dependencyMessage = "Waiting for graphical Polkit authorization and package transaction…";
        dependencyActionProc.exec(["python3", dependencyHelper, "gui", selectedDependency,
                                   "--operation", selectedDependencyAction,
                                   "--confirm", selectedDependencyAction.toUpperCase() + " " + selectedDependency]);
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
        Qt.callLater(root.refreshIntegrationProgress);
    }
    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    if (parsed.ok) {
                        root.info = parsed;
                        if (parsed.integration) root.integrationInfo = parsed.integration;
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
        id: verifyBackupProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const report = JSON.parse(this.text);
                root.backupIntegrity = report.ok === true ?
                    ("Verified · " + (report.verification.default_files || 0) + " default files + " + (report.verification.user_files || 0) + " user files") :
                    (report.message || "Integrity check failed");
            } catch (e) { root.backupIntegrity = "Backup verification failed: " + e; }
        } }
    }
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text);
                    root.lastOk = result.ok === true;
                    root.message = result.message || "No status was returned";
                    if (result.integration) root.integrationInfo = result.integration;
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
            Qt.callLater(root.refreshIntegrationProgress);
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
                root.dependencyMessage = "Dependency transaction failed: " + String(e);
            }
        } }
        onExited: (code, status) => {
            root.dependencyBusy = false;
            root.dependencyConfirmation = "";
            Qt.callLater(root.refreshDependencies);
        }
    }

    Process {
        id: doctorProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const r = JSON.parse(this.text);
                root.doctorSummary = r.totals.ok + " OK · " + r.totals.warn + " warnings · " + r.totals.skip + " unavailable";
            } catch (e) { root.doctorSummary = "Could not read Doctor report: " + e; }
        } }
    }
    Process {
        id: guardStatusProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const r = JSON.parse(this.text);
                root.guardSummary = r.ok === true ? ("Settings: " + r.data.settings.status + " · " + r.data.settings.snapshots + " snapshots") : (r.error || "Error");
            } catch (e) { root.guardSummary = "Could not read snapshot status: " + e; }
        } }
    }
    Process {
        id: snapshotProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const r = JSON.parse(this.text);
                root.guardMessage = r.ok === true ? "Saved settings snapshot " + r.data.id : (r.error || "Backup failed");
            } catch (e) { root.guardMessage = "Backup returned unreadable output: " + e; }
        } }
        onExited: (code, status) => {
            root.guardBusy = false;
            Qt.callLater(root.refreshSafeTools);
        }
    }
    SettingsSection {
        heading: "System Doctor & configuration recovery"
        description: "Read-only system inspection and opt-in snapshots of user-settings.json. No installation, Omarchy changes, or background monitoring."
        symbol: "\ue869"
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Doctor: " + root.doctorSummary; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.guardSummary; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 37; radius: 10; color: Theme.background
                Text { anchors.centerIn: parent; text: "Run diagnostics"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshSafeTools() }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 37; radius: 10
                color: root.guardBusy ? Theme.borderaccent : Theme.accent
                Text { anchors.centerIn: parent; text: root.guardBusy ? "Creating backup…" : "Backup settings now"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; enabled: !root.guardBusy; cursorShape: Qt.PointingHandCursor; onClicked: root.makeConfigBackup() }
            }
        }
        Text { visible: root.guardMessage.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.guardMessage; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "For explicit restore: rusticq config list settings, then rusticq config restore settings SNAPSHOT_ID --confirm RESTORE. Restart the shell after restoring."; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
    }

    SettingsSection {
        heading: "Required & optional dependencies"
        description: "Manage optional packages inside RusticQ with graphical Polkit authorization. Nothing installs on page load."
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
                        text: dependencyRow.installed ? (dependencyRow.modelData.group === "core" ? "Core · installed" : "Remove") : (dependencyRow.selected ? "Selected" : "Install")
                        color: dependencyRow.installed ? Theme.success : Theme.accent
                        font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !root.dependencyBusy && (!dependencyRow.installed || dependencyRow.modelData.group !== "core")
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.selectedDependency = dependencyRow.modelData.id;
                        root.selectedDependencyAction = dependencyRow.installed ? "remove" : "install";
                        root.dependencyConfirmation = "";
                    }
                }
            }
        }
        Text {
            visible: root.selectedDependency.length > 0
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Selected: " + root.selectedDependency + " · " + root.selectedDependencyAction.toUpperCase() + ". Confirm the action below, then authorize with graphical Polkit. Pacman's dependency and Omarchy policy checks remain enforced."
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
                    text: root.selectedDependencyAction === "remove" ? ("Type REMOVE " + root.selectedDependency) : "Type INSTALL to authorize installation"
                    color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                }
            }
        }
        Rectangle {
            id: dependencyCommit
            visible: root.selectedDependency.length > 0
            Layout.fillWidth: true; Layout.preferredHeight: visible ? 39 : 0
            radius: 11
            readonly property bool canInstall: root.selectedDependency.length > 0 && root.dependencyConfirmation === (root.selectedDependencyAction === "remove" ? "REMOVE " + root.selectedDependency : "INSTALL") && !root.dependencyBusy
            color: canInstall ? Theme.accent : Theme.borderaccent
            Text {
                anchors.centerIn: parent
                text: root.dependencyBusy ? "Working…" : (root.selectedDependencyAction === "remove" ? "Remove from GUI" : "Install from GUI")
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
        heading: "Shell Updates"
        description: "Automatically checks official GitHub Releases. Update ~/dev/quickshell even after restoring Omarchy, or update a permanently installed shell. Each target has separate rollback backups."
        symbol: "\ue869"
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Auto fetch: checks GitHub once on Settings load and hourly while open. Download/install requires confirmation."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Repeater { model: ["dev", "installed"]
                delegate: Rectangle {
                    required property string modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 9
                    color: root.shellUpdateTarget === modelData ? Theme.accent : Theme.background
                    Text { anchors.centerIn: parent
                        text: modelData === "dev" ? "DEV · ~/dev/quickshell" : "PERMANENT · shell"
                        color: root.shellUpdateTarget === modelData ? Theme.background : Theme.foreground
                        font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        enabled: !root.shellUpdateBusy
                        onClicked: { root.shellUpdateTarget = modelData; root.shellUpdateAction = ""; root.shellUpdateConfirm = ""; }
                    }
                }
            }
        }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: root.shellUpdateTarget === "dev"
                ? "Update target: " + (root.shellUpdateStatus.local_path || "~/dev/quickshell") + " · usable without permanent integration."
                : (root.shellUpdateStatus.installed
                   ? "Installed target: " + root.shellUpdateStatus.installed_path
                   : "Permanent shell not installed. Select DEV to update GitHub first, then install permanent when ready.")
            color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Last release for selected target: " + ((root.shellUpdateTarget === "dev" ? root.shellUpdateStatus.dev_tag : root.shellUpdateStatus.installed_tag) || "unknown/local")
                + " · Restore points: " + root.shellUpdateTargetBackups
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 8; color: Theme.background; radius: 5; clip: true
            Rectangle { height: parent.height; radius: 5; color: Theme.accent
                width: parent.width * Math.max(0, Math.min(100, root.shellUpdateStatus.progress || 0)) / 100 }
        }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: (root.shellUpdateStatus.phase || "Ready") + " · " + (root.shellUpdateStatus.progress || 0) + "%"
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Source: " + (root.shellUpdateStatus.local_path || "~/dev/quickshell") +
                  "   ·   Destination: " + (root.shellUpdateTarget === "dev" ? root.shellUpdateStatus.local_path : root.shellUpdateStatus.installed_path)
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10
                color: root.shellUpdateStatus.installed && !root.shellUpdateBusy ? Theme.accent : Theme.borderaccent
                Text { anchors.centerIn: parent; text: "Reapply Local"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; enabled: root.shellUpdateStatus.installed && root.shellUpdateStatus.dev_ready && !root.shellUpdateBusy && !root.shellUpdateCheckBusy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { root.shellUpdateTarget = "installed"; root.shellUpdateAction = "reapply-local"; root.shellUpdateConfirm = ""; } }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10; color: Theme.background
                Text { anchors.centerIn: parent; text: root.shellUpdateCheckBusy ? "Checking…" : "Check GitHub"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; enabled: !root.shellUpdateBusy && !root.shellUpdateCheckBusy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.shellUpdateCheck() }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10; color: Theme.background
            TextInput { id: updateTagInput; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter; text: root.shellReleaseTag; onTextEdited: root.shellReleaseTag = text
                color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); selectByMouse: true
                Text { visible: parent.text.length === 0; anchors.verticalCenter: parent.verticalCenter
                    text: "Optional release tag (e.g. beta-1); blank = newest published release"
                    color: Theme.muted; font.pixelSize: Fonts.scale(10) }
            }
        }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: root.shellUpdateStatus.release && root.shellUpdateStatus.release.tag ?
                  ("GitHub Release: " + root.shellUpdateStatus.release.tag + " · Full asset: " + root.shellUpdateStatus.release.asset +
                    " · Verification: " + (root.shellUpdateStatus.release.source_archive ? "official source ZIP (HTTPS; no published checksum)" : (root.shellUpdateStatus.release.digest || "checksum asset required"))) :
                  "Checking official GitHub Releases… Full ZIPs with checksums are preferred; GitHub source ZIP is the fallback."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 37; radius: 10
                color: root.shellUpdateTargetReady && root.shellUpdateStatus.release && root.shellUpdateStatus.release.tag ? Theme.accent : Theme.borderaccent
                Text { anchors.centerIn: parent; text: "Update Shell (GitHub)"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; enabled: root.shellUpdateTargetReady && root.shellUpdateStatus.release && !!root.shellUpdateStatus.release.tag && !root.shellUpdateBusy && !root.shellUpdateCheckBusy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { root.shellUpdateAction = "update-shell"; root.shellUpdateConfirm = ""; } }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 37; radius: 10; color: Theme.background
                Text { anchors.centerIn: parent; text: "Rollback Shell"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; enabled: root.shellUpdateTargetReady && root.shellUpdateTargetBackups > 0 && !root.shellUpdateBusy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { root.shellUpdateAction = "rollback"; root.shellUpdateConfirm = ""; } }
            }
        }
        ColumnLayout { id: updateConfirmColumn; Layout.fillWidth: true; spacing: 7; visible: root.shellUpdateAction.length > 0
            readonly property string phrase: root.shellUpdateAction === "reapply-local" ? "REAPPLY LOCAL" :
                    root.shellUpdateAction === "rollback" ? "ROLLBACK SHELL" : "UPDATE SHELL"
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "Confirm " + parent.phrase + " → " + (root.shellUpdateTarget === "dev" ? "~/dev/quickshell" : "~/.local/share/rusticq/shell") + ". Original files and user settings are preserved for rollback. GitHub source ZIPs have no independent published SHA-256. Restart the active shell manually."
                color: Theme.warning; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 39; radius: 10; color: Theme.background
                TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: TextInput.AlignVCenter
                    text: root.shellUpdateConfirm; onTextEdited: root.shellUpdateConfirm = text; selectByMouse: true
                    color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: parent.text.length === 0
                        text: "Type " + updateConfirmColumn.phrase
                        color: Theme.muted; font.pixelSize: Fonts.scale(10) } }
            }
            RowLayout { Layout.fillWidth: true; spacing: 8
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10; color: Theme.background
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.shellUpdateAction = ""; root.shellUpdateConfirm = ""; } }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10
                    color: root.shellUpdateConfirm === updateConfirmColumn.phrase && !root.shellUpdateBusy ? Theme.accent : Theme.borderaccent
                    Text { anchors.centerIn: parent; text: root.shellUpdateBusy ? "Installing…" : "Confirm & install"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; enabled: root.shellUpdateConfirm === updateConfirmColumn.phrase && !root.shellUpdateBusy
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.shellUpdateApply() }
                }
            }
        }
        Text { visible: root.shellUpdateMessage.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: root.shellUpdateMessage; color: root.shellUpdateOk ? Theme.success : Theme.warning
            font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "GitHub → DEV updates ~/dev/quickshell and works even after Restore Omarchy. Reapply Local → Permanent copies DEV to ~/.local/share/rusticq/shell. Rollback acts on the SELECTED target only. No system packages or Omarchy defaults are changed."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
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
                    text: "Before activation RusticQ snapshots the original Omarchy default Lua tree plus ~/.config/hypr, ~/.config/omarchy, and ~/.config/quickshell (if present). Private checksummed copies stay available for recovery; revert restores only managed files, preserving other edits. /usr/share/omarchy is never edited."
                    color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: integrationProgressColumn.implicitHeight + 28
            color: Theme.background
            radius: 12
            ColumnLayout {
                id: integrationProgressColumn
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 14
                spacing: 9
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Text {
                        Layout.fillWidth: true
                        text: root.integrationInfo.phase || "Checking integration status…"
                        color: root.integrationInfo.state === "failed" || root.integrationInfo.state === "incomplete" ? Theme.warning : Theme.foreground
                        font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12)
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        text: String(root.integrationInfo.percent || 0) + "%"
                        color: root.integrationInfo.state === "failed" ? Theme.warning : Theme.accent
                        font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(16)
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 4
                    color: Theme.surface; clip: true
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, root.integrationInfo.percent || 0)) / 100
                        height: parent.height; radius: 4
                        color: root.integrationInfo.state === "failed" || root.integrationInfo.state === "incomplete" ? Theme.warning : Theme.accent
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: root.integrationInfo.state === "installed"
                        ? "Installation COMPLETE (100%). RusticQ startup is configured for the next login. This does NOT confirm the current session has switched; log out and back in to activate."
                        : root.integrationInfo.state === "restored"
                        ? "Restore COMPLETE (100%). Original Omarchy startup is configured for the next login."
                        : root.integrationInfo.state === "running"
                        ? "Working… Percentage advances only when each installation step finishes."
                        : root.integrationInfo.message || "No permanent integration is running."
                    color: root.integrationInfo.state === "failed" || root.integrationInfo.state === "incomplete" ? Theme.warning : Theme.muted
                    font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                }
            }
        }
        Rectangle {
            visible: root.info.permanent === true
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? fileReportColumn.implicitHeight + 26 : 0
            radius: 12
            color: Theme.background
            ColumnLayout {
                id: fileReportColumn
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 13
                spacing: 7
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Icon { icon: "\ue873"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                    Text { Layout.fillWidth: true; text: "Integration file changes"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                    Rectangle { Layout.preferredWidth: 74; Layout.preferredHeight: 27; radius: 8; color: Theme.surface
                        Text { anchors.centerIn: parent; text: root.showFileReport ? "Hide paths" : "Show paths"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showFileReport = !root.showFileReport }
                    }
                }
                Repeater {
                    model: root.showFileReport ? (root.integrationInfo.changes || []) : []
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 2
                        RowLayout { Layout.fillWidth: true; spacing: 7
                            Text { text: modelData.action || "Unknown"; color: modelData.action === "Read only" ? Theme.muted : Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10); Layout.preferredWidth: 93 }
                            Text { Layout.fillWidth: true; text: modelData.path || ""; wrapMode: Text.WrapAnywhere; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                        }
                        Text { Layout.fillWidth: true; text: modelData.detail || ""; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: Fonts.scale(9) }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                    }
                }
                Text { visible: !root.showFileReport; text: "File locations hidden. Select Show paths to inspect all managed paths."; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
            }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Backup: " + ((root.info.backup_health && root.info.backup_health.message) || "Checking…")
                + (root.info.backup_health ? " · Default files: " + (root.info.backup_health.defaults || 0) + " · User entries: " + (root.info.backup_health.user_files || 0) : "")
            color: Theme.muted; font.pixelSize: Fonts.scale(10)
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 33; radius: 9; color: Theme.background
                Text { anchors.centerIn: parent; text: root.backupBusy ? "Backing up…" : "Backup default & user configs"; color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; enabled: !root.backupBusy && root.info.permanent !== true; cursorShape: Qt.PointingHandCursor; onClicked: {
                    root.backupBusy = true;
                    backupProc.exec(["python3", root.helper, "backup-omarchy"]);
                } }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 33; radius: 9; color: Theme.background
                Text { anchors.centerIn: parent; text: "Verify backup"; color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; enabled: !verifyBackupProc.running; cursorShape: Qt.PointingHandCursor; onClicked: verifyBackupProc.exec(["python3", root.helper, "verify-backup"]) }
            }
        }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.backupIntegrity; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
        Text {
            Layout.fillWidth: true
            text: root.info.permanent ? "Installation finished · next-login startup ready" : "Not installed permanently"
            color: root.info.permanent ? Theme.accent : Theme.muted
            font.family: Fonts.poppinsSB.name
            font.pixelSize: Fonts.scale(12)
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: root.info.compatibility && root.info.compatibility.omarchy_detected && root.info.compatibility.launcher_intercept_supported ?
                "Omarchy Quattro detected · " + (root.info.omarchy_backup_ready ? "backup available" : "backup will be created/verified before install") + ". Type ENABLE RUSTICQ and confirm to reinstall even after Restore Omarchy." :
                "Omarchy Quattro startup has not been verified. No automatic backup or permanent install will run."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        Text {
            visible: !root.info.permanent && root.info.reinstall && root.info.reinstall.stale_files && root.info.reinstall.stale_files.length > 0
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: root.info.reinstall ? root.info.reinstall.message : ""
            color: Theme.warning; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
            text: "Backups (preserved): " + (root.info.backup_dir || "~/.local/state/rusticq/integration/backup")
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
                            && root.info.compatibility.launcher_intercept_supported === true))
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
