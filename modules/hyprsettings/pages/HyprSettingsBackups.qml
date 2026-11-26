import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import "../../../services"
import "../components"
import "../../../components/settings" as Suite

ColumnLayout {
    id: root
    required property var palette
    property string selected: ""
    function localPath(url) { const text=url.toString(); return text.indexOf("file://")===0 ? decodeURIComponent(text.slice(7)) : ""; }
    spacing: 12
    Component.onCompleted: HyprlandConfigService.history()
    HyprSettingsLabel { palette: root.palette; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Every Apply creates a private snapshot before writing. Restore verifies the current files still match that snapshot and validates Hyprland after restoration."; color: palette.muted; font.pixelSize: 12 }
    HyprSettingsButton { palette: root.palette; text: "Refresh history"; enabled: !HyprlandConfigService.busy; onClicked: HyprlandConfigService.history() }
    RowLayout {
        HyprSettingsButton { palette: root.palette; text: "Create snapshot"; enabled: HyprlandConfigService.editable && !HyprlandConfigService.busy; onClicked: HyprlandConfigService.snapshot() }
        HyprSettingsButton { palette: root.palette; text: "Export managed settings…"; enabled: HyprlandConfigService.editable && !HyprlandConfigService.busy; onClicked: exportFile.open() }
        HyprSettingsButton { palette: root.palette; text: "Import as draft…"; enabled: HyprlandConfigService.editable && !HyprlandConfigService.busy; onClicked: importFile.open() }
    }
    HyprSettingsButton { palette: root.palette; text: "Reset RusticQ-managed overrides…"; enabled: HyprlandConfigService.editable && !HyprlandConfigService.busy; onClicked: { HyprlandConfigService.resetManaged(); HyprlandConfigService.preview(); } }
    Repeater {
        model: HyprlandConfigService.snapshots
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            HyprSettingsLabel { palette: root.palette; text: new Date(modelData.time * 1000).toLocaleString() + " · " + modelData.state; Layout.fillWidth: true }
            HyprSettingsButton { palette: root.palette; text: "Restore…"; enabled: modelData.state === "applied" && !HyprlandConfigService.busy && !HyprlandConfigService.dirty; onClicked: { root.selected = modelData.id; HyprlandConfigService.previewRestore(modelData.id); } }
        }
    }
    HyprSettingsLabel { visible: !HyprlandConfigService.snapshots.length; palette: root.palette; text: "No studio snapshots yet."; color: palette.muted }
    HyprSettingsLabel { palette: root.palette; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Recovery: backups are in $XDG_STATE_HOME/rusticq/compositor-config/studio-history. Each manifest contains the original entrypoint and managed fragment. Restore those files from a terminal if Hyprland cannot start."; color: palette.muted; font.pixelSize: 12 }
    Dialog {
        palette:Suite.SettingsControlPalette {design:root.palette}
        id: confirm
        parent: Overlay.overlay
        anchors.centerIn: parent
        title: "Restore configuration?"
        width: Math.min(680,parent ? parent.width-40 : 680)
        height: Math.min(540,parent ? parent.height-40 : 540)
        modal: true
        background: Rectangle { color: root.palette.background;radius: 12;border.width: 1;border.color: root.palette.line }
        contentItem: ColumnLayout {
            HyprSettingsLabel { palette: root.palette;Layout.fillWidth: true;wrapMode: Text.WordWrap;font.pixelSize: 12;text: "Restore only RusticQ-managed settings. Current user configuration is preserved. The current managed state will be backed up before reloading." }
            ScrollView { Layout.fillWidth: true;Layout.fillHeight: true;clip: true
                TextArea { readOnly: true;selectByMouse: true;text: HyprlandConfigService.restoreDiff || "No changes.";font.family: "Monospace";font.pixelSize: 12;color: root.palette.foreground;wrapMode: TextEdit.WrapAnywhere;background: Rectangle { color: root.palette.group;radius: 8 } }
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                HyprSettingsButton { palette: root.palette;text: "Cancel";onClicked: confirm.close() }
                HyprSettingsButton { palette: root.palette;text: "Restore";primary: true;enabled: !!HyprlandConfigService.restoreToken && !HyprlandConfigService.busy;onClicked: { confirm.close();HyprlandConfigService.restore(root.selected); } }
            }
        }
    }
    Connections { target: HyprlandConfigService;function onRestoreTokenChanged() { if (HyprlandConfigService.restoreToken) confirm.open(); } }
    FileDialog {
        id: exportFile
        title: "Export RusticQ-managed Hyprland settings"
        fileMode: FileDialog.SaveFile
        nameFilters: ["RusticQ settings (*.json)"]
        defaultSuffix: "json"
        onAccepted: HyprlandConfigService.exportSettings(root.localPath(selectedFile))
    }
    FileDialog {
        id: importFile
        title: "Import RusticQ-managed settings as a draft"
        fileMode: FileDialog.OpenFile
        nameFilters: ["RusticQ settings (*.json)"]
        onAccepted: HyprlandConfigService.importSettings(root.localPath(selectedFile))
    }
}
