import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../../services"
import "../components"
import "../previews"

ColumnLayout {
    id: root
    required property var palette
    required property string kind
    objectName: "hypr-records-" + kind
    property int editing: -1
    property bool adding: false
    property var fields: ({})
    readonly property var schema: HyprlandConfigService.state.collections[kind] || []
    readonly property var rows: HyprlandConfigService.draft.records[kind] || []
    readonly property bool supported: HyprlandConfigService.state.collectionSupport[kind] === true
    spacing: 10
    onKindChanged: { adding = false; editing = -1; }
    function begin(index) {
        editing = index;
        const next = {};
        schema.forEach(f => next[f.key] = f.type === "choice" ? f.default[0] : f.default);
        fields = index >= 0 ? HyprlandConfigService.clone(rows[index]) : next;
        adding = true;
    }
    function setField(key, value) { fields = Object.assign({}, fields, {[key]:value}); }
    function save() {
        const next = HyprlandConfigService.clone(rows);
        if (editing >= 0) next[editing] = fields; else next.push(fields);
        HyprlandConfigService.setRecords(kind, next);
        adding = false; editing = -1;
    }
    function remove(index) { const next = rows.slice(); next.splice(index, 1); HyprlandConfigService.setRecords(kind, next); }
    function move(index, delta) {
        const next = rows.slice(); const other = index + delta;
        if (other < 0 || other >= next.length) return;
        const item = next.splice(index,1)[0]; next.splice(other,0,item); HyprlandConfigService.setRecords(kind,next);
    }
    RowLayout {
        Layout.fillWidth: true
        HyprSettingsLabel { palette: root.palette; text: "RusticQ-managed entries"; font.bold: true; Layout.fillWidth: true }
        HyprSettingsButton { palette: root.palette; text: "Add…"; enabled: root.supported && !HyprlandConfigService.busy; onClicked: root.begin(-1) }
    }
    HyprSettingsLabel {
        palette: root.palette; Layout.fillWidth: true; wrapMode: Text.WordWrap
        color: palette.muted; font.pixelSize: 12
        text: !root.supported ? "This record schema is unavailable for the detected format/version. Existing configuration remains available in Configuration Editor."
            : root.kind === "environment" ? "Requires a new session. Values are not imported from the process environment. Keep credentials in a credential manager. With uwsm, manage session variables in uwsm instead."
            : root.kind === "autostart" ? "Startup commands execute on a future session; commands marked to run on each reload execute when you Apply. Review them carefully."
            : "Existing user entries stay in their original files. These entries are appended as RusticQ-managed overrides; review Configuration Editor for the complete configuration."
    }
    HyprSettingsLabel { visible: !root.rows.length && !root.adding; palette: root.palette; text: "No RusticQ-managed entries yet."; color: palette.muted }
    Repeater {
        model: root.rows
        delegate: RowLayout {
            id: record
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 6
            HyprSettingsCheckBox {
                colors: root.palette;
                checked: record.modelData.enabled !== false
                enabled: root.supported
                Accessible.name: "Enable entry " + (record.index + 1)
                onToggled: {
                    const next = HyprlandConfigService.clone(root.rows); next[record.index].enabled = checked;
                    HyprlandConfigService.setRecords(root.kind,next);
                }
            }
            HyprSettingsLabel {
                palette: root.palette; Layout.fillWidth: true
                text: Object.keys(record.modelData).filter(k => record.modelData[k] !== "" && k !== "value" && k !== "enabled").map(k => k + ": " + record.modelData[k]).join(" · ")
                font.pixelSize: 12
            }
            HyprSettingsButton { palette: root.palette; text: "↑"; enabled: record.index > 0; Accessible.name: "Move entry up"; onClicked: root.move(record.index,-1) }
            HyprSettingsButton { palette: root.palette; text: "↓"; enabled: record.index < root.rows.length - 1; Accessible.name: "Move entry down"; onClicked: root.move(record.index,1) }
            HyprSettingsButton { palette: root.palette; text: "Edit"; enabled: root.supported; onClicked: root.begin(record.index) }
            HyprSettingsButton { palette: root.palette; text: "−"; enabled: root.supported; Accessible.name: "Remove entry"; onClicked: root.remove(record.index) }
        }
    }
    Rectangle {
        visible: root.adding
        Layout.fillWidth: true
        implicitHeight: form.implicitHeight + 24
        color: root.palette.group
        radius: 12
        ColumnLayout {
            id: form
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 12
            spacing: 8
            HyprSettingsDropdown {
                colors: root.palette;
                visible: root.kind === "window-rules"
                Layout.fillWidth: true
                model: ["Pick a running window…"].concat((HyprlandConfigService.state.clients || []).map(c => c.class + " · " + c.title))
                onActivated: {
                    const c = HyprlandConfigService.state.clients[currentIndex - 1];
                    if (c) { root.setField("class", "^(" + c.class.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")$"); root.setField("title", ""); }
                }
            }
            HyprSettingsDropdown {
                colors: root.palette;
                visible: root.kind === "devices"
                Layout.fillWidth: true
                readonly property var devices: {
                    const d=HyprlandConfigService.state.devices || {};
                    return Object.keys(d).reduce((all,k)=>all.concat(Array.isArray(d[k]) ? d[k] : []),[]).filter(device=>device.name);
                }
                model: ["Pick a connected device…"].concat(devices.map(d=>d.name))
                onActivated: if (currentIndex > 0) root.setField("name",devices[currentIndex-1].name)
            }
            HyprSettingsDropdown {
                colors: root.palette;
                visible: root.kind === "layer-rules"
                Layout.fillWidth: true
                readonly property var namespaces: {
                    const names=[];
                    function visit(v) {
                        if (!v || typeof v !== "object") return;
                        if (v.namespace && names.indexOf(v.namespace)<0) names.push(v.namespace);
                        Object.keys(v).forEach(k=> { if(typeof v[k]==="object") visit(v[k]); });
                    }
                    visit(HyprlandConfigService.state.layers);return names;
                }
                model: ["Pick a layer namespace…"].concat(namespaces)
                onActivated: if (currentIndex > 0) root.setField("namespace",namespaces[currentIndex-1])
            }
            HyprSettingsBezierEditor {
                visible: root.kind === "animations"
                Layout.fillWidth: true
                palette: root.palette
                previewKind: String(root.fields.leaf || "windows")
                previewSpeed: Number(root.fields.speed || 4)
                previewEnabled: root.fields.enabled !== false && HyprlandConfigService.value("animations:enabled") !== false
                x1: Number(root.fields.x1 || 0); y1: Number(root.fields.y1 || 0)
                x2: Number(root.fields.x2 || 0); y2: Number(root.fields.y2 || 0)
                onEdited: (a,b,c,d) => { root.setField("x1",a.toFixed(3)); root.setField("y1",b.toFixed(3)); root.setField("x2",c.toFixed(3)); root.setField("y2",d.toFixed(3)); }
            }
            Repeater {
                model: root.schema
                delegate: RowLayout {
                    id: fieldRow
                    required property var modelData
                    Layout.fillWidth: true
                    HyprSettingsLabel { palette: root.palette; text: fieldRow.modelData.label; Layout.fillWidth: true; font.pixelSize: 12 }
                    Loader {
                        Layout.preferredWidth: 230
                        sourceComponent: fieldRow.modelData.type === "bool" ? booleanField : fieldRow.modelData.type === "choice" ? choiceField : textField
                        Component { id: textField; HyprSettingsField { objectName: "hypr-record-field-" + fieldRow.modelData.key; palette: root.palette; text: String(root.fields[fieldRow.modelData.key] || ""); Accessible.name: fieldRow.modelData.label; onTextEdited: root.setField(fieldRow.modelData.key,text) } }
                        Component { id: booleanField; HyprSettingsCheckBox {
                colors: root.palette; checked: root.fields[fieldRow.modelData.key] === true; Accessible.name: fieldRow.modelData.label; onToggled: root.setField(fieldRow.modelData.key,checked) } }
                        Component { id: choiceField; HyprSettingsDropdown {
                colors: root.palette; model: fieldRow.modelData.default; currentIndex: Math.max(0,model.indexOf(root.fields[fieldRow.modelData.key])); Accessible.name: fieldRow.modelData.label; onActivated: root.setField(fieldRow.modelData.key,currentText) } }
                    }
                }
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                HyprSettingsButton { palette: root.palette; text: "Cancel"; onClicked: root.adding = false }
                HyprSettingsButton { objectName: "hypr-record-save"; palette: root.palette; text: "Save draft"; primary: true; onClicked: root.save() }
            }
        }
    }
}
