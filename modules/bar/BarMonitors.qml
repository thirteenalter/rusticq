import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

// Native display arrangement preview for Hyprland Lua. Drag moves the draft only.
// Apply runs a strictly validated helper. Export never overwrites the user's config.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12
    property var drafts: []
    property string selectedName: ""
    property string detailsOpen: ""
    property string status: "Loading active monitors…"
    property bool busy: readMonitors.running || editMonitors.running
    readonly property real minX: drafts.length ? Math.min.apply(null, drafts.map(m => m.x)) : 0
    readonly property real minY: drafts.length ? Math.min.apply(null, drafts.map(m => m.y)) : 0
    readonly property real maxX: drafts.length ? Math.max.apply(null, drafts.map(m => m.x + m.width / m.scale)) : 1920
    readonly property real maxY: drafts.length ? Math.max.apply(null, drafts.map(m => m.y + m.height / m.scale)) : 1080
    readonly property real previewScale: Math.max(0.03, Math.min((preview.width - 44) / Math.max(1, maxX-minX),
                                                               (preview.height - 40) / Math.max(1, maxY-minY)))
    readonly property var selected: drafts.find(m => m.name === selectedName) || null
    function chooseMode(name, value) {
        const cleanMode = value.replace("Hz", "");
        const match = cleanMode.match(/^(\d+)x(\d+)@/);
        drafts = drafts.map(m => m.name === name ? Object.assign({}, m, {
            mode: cleanMode,
            width: match ? Number(match[1]) : m.width,
            height: match ? Number(match[2]) : m.height
        }) : m);
    }
    function update(name, field, value) {
        const next = drafts.map(m => {
            if (m.name !== name) return m;
            const copy = Object.assign({}, m);
            copy[field] = value;
            return copy;
        });
        drafts = next;
    }
    function placeNextTo(name, side) {
        if (drafts.length < 2) return;
        const reference = drafts.find(m => m.name !== name);
        const target = drafts.find(m => m.name === name);
        if (!reference || !target) return;
        const rw = Math.round(reference.width / reference.scale);
        const rh = Math.round(reference.height / reference.scale);
        const tw = Math.round(target.width / target.scale);
        const th = Math.round(target.height / target.scale);
        const x = side === "right" ? reference.x + rw : side === "left" ? reference.x - tw : reference.x;
        const y = side === "below" ? reference.y + rh : side === "above" ? reference.y - th : reference.y;
        drafts = drafts.map(m => m.name === name ? Object.assign({}, m, {x:x, y:y}) : m);
    }
    function run(action) {
        if (busy || drafts.length === 0) return;
        currentAction.action = action;
        currentAction.data = JSON.stringify(drafts) + "\n";
        status = action === "apply" ? "Applying monitor layout…" : action === "export" ? "Exporting Lua…" : "Checking preview…";
        editMonitors.command = ["python3", Quickshell.shellPath("scripts/rustiq-display.py"), action];
        editMonitors.running = true;
    }
    QtObject { id: currentAction; property string action: ""; property string data: "" }
    Process {
        id: readMonitors
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const items = JSON.parse(this.text);
                    if (!Array.isArray(items)) throw Error("not an array");
                    root.drafts = items.filter(m => m.name && m.width > 0).map(m => ({
                        name: m.name, width: m.width, height: m.height,
                        x: Math.round(m.x || 0), y: Math.round(m.y || 0),
                        scale: Number(m.scale || 1),
                        mode: (m.width + "x" + m.height + "@" + Math.round(m.refreshRate || 60)),
                        modes: Array.isArray(m.availableModes) ? m.availableModes : [],
                        description: m.description || "", transform: m.transform || 0,
                        focused: Boolean(m.focused), vrr: Boolean(m.vrr),
                        refreshRate: Math.round(m.refreshRate || 60)
                    }));
                    if (!root.drafts.some(m => m.name === root.selectedName))
                        root.selectedName = root.drafts.length ? root.drafts[0].name : "";
                    root.status = root.drafts.length ? "Drag to arrange, then select Apply to change the desktop." : "No active monitors reported.";
                } catch (e) { root.status = "Could not parse Hyprland monitors: " + e; }
            }
        }
        onExited: (code, status) => { if (code !== 0) root.status = "Unable to read monitors (is Hyprland running?)"; }
    }
    Process {
        id: editMonitors
        stdinEnabled: true
        onStarted: { write(currentAction.data); currentAction.data = ""; }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim());
                    root.status = data.message || (data.ok ? "Saved" : "Failed");
                    if (data.ok && currentAction.action === "apply") readMonitors.running = true;
                } catch (e) { root.status = "Display helper returned an unreadable response"; }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && (root.status === "Applying monitor layout…" || root.status === "Checking preview…"))
                root.status = "Display update failed. Check Hyprland's Lua API and monitor modes.";
        }
    }
    Timer {
        interval: 10000; repeat: true; running: root.visible
        triggeredOnStart: true
        onTriggered: if (!root.busy && root.drafts.length === 0) readMonitors.running = true
    }

    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Arrange your displays"; font.family: Fonts.poppinsSB.name; font.pixelSize: 14; color: Theme.foreground }
        Rectangle {
            Layout.preferredWidth: 88; Layout.preferredHeight: 31; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "Refresh"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 11 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (!root.busy) readMonitors.running = true; } }
        }
    }
    Text { Layout.fillWidth: true; text: "Move each screen with drag & drop. Changes stay in preview until you press Apply."; font.family: Fonts.poppins.name; font.pixelSize: 11; color: Theme.muted; wrapMode: Text.WordWrap }

    Rectangle {
        id: preview
        Layout.fillWidth: true; Layout.preferredHeight: 245
        radius: 15; color: Qt.alpha(Theme.foreground, .035)
        border.color: Theme.borderaccent; border.width: 1
        clip: true
        Repeater {
            model: root.drafts
            delegate: Rectangle {
                id: screenChip
                required property var modelData
                readonly property var display: modelData
                width: Math.max(55, Math.round(display.width / display.scale * root.previewScale))
                height: Math.max(38, Math.round(display.height / display.scale * root.previewScale))
                x: 20 + (display.x - root.minX) * root.previewScale
                y: 18 + (display.y - root.minY) * root.previewScale
                radius: 9
                color: root.selectedName === display.name ? Qt.alpha(Theme.accent, .2) : Theme.surface
                border.color: root.selectedName === display.name ? Theme.accent : Theme.muted
                border.width: root.selectedName === display.name ? 2 : 1
                Column {
                    anchors.centerIn: parent; spacing: 3
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: screenChip.display.name; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: screenChip.display.width + "×" + screenChip.display.height; font.family: Fonts.poppins.name; font.pixelSize: 9; color: Theme.muted }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.OpenHandCursor
                    drag.target: screenChip
                    drag.minimumX: 2; drag.minimumY: 2
                    drag.maximumX: Math.max(2, preview.width - screenChip.width - 2)
                    drag.maximumY: Math.max(2, preview.height - screenChip.height - 2)
                    onPressed: root.selectedName = screenChip.display.name
                    onReleased: {
                        const nx = Math.round(root.minX + (screenChip.x - 20) / root.previewScale);
                        const ny = Math.round(root.minY + (screenChip.y - 18) / root.previewScale);
                        root.drafts = root.drafts.map(m => m.name === screenChip.display.name ? Object.assign({}, m, {x:nx, y:ny}) : m);
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: root.drafts.length + " connected · logical coordinates in px · avoid overlapping displays"
        font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted
    }
    Repeater {
        model: root.drafts
        delegate: Rectangle {
            id: detailCard
            required property var modelData
            readonly property bool opened: root.detailsOpen === modelData.name
            readonly property var current: root.drafts.find(m => m.name === modelData.name) || modelData
            Layout.fillWidth: true
            Layout.preferredHeight: opened ? detailColumn.implicitHeight + 24 : 62
            radius: 11; color: Theme.surface; border.color: opened ? Qt.alpha(Theme.accent, .65) : Theme.borderaccent
            ColumnLayout {
                id: detailColumn
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 12
                spacing: 10
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: 38
                    RowLayout {
                        anchors.fill: parent
                        Icon { icon: "\ue30b"; font.pixelSize: 20; color: Theme.accent }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: detailCard.modelData.name + (detailCard.modelData.focused ? " · Primary" : ""); font.family: Fonts.poppinsSB.name; font.pixelSize: 12; color: Theme.foreground }
                            Text { text: detailCard.current.width + "×" + detailCard.current.height + " · " + detailCard.current.mode.split("@").slice(-1)[0] + " Hz · " + detailCard.current.scale + "x"; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted }
                        }
                        Icon { icon: detailCard.opened ? "\ue5ce" : "\ue5cf"; font.pixelSize: 20; color: Theme.foreground }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.detailsOpen = detailCard.opened ? "" : detailCard.modelData.name; root.selectedName = detailCard.modelData.name; } }
                }
                ColumnLayout {
                    visible: detailCard.opened
                    Layout.fillWidth: true
                    spacing: 10
                    Text { Layout.fillWidth: true; text: detailCard.modelData.description || "Connected monitor"; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted; wrapMode: Text.WordWrap }
                    Text { text: "Position relative to another monitor"; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: [{text:"Left",side:"left"},{text:"Right",side:"right"},{text:"Above",side:"above"},{text:"Below",side:"below"}]
                            delegate: Rectangle {
                                id: sideButton; required property var modelData
                                Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8
                                color: Theme.background
                                Text { anchors.centerIn: parent; text: sideButton.modelData.text; font.pixelSize: 10; font.family: Fonts.poppins.name; color: Theme.foreground }
                                MouseArea { anchors.fill: parent; enabled: root.drafts.length > 1; cursorShape: Qt.PointingHandCursor; onClicked: root.placeNextTo(detailCard.modelData.name, sideButton.modelData.side) }
                            }
                        }
                    }
                    Text { text: "Resolution and refresh rate"; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                    Flow {
                        Layout.fillWidth: true; width: parent.width; spacing: 6
                        Repeater {
                            model: (root.drafts.find(m => m.name === detailCard.modelData.name) || detailCard.modelData).modes.slice(0, 16)
                            delegate: Rectangle {
                                id: modeButton; required property var modelData
                                readonly property bool chosen: (root.drafts.find(m => m.name === detailCard.modelData.name) || {}).mode === modelData.replace("Hz", "")
                                width: modeText.implicitWidth + 18; height: 29; radius: 7
                                color: chosen ? Qt.alpha(Theme.accent, .2) : Theme.background
                                border.color: chosen ? Theme.accent : "transparent"
                                Text { id: modeText; anchors.centerIn: parent; text: modeButton.modelData; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.foreground }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.chooseMode(detailCard.modelData.name, modeButton.modelData) }
                            }
                        }
                    }
                    Text { text: "Scale"; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: [1, 1.25, 1.5, 1.75, 2]
                            delegate: Rectangle {
                                id: scaleButton; required property real modelData
                                Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8
                                readonly property bool active: (root.drafts.find(m => m.name === detailCard.modelData.name) || {}).scale === modelData
                                color: active ? Qt.alpha(Theme.accent, .2) : Theme.background
                                border.width: active ? 1 : 0; border.color: Theme.accent
                                Text { anchors.centerIn: parent; text: scaleButton.modelData + "x"; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.foreground }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.update(detailCard.modelData.name, "scale", scaleButton.modelData) }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        readonly property var display: root.drafts.find(m => m.name === detailCard.modelData.name) || detailCard.modelData
                        text: "Coordinates: " + display.x + ", " + display.y + " px · Transform " + display.transform + " · VRR " + (display.vrr ? "on" : "off")
                        font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted
                    }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: [{text: "Validate", action: "dry-run"}, {text: "Apply layout", action: "apply"}, {text: "Export Lua", action: "export"}]
            delegate: Rectangle {
                id: actionBtn; required property var modelData
                Layout.fillWidth: true; Layout.preferredHeight: 39; radius: 9
                opacity: root.busy ? .5 : 1
                color: actionBtn.modelData.action === "apply" ? Qt.alpha(Theme.accent, .23) : Theme.surface
                border.color: actionBtn.modelData.action === "apply" ? Theme.accent : Theme.borderaccent
                Text { anchors.centerIn: parent; text: actionBtn.modelData.text; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                MouseArea { anchors.fill: parent; enabled: !root.busy && root.drafts.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: root.run(actionBtn.modelData.action) }
            }
        }
    }
    Text { Layout.fillWidth: true; text: root.status; wrapMode: Text.WordWrap; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted }
    Text { Layout.fillWidth: true; text: "Apply affects the current session. Export saves ~/.config/rustiq/monitors.lua; your Hyprland config is never rewritten. You can also use nwg-displays."; wrapMode: Text.WordWrap; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 9; color: Theme.surface
        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            Icon {
                icon: "\ue8b8"
                font.pixelSize: 17
                color: Theme.accent
            }
            Text {
                text: "Open nwg-displays"
                font.family: Fonts.poppins.name
                font.pixelSize: 11
                color: Theme.foreground
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["nwg-displays"]) }
    }
}
