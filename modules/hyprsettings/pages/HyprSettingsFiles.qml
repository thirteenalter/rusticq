import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../../services"
import "../components"
import "../../../components/settings" as Suite

ColumnLayout {
    id: root
    required property var palette
    spacing: 12
    HyprSettingsLabel { palette: root.palette; text: "Read-only configuration browser"; font.bold: true }
    HyprSettingsLabel { palette: root.palette; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: palette.muted; font.pixelSize: 12; text: "Static includes are resolved without executing Lua. Dynamic Lua includes may not appear here. Use the setting controls to edit RusticQ-managed overrides safely." }
    HyprSettingsDropdown {
                colors: root.palette;
        id: files
        Layout.fillWidth: true
        model: Object.keys(HyprlandConfigService.state.files || {})
        onActivated: HyprlandConfigService.readFile(currentText)
    }
    HyprSettingsField { id: search; palette: root.palette; Layout.fillWidth: true; placeholderText: "Find in file…" }
    ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: 420
        clip: true
        TextArea {
            readOnly: true
            selectByMouse: true
            textFormat: TextEdit.RichText
            font.family: "Monospace"
            font.pixelSize: 12
            color: root.palette.foreground
            wrapMode: TextEdit.NoWrap
            text: {
                const q = search.text.toLowerCase();
                function escape(s) { return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }
                return "<pre>" + HyprlandConfigService.editorText.split("\n").map((line,i) => {
                    const muted = /^\s*(--|#)/.test(line);
                    const color = muted ? root.palette.muted : q && line.toLowerCase().includes(q) ? root.palette.accent : root.palette.foreground;
                    return '<span style="color:' + root.palette.muted + '">' + String(i+1).padStart(4," ") + '</span>  <span style="color:' + color + '">' + escape(line) + '</span>';
                }).join("\n") + "</pre>";
            }
            background: Rectangle { color: root.palette.group; radius: 10 }
        }
    }
    HyprSettingsButton { palette: root.palette; text: "Read selected file"; enabled: files.currentIndex >= 0 && !HyprlandConfigService.busy; onClicked: HyprlandConfigService.readFile(files.currentText) }
    RowLayout {
        HyprSettingsButton { palette: root.palette; text: "Edit managed settings JSON…"; enabled: HyprlandConfigService.editable && !HyprlandConfigService.busy; onClicked: { managed.text=JSON.stringify(HyprlandConfigService.draft,null,2); editManaged.open(); } }
        HyprSettingsButton { palette: root.palette; text: "Open file externally"; enabled: files.currentIndex>=0; onClicked: Qt.openUrlExternally("file://"+files.currentText) }
    }
    Dialog {
        palette:Suite.SettingsControlPalette {design:root.palette}
        id: editManaged
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(640,parent ? parent.width-40 : 640)
        height: Math.min(540,parent ? parent.height-40 : 540)
        title: "Edit RusticQ-managed configuration data"
        modal: true
        background: Rectangle { color: root.palette.background; radius: 12; border.width: 1; border.color: root.palette.line }
        contentItem: ColumnLayout {
            HyprSettingsLabel { palette: root.palette; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Stage schema-validated overrides as JSON. Review changes generates the native Lua/hyprlang diff and validates all values before writing."; font.pixelSize: 12 }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                TextArea { id: managed; selectByMouse: true; color: root.palette.foreground; font.family: "Monospace"; font.pixelSize: 12; wrapMode: TextEdit.WrapAnywhere; background: Rectangle { color: root.palette.group; radius: 8 } }
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                HyprSettingsButton { palette: root.palette; text: "Cancel"; onClicked: editManaged.close() }
                HyprSettingsButton { palette: root.palette; text: "Stage JSON"; primary: true; onClicked: if (HyprlandConfigService.stageJson(managed.text)) editManaged.close() }
            }
        }
    }
}
