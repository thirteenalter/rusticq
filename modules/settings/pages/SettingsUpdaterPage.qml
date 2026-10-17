import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    id: root
    width: parent ? parent.width : 700
    spacing: 14
    property var status: ({ state:"idle", busy:false, lines:[], message:"No upgrades started", progress:-1 })
    property var available: []
    property string checkMessage: "Check repository updates safely with checkupdates."
    property bool checking: false
    property bool starting: false
    property bool confirmation: false
    property bool showAllLog: true
    property bool followLog: true
    readonly property bool busy: status.busy || starting
    // Percent is for the pacman item CURRENTLY shown, not for whole upgrade.
    readonly property bool itemProgressAvailable: status.progressKind === "item" && status.progress >= 0 && status.progress <= 100
    readonly property bool transactionDone: status.state === "completed"
    readonly property bool omarchy: status.updaterMode === "omarchy" || status.omarchyGuard === true
    readonly property bool externalSession: status.state === "external"
    readonly property bool supported: true

    function refreshStatus() {
        if (!statusProc.running) statusProc.exec(["python3", Quickshell.shellPath("scripts/rustiq-updater.py"), "status"]);
    }
    function checkUpdates() {
        if (busy || checking) return;
        confirmation = false;
        checkMessage = "Checking repository mirrors safely…";
        checking = true;
        checkProc.exec(["python3", Quickshell.shellPath("scripts/rustiq-updater.py"), "check"]);
    }
    function startUpgrade() {
        if (busy) return;
        confirmation = false;
        starting = true;
        actionProc.exec(["python3", Quickshell.shellPath("scripts/rustiq-updater.py"), "start"]);
    }
    Component.onCompleted: Qt.callLater(refreshStatus)

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    if (parsed.ok) root.status = parsed;
                } catch (e) { root.checkMessage = "Unable to read updater status: " + String(e); }
            }
        }
    }
    Process {
        id: checkProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    root.available = parsed.packages || [];
                    root.checkMessage = parsed.message || "Update check finished";
                } catch (e) { root.checkMessage = "Unexpected checkupdates response: " + String(e); }
                root.checking = false;
            }
        }
        onExited: function(code, status) { root.checking = false; }
    }
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text);
                    root.checkMessage = result.message || (result.ok ? "Updater started" : "Updater unavailable");
                    if (result.ok) root.refreshStatus();
                } catch (e) { root.checkMessage = "Failed to launch updater: " + String(e); }
                root.starting = false;
            }
        }
        onExited: function(code, status) { root.starting = false; root.refreshStatus(); }
    }
    Timer {
        interval: 1300
        running: root.visible
        repeat: true
        onTriggered: root.refreshStatus()
    }

    SettingsSection {
        heading: "Arch Linux updater"
        description: root.omarchy ? "Omarchy owns system updates. Open its interactive terminal workflow to retain snapshots and migrations." : "Inspect pending updates, authorize a full upgrade, and follow pacman's output live."
        symbol: "\ue5d5"
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 12
                color: Qt.alpha(Theme.accent, 0.13)
                Icon { anchors.centerIn: parent; icon: root.busy ? "\ue5d5" : "\ue8b8"; color: Theme.accent; font.pixelSize: Fonts.scale(21)
                    RotationAnimator on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: root.busy } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: root.externalSession ? "Omarchy terminal started" : root.status.state === "running" ? "Upgrade running" : root.status.state === "completed" ? "Upgrade completed" : root.status.state === "failed" ? "Update failed" : root.omarchy ? "Omarchy system updates" : "System package updates"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                Text { text: root.status.message || root.checkMessage; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            radius: 4
            color: Theme.background
            clip: true
            Rectangle {
                width: parent.width * (root.transactionDone ? 1 : root.itemProgressAvailable ? root.status.progress / 100 : 0)
                height: parent.height
                radius: 4
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 140 } }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 9
            Icon {
                visible: root.busy || root.checking
                icon: "\ue5d5"
                color: Theme.accent
                font.pixelSize: Fonts.scale(17)
                RotationAnimator on rotation { running: root.busy || root.checking; from: 0; to: 360; duration: 1150; loops: Animation.Infinite }
            }
            Text {
                Layout.fillWidth: true
                text: root.checking ? "Checking repositories (no percentage available)" :
                    root.transactionDone ? "Transaction complete" :
                    root.itemProgressAvailable ? "Current pacman item: " + root.status.progress + "%" :
                    root.busy && root.omarchy ? "Follow progress and answer prompts in the Omarchy terminal" :
                    root.externalSession ? "See the terminal for the actual transaction status; no percentage is inferred" :
                    root.busy ? "Waiting for the next pacman progress update…" : "No upgrade running"
                color: Theme.foreground
                font.family: Fonts.poppinsSB.name
                font.pixelSize: Fonts.scale(11)
            }
            Text {
                visible: root.status.total > 0
                text: root.status.completed + " / " + root.status.total + " packages/hooks"
                color: Theme.muted
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(10)
            }
        }
        Text {
            Layout.fillWidth: true
            visible: root.busy && (root.status.item || root.status.details)
            text: (root.status.item || "") + (root.status.details && root.status.details !== root.status.message ? " · " + root.status.details : "")
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(10)
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 39; radius: 11
                opacity: root.busy || root.checking ? 0.45 : 1
                color: Theme.background
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Icon { icon: "\ue8b6"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                    Text { text: root.checking ? "Checking…" : "Check updates"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                }
                MouseArea { anchors.fill: parent; enabled: !root.busy && !root.checking; cursorShape: Qt.PointingHandCursor; onClicked: root.checkUpdates() }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 39; radius: 11
                opacity: root.busy ? 0.45 : 1
                color: Qt.alpha(Theme.accent, 0.18)
                border.width: 1; border.color: Theme.accent
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Icon { icon: "\ue5d5"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                    Text { text: root.busy ? "Updating…" : root.omarchy ? "Open Omarchy update" : "Install all updates"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                }
                MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmation = true }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: root.omarchy
            text: root.status.omarchyGuard ? "The previous direct pacman attempt was blocked by Omarchy. Use `omarchy update` instead. RusticQ never bypasses its guard." : "Omarchy detected · recommended command: omarchy update · interactive terminal required."
            wrapMode: Text.WordWrap
            color: Theme.accent; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
        Text {
            Layout.fillWidth: true
            text: root.checkMessage
            wrapMode: Text.WordWrap
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
    }
    SettingsSection {
        visible: root.confirmation && !root.busy
        heading: "Confirm system upgrade"
        description: "This is a real system-wide operation, not a simulation."
        symbol: "\ue002"
        Text {
            Layout.fillWidth: true
            text: root.omarchy ? "Launch `omarchy update` in a terminal? Review snapshots, migrations, package changes, and any prompts in that terminal. RusticQ will not bypass the Omarchy pacman guard or auto-confirm the upgrade." : "Run a full pacman -Syu using graphical PolicyKit authorization? Packages and dependencies may change. The updater runs with pacman's default answers (--noconfirm). Back up important data and review Arch news first. AUR packages are not upgraded."
            wrapMode: Text.WordWrap; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 9
            Repeater {
                model: [{ label:"Cancel", approve:false }, { label:root.omarchy ? "Open Omarchy terminal" : "Authorize full upgrade", approve:true }]
                delegate: Rectangle {
                    id: confirmButton; required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 11
                    color: confirmButton.modelData.approve ? Qt.alpha(Theme.accent, 0.20) : Theme.background
                    border.width: confirmButton.modelData.approve ? 1 : 0; border.color: Theme.accent
                    Text { anchors.centerIn: parent; text: confirmButton.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (confirmButton.modelData.approve) root.startUpgrade(); else root.confirmation = false; } }
                }
            }
        }
    }

    SettingsSection {
        heading: "Available updates"
        description: "Package names, current versions, and candidate repository versions"
        symbol: "\ue5c3"
        Text {
            Layout.fillWidth: true
            text: root.available.length > 0 ? root.available.length + " packages identified in the latest check" : (root.checking ? "Checking repository…" : "Run Check updates to list repository upgrades")
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(235, Math.max(0, root.available.length * 40))
            visible: root.available.length > 0
            model: root.available
            clip: true; spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: pkgRow
                required property var modelData
                width: ListView.view.width; height: 37; radius: 9; color: Theme.background
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                    Text { text: pkgRow.modelData.name; Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    Text { text: pkgRow.modelData.installed + "  →  " + pkgRow.modelData.new; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); elide: Text.ElideLeft; Layout.preferredWidth: 215; horizontalAlignment: Text.AlignRight }
                }
            }
        }
    }
    SettingsSection {
        heading: root.omarchy ? "Omarchy update output" : "Pacman terminal output"
        description: root.omarchy ? "Omarchy displays its interactive transaction in a terminal. Its own transcript appears here when available; no success is inferred from the window closing." : "PTY capture of actual pacman output. Percentages apply to the current package or download, never to the full upgrade."
        symbol: "\ueb8e"
        RowLayout {
            Layout.fillWidth: true; spacing: 9
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 29; radius: 9; color: Theme.background
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 9; spacing: 8
                    Icon { icon: "\ueb8e"; color: Theme.accent; font.pixelSize: Fonts.scale(15) }
                    Text { text: root.status.phase || root.status.state || "idle"; Layout.fillWidth: true; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                    Text { text: root.transactionDone ? "DONE" : root.itemProgressAvailable ? "ITEM " + root.status.progress + "%" : root.busy ? "LIVE" : "--"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                }
            }
            Rectangle {
                Layout.preferredWidth: 90; Layout.preferredHeight: 29; radius: 9; color: Theme.background
                Text { anchors.centerIn: parent; text: root.followLog ? "Auto-scroll" : "Hold scroll"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.followLog = !root.followLog }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 286
            radius: 12
            color: Theme.background
            ListView {
                id: terminalList
                anchors.fill: parent
                anchors.margins: 9
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: root.status.lines || []
                onCountChanged: if (root.followLog && count > 0) Qt.callLater(function(){ terminalList.positionViewAtEnd(); })
                delegate: Text {
                    required property string modelData
                    width: terminalList.width
                    text: modelData
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    color: modelData.indexOf('[ERROR]') >= 0 || modelData.indexOf('[FAILED]') >= 0 ? Theme.error : Theme.foreground
                    font.family: "monospace"
                    font.pixelSize: Fonts.scale(10)
                }
                Text { anchors.centerIn: parent; visible: terminalList.count === 0; text: "No terminal output yet. Start an update to see the process."; color: Theme.muted; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppins.name }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Persistent log: " + (root.status.logPath || "~/.local/state/rustiq/updater/pacman.log") + ". Do not close a running upgrade via reboot or system shutdown."
            color: Theme.muted; wrapMode: Text.WordWrap; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
    }
    SettingsSection {
        heading: "Update safety"
        description: "Important Arch Linux upgrade precautions"
        symbol: "\ue88e"
        Text {
            Layout.fillWidth: true
            text: root.omarchy ? "On Omarchy, use `omarchy update` to retain snapshots, hooks, migrations and interactive review. Never use a direct pacman guard-bypass as an automatic fallback. The checkupdates list covers repository packages, not Omarchy's complete update plan." : "Only full repository updates (-Syu) are supported. Check Updates requires pacman-contrib. Install Updates requires a graphical PolicyKit authentication agent. The updater cannot change AUR-built packages and does not automatically resolve .pacnew files, package conflicts, or breaking changes."
            color: Theme.muted; wrapMode: Text.WordWrap; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
    }
}
