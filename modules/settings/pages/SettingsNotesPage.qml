import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

// Local, private notes/Kanban. No background poller, network, clipboard history.
ColumnLayout {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    width: parent ? parent.width : 680
    spacing: 13
    property var items: []
    property string inputText: ""
    property string statusMessage: ""
    property bool failed: false
    readonly property string helper: Quickshell.shellPath("scripts/rusticq-notes.py")
    function refresh() {
        if (!reader.running) reader.exec(["python3", helper, "list"]);
    }
    function modify(action, noteId, stage) {
        if (writer.running) return;
        failed = false;
        const cmd = ["python3", helper, action, noteId];
        if (action === "move") cmd.push(stage);
        writer.exec(cmd);
    }
    Process {
        id: reader
        stdout: StdioCollector { onStreamFinished: {
            try {
                const value = JSON.parse(this.text.trim());
                if (value.ok && value.result && Array.isArray(value.result.items)) root.items = value.result.items;
                else { root.failed = true; root.statusMessage = value.message || "Unable to load notes"; }
            } catch (error) { root.failed = true; root.statusMessage = "Invalid notes response: " + error; }
        } }
    }
    Process {
        id: writer
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text.trim());
                root.failed = result.ok !== true;
                root.statusMessage = result.ok ? "Note updated" : (result.message || "Note action failed");
                if (result.ok) {
                    Store.notesChanged();
                    root.inputText = "";
                    noteInput.text = "";
                }
            } catch (error) { root.failed = true; root.statusMessage = "Invalid note action response: " + error; }
        } }
        onExited: (code, reason) => root.refresh()
    }
    Connections {
        target: Store
        function onNotesChanged() { root.refresh(); }
    }
    Component.onCompleted: refresh()
    SettingsSection {
        heading: "Notes & Kanban"
        description: "A local, private task board. Notes are stored with restricted permissions in ~/.local/state/rusticq/notes.json. Nothing is synchronized or uploaded."
        symbol: "\ue873"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 42
                radius: root.settingsTheme.glassRadius("card", 10); color: root.settingsTheme.glassColor("card", root.settingsTheme.background)
                TextInput {
                    id: noteInput
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.settingsTheme.foreground; font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(12)
                    maximumLength: 260
                    text: root.inputText
                    onTextEdited: root.inputText = text
                    Keys.onReturnPressed: if (root.inputText.trim().length) root.modify("add", root.inputText.trim(), "")
                    GlassLabel {
                        visible: noteInput.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "New note or task…"
                        color: root.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(12)
                    }
                }
            }
            Rectangle {
                Layout.preferredWidth: 72; Layout.preferredHeight: 42; radius: 10
                color: root.settingsTheme.accent; opacity: writer.running ? .5 : 1
                GlassLabel { anchors.centerIn: parent; text: "Add"; color: root.settingsTheme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                MouseArea { anchors.fill: parent; enabled: !writer.running && root.inputText.trim().length > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.modify("add", root.inputText.trim(), "") }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: [
                    {key:"todo", label:"To Do"},
                    {key:"doing", label:"In Progress"},
                    {key:"done", label:"Done"}
                ]
                delegate: Rectangle {
                    id: lane
                    required property var modelData
                    readonly property var cards: root.items.filter(n => n.stage === modelData.key)
                    Layout.fillWidth: true
                    Layout.minimumWidth: 145
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredHeight: Math.max(110, cardsColumn.implicitHeight + 22)
                    radius: root.settingsTheme.glassRadius("card", 12); color: root.settingsTheme.glassColor("card", root.settingsTheme.background)
                    ColumnLayout {
                        id: cardsColumn
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                        anchors.margins: 10; spacing: 9
                        RowLayout { Layout.fillWidth: true
                            GlassLabel { Layout.fillWidth: true; text: lane.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); color: root.settingsTheme.foreground }
                            GlassLabel { text: String(lane.cards.length); font.pixelSize: Fonts.scale(12); color: root.settingsTheme.accent }
                        }
                        Repeater {
                            model: lane.cards
                            delegate: Rectangle {
                                id: task
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(66, taskContent.implicitHeight + 16)
                                radius: root.settingsTheme.glassRadius("card", 9); color: root.settingsTheme.glassColor("card", root.settingsTheme.surface)
                                ColumnLayout {
                                    id: taskContent
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                    anchors.margins: 8; spacing: 7
                                    GlassLabel { Layout.fillWidth: true; text: task.modelData.title
                                        wrapMode: Text.Wrap; maximumLineCount: 4
                                        font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12); color: root.settingsTheme.foreground }
                                    RowLayout { Layout.fillWidth: true; spacing: 6
                                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 22; radius: root.settingsTheme.glassRadius("card", 6); color: root.settingsTheme.glassColor("card", Qt.alpha(root.settingsTheme.accent, .17))
                                            GlassLabel { anchors.centerIn: parent; text: "Next →"; font.pixelSize: Fonts.scale(12); color: root.settingsTheme.accent }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.modify("toggle", task.modelData.id, "") }
                                        }
                                        Rectangle { Layout.preferredWidth: 25; Layout.preferredHeight: 22; radius: root.settingsTheme.glassRadius("card", 6); color: root.settingsTheme.glassColor("card", Qt.alpha(root.settingsTheme.foreground,.05))
                                            Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: root.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(13) }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.modify("delete", task.modelData.id, "") }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        GlassLabel {
            Layout.fillWidth: true; visible: root.statusMessage.length > 0
            text: root.statusMessage
            color: root.failed ? root.settingsTheme.error : root.settingsTheme.muted
            font.pixelSize: Fonts.scale(12); wrapMode: Text.WordWrap
        }
    }
}
