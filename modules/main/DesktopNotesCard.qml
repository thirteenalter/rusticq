import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

// Two views of the SAME private notes.json backend used by Settings → Notes.
// Not a second notes service or persistence layer. No background polling.
Rectangle {
    id: root
    property string boardKind: "notes" // notes or kanban
    property var entries: []
    property string draft: ""
    property string errorText: ""
    readonly property bool board: boardKind === "kanban"
    readonly property string helper: Quickshell.shellPath("scripts/rusticq-notes.py")
    implicitHeight: Math.max(132, body.implicitHeight + 28)
    radius: 17
    color: Theme.background
    border.color: Theme.borderaccent
    border.width: 1

    function refresh() {
        if (!readProcess.running) readProcess.exec(["python3", helper, "list"]);
    }
    function update(action, argument) {
        if (writeProcess.running) return;
        if (action === "add" && (!argument || !argument.trim())) return;
        if (["toggle", "delete"].indexOf(action) < 0 && action !== "add") return;
        errorText = "";
        writeProcess.exec(["python3", helper, action, argument]);
    }
    Process {
        id: readProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text);
                if (result.ok === true && result.result && Array.isArray(result.result.items)) {
                    root.entries = result.result.items;
                    root.errorText = "";
                } else root.errorText = result.message || "Cannot read notes";
            } catch (err) { root.errorText = "Notes read error: " + String(err); }
        } }
    }
    Process {
        id: writeProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text);
                if (result.ok === true) {
                    root.draft = "";
                    inputField.text = "";
                    Store.notesChanged();
                } else root.errorText = result.message || "Cannot update notes";
            } catch (err) { root.errorText = "Notes write error: " + String(err); }
        } }
        onExited: (code, status) => root.refresh()
    }
    Connections {
        target: Store
        function onNotesChanged() { root.refresh(); }
    }
    Component.onCompleted: refresh()
    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 13
        spacing: 9
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Icon { icon: root.board ? "\ue8f9" : "\ue873"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
            Text { Layout.fillWidth: true; text: root.board ? "Kanban" : "Sticky Notes"
                color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
            Text { text: String(root.entries.length); color: Theme.accent; font.pixelSize: Fonts.scale(10) }
            Rectangle {
                Layout.preferredWidth: 27; Layout.preferredHeight: 26
                radius: 7; color: Theme.surface
                Icon { anchors.centerIn: parent; icon: "\ue5d5"; color: Theme.muted; font.pixelSize: Fonts.scale(15) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
            // Reserve the rightmost region for the widget drag grip.
            Item { Layout.preferredWidth: 25; Layout.preferredHeight: 26 }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 8; color: Theme.surface
                TextInput {
                    id: inputField
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.draft
                    onTextEdited: root.draft = text
                    maximumLength: 260
                    color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                    Keys.onReturnPressed: root.update("add", root.draft.trim())
                    Text { visible: !parent.text.length; anchors.verticalCenter: parent.verticalCenter
                        text: root.board ? "Add task..." : "Write a note..."; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                }
            }
            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 34; radius: 8; color: Theme.accent
                Icon { anchors.centerIn: parent; icon: "\ue145"; color: Theme.background; font.pixelSize: Fonts.scale(17) }
                MouseArea { anchors.fill: parent; enabled: !writeProcess.running && root.draft.trim().length > 0
                    cursorShape: Qt.PointingHandCursor; onClicked: root.update("add", root.draft.trim()) }
            }
        }
        // Compact sticky-note list, scrolls internally on a busy desktop.
        ListView {
            visible: !root.board
            Layout.fillWidth: true
            Layout.preferredHeight: root.board ? 0 : Math.min(235, Math.max(45, contentHeight))
            clip: true
            spacing: 5
            model: root.board ? [] : root.entries.slice(0, 12)
            delegate: Rectangle {
                id: sticky
                required property var modelData
                width: ListView.view.width
                height: Math.max(39, label.implicitHeight + 16)
                radius: 9; color: Theme.surface
                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 7
                    Rectangle { Layout.preferredWidth: 5; Layout.fillHeight: true; radius: 2
                        color: sticky.modelData.stage === "done" ? Theme.muted : Theme.accent }
                    Text { id: label; Layout.fillWidth: true; text: sticky.modelData.title
                        maximumLineCount: 3; wrapMode: Text.Wrap; color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
                    Rectangle { Layout.preferredWidth: 24; Layout.preferredHeight: 24; color: "transparent"
                        Icon { anchors.centerIn: parent; icon: "\ue5ca"; color: Theme.accent; font.pixelSize: Fonts.scale(15) }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.update("toggle", sticky.modelData.id) }
                    }
                    Rectangle { Layout.preferredWidth: 22; Layout.preferredHeight: 24; color: "transparent"
                        Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: Theme.muted; font.pixelSize: Fonts.scale(15) }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.update("delete", sticky.modelData.id) }
                    }
                }
            }
        }
        // A three-lane Kanban view. Buttons reuse the existing stage cycle.
        RowLayout {
            visible: root.board
            Layout.fillWidth: true; spacing: 5
            Repeater {
                model: [
                    {id:"todo",name:"To Do"},
                    {id:"doing",name:"Doing"},
                    {id:"done",name:"Done"}
                ]
                delegate: Rectangle {
                    id: lane
                    required property var modelData
                    readonly property var tasks: root.entries.filter(n => n.stage === modelData.id).slice(0, 5)
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredHeight: Math.max(86, laneBody.implicitHeight + 14)
                    radius: 9; color: Theme.surface
                    ColumnLayout {
                        id: laneBody
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 6; spacing: 6
                        RowLayout { Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: lane.modelData.name
                                color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(9) }
                            Text { text: String(root.entries.filter(n => n.stage === lane.modelData.id).length)
                                color: Theme.accent; font.pixelSize: Fonts.scale(9) }
                        }
                        Repeater {
                            model: lane.tasks
                            delegate: Rectangle {
                                id: taskTile
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(51, taskLayout.implicitHeight + 12)
                                radius: 7; color: Theme.background
                                ColumnLayout {
                                    id: taskLayout
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                    anchors.margins: 5; spacing: 4
                                    Text { Layout.fillWidth: true; text: taskTile.modelData.title
                                        wrapMode: Text.Wrap; maximumLineCount: 3
                                        color: Theme.foreground; font.pixelSize: Fonts.scale(9) }
                                    RowLayout { Layout.fillWidth: true; spacing: 4
                                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 18; radius: 5; color: Qt.alpha(Theme.accent,.16)
                                            Text { anchors.centerIn: parent; text: "Next →"; color: Theme.accent; font.pixelSize: Fonts.scale(8) }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.update("toggle", taskTile.modelData.id) }
                                        }
                                        Rectangle { Layout.preferredWidth: 19; Layout.preferredHeight: 18; color: "transparent"
                                            Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: Theme.muted; font.pixelSize: Fonts.scale(12) }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.update("delete", taskTile.modelData.id) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Text { visible: !!root.errorText; Layout.fillWidth: true; text: root.errorText
            color: Theme.error; wrapMode: Text.WordWrap; font.pixelSize: Fonts.scale(9) }
    }
}
