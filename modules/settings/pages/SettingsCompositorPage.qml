import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

// A safe editor, NOT a HyprMod fork: schema-limited settings, diff + explicit
// confirmation, verified backups, compositor rollback, no direct editing of
// Omarchy-owned /usr/share files. Niri-only features are gated by backend.
ColumnLayout {
    id: root
    width: parent ? parent.width : 680
    spacing: 14
    property string backend: "unknown"
    property string section: "autostart"
    property var available: ({})
    property var sections: ({})
    property var savedValues: ({})
    property string phase: ""
    property string notification: ""
    property bool failed: false
    property string token: ""
    property string diff: ""
    property var frozenValues: ({})
    property var snapshots: []
    readonly property var visibleSnapshots: snapshots.filter(s => s.backend === backend)
    property string activeSnapshot: ""
    readonly property string helper: Quickshell.shellPath("scripts/rusticq-compositor-config.py")
    readonly property bool ready: backend === "hyprland" || backend === "niri"
    readonly property bool sectionReady: !!available[section] && !!sections[section] && !sections[section].error
    readonly property var groups: [
        {id:"autostart",label:"Autostart",icon:"\ue5d5",hint:"Startup commands"},
        {id:"appearance",label:"Appearance",icon:"\ue40a",hint:"Gaps & corners"},
        {id:"input",label:"Input",icon:"\ue312",hint:"Keyboard & touchpad"},
        {id:"monitors",label:"Monitors",icon:"\ue30b",hint:"Output profile"}
    ]
    Component.onCompleted: refresh()
    function refresh() {
        if (!scanProc.running) scanProc.exec(["python3", helper, "status"]);
        if (!historyProc.running) historyProc.exec(["python3", helper, "history"]);
    }
    function changed() { token = ""; diff = ""; notification = ""; }
    function loadValues() {
        const data = sections[section] ? sections[section].values || {} : {};
        savedValues = data;
        commands.text = (data.commands || []).join("\n");
        gapInside.text = String(data.gaps_in === undefined ? 5 : data.gaps_in);
        gapOutside.text = String(data.gaps_out === undefined ? 10 : data.gaps_out);
        roundness.text = String(data.rounding === undefined ? 8 : data.rounding);
        keyboardLayout.text = String(data.kb_layout || "us");
        followMouse.checked = data.follow_mouse !== false;
        naturalScroll.checked = !!data.natural_scroll;
        outputName.text = String(data.output || "eDP-1");
        outputMode.text = String(data.mode || "preferred");
        outputPosition.text = String(data.position || "auto");
        outputScale.text = String(data.scale === undefined ? 1 : data.scale);
        changed();
    }
    function values() {
        if (section === "autostart") return {commands: commands.text.split("\n").map(s => s.trim()).filter(s => s.length)};
        if (section === "appearance") {
            const v = {gaps_in: Number(gapInside.text), gaps_out: Number(gapOutside.text)};
            if (backend === "hyprland") v.rounding = Number(roundness.text);
            return v;
        }
        if (section === "input") return {kb_layout: keyboardLayout.text.trim(), follow_mouse: followMouse.checked, natural_scroll: naturalScroll.checked};
        return {output: outputName.text.trim(), mode: outputMode.text.trim(), position: outputPosition.text.trim(), scale: Number(outputScale.text)};
    }
    function execute(operation) {
        if (actionProc.running || !sectionReady) return;
        phase = operation;
        failed = false;
        notification = operation === "preview" ? "Generating diff…" : "Applying and validating…";
        if (operation === "preview") frozenValues = values();
        const data = operation === "apply" ? frozenValues : values();
        actionProc.exec(["python3", helper, operation, "--section", section, "--values", JSON.stringify(data), "--token", operation === "apply" ? token : ""]);
    }
    function doRollback() {
        if (!activeSnapshot || actionProc.running) return;
        phase = "rollback";
        actionProc.exec(["python3", helper, "rollback", "--snapshot", activeSnapshot]);
    }
    Process {
        id: scanProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const payload = JSON.parse(text);
                root.backend = payload.backend || "unknown";
                root.available = payload.editable || {};
                root.sections = payload.sections || {};
                root.activeSnapshot = root.visibleSnapshots.length ? root.visibleSnapshots[0].snapshot : "";
                root.loadValues();
            } catch(e) { root.failed = true; root.notification = "Detection failed: " + String(e); }
        } }
    }
    Process {
        id: historyProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const payload = JSON.parse(text);
                root.snapshots = payload.snapshots || [];
                root.activeSnapshot = root.visibleSnapshots.length ? root.visibleSnapshots[0].snapshot : "";
            } catch (e) { root.snapshots = []; }
        } }
    }
    Process {
        id: actionProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const payload = JSON.parse(text);
                root.failed = !payload.ok;
                root.notification = payload.message || payload.note || (payload.ok ? "Operation verified." : "Operation failed.");
                if (payload.ok && root.phase === "preview") {
                    root.token = payload.changed ? payload.token : "";
                    root.diff = payload.diff || "No changes.";
                } else if (root.phase !== "preview") {
                    root.token = "";
                    root.diff = "";
                    root.refresh();
                } else { root.token = ""; root.diff = ""; }
            } catch(e) {
                root.failed = true;
                root.token = "";
                root.notification = "Compositor helper returned invalid JSON: " + String(e);
            }
        } }
        onExited: (code, status) => {
            if (code !== 0 && !root.notification) { root.failed = true; root.notification = "Operation exited with code " + code; }
        }
    }

    SettingsSection {
        heading: "Compositor studio"
        description: "Graphical, version-aware controls inspired by HyprMod. Only RusticQ-owned blocks are edited. Original Omarchy files are preserved."
        symbol: "\ue8b8"
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.preferredWidth: 10; Layout.preferredHeight: 10; radius: 5
                color: root.ready ? Theme.success : Theme.warning }
            Text { Layout.fillWidth: true
                text: root.backend === "hyprland" ? "HYPRLAND · Lua / Omarchy Quattro" : root.backend === "niri" ? "NIRI · KDL" : "COMPOSITOR NOT DETECTED"
                color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            Rectangle { Layout.preferredWidth: 76; Layout.preferredHeight: 28; radius: 8; color: Theme.background
                Text { anchors.centerIn: parent; text: "Refresh"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
        }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: Fonts.scale(10); color: Theme.muted
            text: root.backend === "niri" ? "Niri: Autostart and gap controls are available only with native KDL validation. Other controls stay read-only rather than writing Hyprland syntax." : "Hyprland: schema-limited Lua editing through your user autostart.lua / looknfeel.lua / input.lua / monitors.lua. Keybindings remain in Settings → Shortcuts." }
    }

    SettingsSection {
        heading: "Configuration sections"
        description: "Select a category. Unsupported combinations are visibly locked."
        symbol: "\ue5c3"
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 9; rowSpacing: 9
            Repeater {
                model: root.groups
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool chosen: root.section === modelData.id
                    readonly property bool enabledHere: !!root.available[modelData.id]
                    Layout.fillWidth: true; Layout.preferredHeight: 67; radius: 11
                    color: chosen ? Qt.alpha(Theme.accent, 0.17) : Theme.background
                    border.color: chosen ? Theme.accent : Theme.borderaccent
                    border.width: chosen ? 1 : 0
                    opacity: enabledHere ? 1 : .52
                    RowLayout { anchors.fill: parent; anchors.margins: 10; spacing: 8
                        Icon { icon: tile.modelData.icon; color: Theme.accent; font.pixelSize: Fonts.scale(19) }
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: tile.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                            Text { text: tile.enabledHere ? tile.modelData.hint : "Read-only on this backend"; color: Theme.muted; font.pixelSize: Fonts.scale(9) }
                        }
                    }
                    MouseArea { anchors.fill: parent; enabled: tile.enabledHere; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.section = tile.modelData.id; root.loadValues(); } }
                }
            }
        }
    }

    SettingsSection {
        visible: root.ready
        heading: (root.groups.find(g => g.id === root.section) || {label:"Configuration"}).label
        description: "Preview is required before Apply. Changes to startup applications run on your NEXT login."
        symbol: "\ue873"
        Text { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; color: Theme.muted; font.pixelSize: Fonts.scale(10)
            text: root.sections[root.section] ? "Source: " + root.sections[root.section].path : "No supported source file" }
        Text { visible: !!(root.sections[root.section] && root.sections[root.section].error)
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.warning; font.pixelSize: Fonts.scale(11)
            text: root.sections[root.section] ? root.sections[root.section].error || "" : "" }
        ColumnLayout { visible: root.section === "autostart"; Layout.fillWidth: true; spacing: 6
            Text { text: "Startup commands · one per line"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 164; radius: 9; color: Theme.background
                TextArea { id: commands; anchors.fill: parent; anchors.margins: 10; wrapMode: TextEdit.Wrap
                    placeholderText: "waybar\nfcitx5 -d\nuwsm-app -- your-app"; color: Theme.foreground; font.pixelSize: Fonts.scale(11)
                    onTextChanged: root.changed() }
            }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.warning; font.pixelSize: Fonts.scale(10)
                text: "Commands execute when the session starts, with your user permissions. Only enter software you trust. Avoid duplicating existing Omarchy startup services." }
        }
        GridLayout { visible: root.section === "appearance"; Layout.fillWidth: true; columns: 2; columnSpacing: 9; rowSpacing: 8
            Text { text: "Inner gaps"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            TextField { id: gapInside; Layout.fillWidth: true; placeholderText: "5"; color: Theme.foreground; onTextEdited: root.changed() }
            Text { text: root.backend === "niri" ? "Reserved (Niri has one gap)" : "Outer gaps"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            TextField { id: gapOutside; Layout.fillWidth: true; enabled: root.backend === "hyprland"; placeholderText: "10"; color: Theme.foreground; onTextEdited: root.changed() }
            Text { visible: root.backend === "hyprland"; text: "Corner rounding"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            TextField { id: roundness; Layout.fillWidth: true; visible: root.backend === "hyprland"; placeholderText: "8"; color: Theme.foreground; onTextEdited: root.changed() }
        }
        ColumnLayout { visible: root.section === "input"; Layout.fillWidth: true
            RowLayout { Layout.fillWidth: true
                Text { text: "Keyboard layout"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
                TextField { id: keyboardLayout; Layout.fillWidth: true; placeholderText: "us"; color: Theme.foreground; onTextEdited: root.changed() }
            }
            CheckBox { id: followMouse; text: "Focus follows mouse"; onToggled: root.changed() }
            CheckBox { id: naturalScroll; text: "Touchpad natural scrolling"; onToggled: root.changed() }
        }
        GridLayout { visible: root.section === "monitors"; Layout.fillWidth: true; columns: 2; columnSpacing: 9; rowSpacing: 8
            Text { text: "Output"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            TextField { id: outputName; Layout.fillWidth: true; placeholderText: "eDP-1"; color: Theme.foreground; onTextEdited: root.changed() }
            Text { text: "Resolution @ refresh"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            TextField { id: outputMode; Layout.fillWidth: true; placeholderText: "preferred"; color: Theme.foreground; onTextEdited: root.changed() }
            Text { text: "Position"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            TextField { id: outputPosition; Layout.fillWidth: true; placeholderText: "auto"; color: Theme.foreground; onTextEdited: root.changed() }
            Text { text: "Scale"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
            TextField { id: outputScale; Layout.fillWidth: true; placeholderText: "1.0"; color: Theme.foreground; onTextEdited: root.changed() }
            Text { Layout.columnSpan: 2; Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "Warning: a wrong monitor rule can blank a screen. Backups are automatic. Existing display live-test controls remain under Settings → Displays.";
                color: Theme.warning; font.pixelSize: Fonts.scale(10) }
        }
        RowLayout { Layout.fillWidth: true; spacing: 9
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 10; color: Theme.background
                Text { anchors.centerIn: parent; text: "Preview changes"; color: Theme.accent; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: root.sectionReady && !actionProc.running;
                    onClicked: root.execute("preview") }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 10
                color: root.token.length ? Theme.accent : Theme.background
                Text { anchors.centerIn: parent; text: root.token.length ? "Apply verified preview" : "Preview required"; color: root.token.length ? Theme.background : Theme.muted; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: root.token.length > 0 && !actionProc.running; onClicked: root.execute("apply") }
            }
        }
        Text { visible: root.notification.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: root.notification; font.pixelSize: Fonts.scale(11); color: root.failed ? Theme.warning : Theme.accent }
        Rectangle { visible: root.diff.length > 0; Layout.fillWidth: true; Layout.preferredHeight: visible ? Math.min(320, 68 + diffArea.contentHeight) : 0; radius: 10; color: Theme.background
            clip: true
            Flickable { anchors.fill: parent; anchors.margins: 9; contentHeight: diffArea.contentHeight; clip: true
                TextArea { id: diffArea; width: parent.width; readOnly: true; text: root.diff; wrapMode: TextEdit.Wrap; color: Theme.foreground; font.family: "monospace"; font.pixelSize: Fonts.scale(10) }
            }
        }
    }
    SettingsSection {
        heading: "Backup history & rollback"
        description: "Each Apply stores a private SHA-256 snapshot. Rollback refuses to overwrite edits made after the selected snapshot."
        symbol: "\ue8b8"
        Text { Layout.fillWidth: true; color: Theme.muted; font.pixelSize: Fonts.scale(10); wrapMode: Text.WrapAnywhere
            text: root.visibleSnapshots.length ? root.visibleSnapshots.length + " recent snapshots (newest first)" : "No RusticQ compositor edits have been applied yet." }
        RowLayout { Layout.fillWidth: true; spacing: 8
            ComboBox { Layout.fillWidth: true; model: root.visibleSnapshots.map(s => s.snapshot + " · " + s.backend + "/" + s.section); currentIndex: 0
                onActivated: (index) => root.activeSnapshot = root.visibleSnapshots[index].snapshot }
            Rectangle { Layout.preferredWidth: 135; Layout.preferredHeight: 39; radius: 9; color: Theme.background
                Text { anchors.centerIn: parent; text: "Restore backup"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; enabled: !!root.activeSnapshot && !actionProc.running; cursorShape: Qt.PointingHandCursor; onClicked: root.doRollback() }
            }
        }
        Text { Layout.fillWidth: true; color: Theme.muted; font.pixelSize: Fonts.scale(10); wrapMode: Text.WordWrap
            text: "For keybindings, use the existing Settings → Shortcuts manager. Window/layer rules are not rewritten automatically: Hyprland rule schemas change between releases." }
    }
}
