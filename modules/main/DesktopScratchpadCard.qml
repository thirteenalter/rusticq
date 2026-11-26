import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

// Multiline text editor, independent from the Kanban task backend.
// DesktopWidgetWindow provides the monitor/workspace and keyboard-focusable
// bottom-layer surface; this component persists via the existing SettingsStore.
GlassSurface {
    Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
    surfaceRole: "primary"
    id: root
    property string monitorName: ""
    property int workspaceId: -1
    readonly property string documentKey: SettingsStore.workspaceNoteKey(monitorName, workspaceId)
    property bool loading: false
    property bool ready: false
    implicitHeight: 180
    radius: Theme.glassRadius("primary", 17)
    color: Theme.glassColor("primary", Theme.background)
    border.color: Theme.glassBorder("primary", Theme.borderaccent)
    border.width: Theme.glassBorderWidth("primary", 1)

    function saveCurrentNote() {
        if (!loading && workspaceId > 0 && editor.text !== SettingsStore.workspaceNote(monitorName, workspaceId))
            SettingsStore.setWorkspaceNote(monitorName, workspaceId, editor.text);
    }
    function loadCurrentNote() {
        loading = true;
        editor.text = workspaceId > 0 ? SettingsStore.workspaceNote(monitorName, workspaceId) : "";
        loading = false;
    }
    onDocumentKeyChanged: {
        if (!ready) return;
        // Flush the old workspace before replacing its editor text.
        saveTimer.stop();
        if (previousWorkspaceId > 0 && previousMonitorName.length && !loading)
            SettingsStore.setWorkspaceNote(previousMonitorName, previousWorkspaceId, editor.text);
        previousWorkspaceId = workspaceId;
        previousMonitorName = monitorName;
        loadCurrentNote();
    }
    property int previousWorkspaceId: -1
    property string previousMonitorName: ""
    Component.onCompleted: {
        ready = true;
        previousWorkspaceId = workspaceId;
        previousMonitorName = monitorName;
        loadCurrentNote();
    }
    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: root.saveCurrentNote()
    }
    ColumnLayout {
        objectName: "surfaceContent"
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Icon { icon: "\ue873"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
            GlassLabel { Layout.fillWidth: true; text: "Scratchpad · WS " + root.workspaceId; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            GlassLabel { text: editor.length + " chars"; color: Theme.contentMuted; font.pixelSize: Fonts.scale(9) }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.glassRadius("card", 9)
            color: Theme.glassColor("card", Theme.surface)
            Flickable {
                id: scroll
                anchors.fill: parent
                anchors.margins: Theme.controlPadding
                contentWidth: width
                contentHeight: Math.max(height, editor.implicitHeight)
                clip: true
                TextEdit {
                    id: editor
                    width: scroll.width
                    color: Theme.foreground
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(11)
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    activeFocusOnPress: true
                    textFormat: TextEdit.PlainText
                    onTextChanged: {
                        if (!root.loading && root.workspaceId > 0) saveTimer.restart();
                    }
                    onCursorRectangleChanged: scroll.ensureVisible(cursorRectangle)
                }
                function ensureVisible(rect) {
                    if (rect.y < contentY) contentY = rect.y;
                    else if (rect.y + rect.height > contentY + height)
                        contentY = rect.y + rect.height - height;
                }
                GlassLabel {
                    anchors.top: parent.top
                    visible: editor.text.length === 0 && !editor.activeFocus
                    text: "Write anything here...\n\nIdeas, quick thoughts, snippets.\nAutosaved for this workspace."
                    wrapMode: Text.WordWrap
                    color: Theme.contentMuted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(11)
                }
            }
        }
        GlassLabel {
            Layout.fillWidth: true
            text: "Autosaved locally · drag ↗ · resize ↘"
            color: Theme.contentMuted
            font.pixelSize: Fonts.scale(9)
        }
    }
}
