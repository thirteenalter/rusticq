pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root
    property var state: ({info:{}, options:[], data:{options:{},records:{}}, categories:[], collections:{}, collectionSupport:{}, presets:{}, files:{}})
    property var draft: ({options:{}, records:{}})
    property string revision: ""
    property string operation: ""
    property string message: ""
    property bool failed: false
    property bool initialized: false
    property bool externalChange: false
    property string diff: ""
    property string previewToken: ""
    property var frozen: ({})
    property var snapshots: []
    property string editorText: ""
    property string editorPath: ""
    property string restoreToken: ""
    property string restoreDiff: ""
    property string restoreSnapshot: ""
    readonly property bool busy: request.running
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(state.data)
    readonly property bool editable: state.info.editable === true
    readonly property string helper: Quickshell.shellPath("scripts/rusticq-compositor-config.py")
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function initialize() { if (!initialized && !busy) refresh(); }
    function run(action, extra) {
        if (busy) return;
        operation = action; failed = false; message = "";
        request.exec(["python3", helper, "studio-" + action].concat(extra || []));
        timeout.restart();
    }
    function refresh() { run("status"); }
    function payload() { return {options:draft.options, records:draft.records, revision:revision}; }
    function changed() { previewToken = ""; diff = ""; message = ""; }
    function setOption(key, value) {
        const next = clone(draft); next.options[key] = value; draft = next; changed();
    }
    function value(key) {
        if (Object.prototype.hasOwnProperty.call(draft.options, key)) return draft.options[key];
        const spec = state.options.find(o => o.id === key);
        return spec ? spec.effective : null;
    }
    function resetOption(key) {
        const spec = state.options.find(o => o.id === key);
        if (spec && spec.defaultKnown) setOption(key, spec.default);
        else removeOverride(key);
    }
    function removeOverride(key) {
        const next = clone(draft); delete next.options[key]; draft = next; changed();
    }
    function setRecords(kind, rows) {
        const next = clone(draft); next.records[kind] = clone(rows); draft = next; changed();
    }
    function discard() {
        draft = clone(state.data); changed();
        if (externalChange) { initialized = false; refresh(); }
    }
    function preset(name) {
        const values = state.presets[name];
        if (!values) return;
        const next = clone(draft);
        state.options.forEach(o => { if (o.supported && Object.prototype.hasOwnProperty.call(values,o.id)) next.options[o.id] = values[o.id]; });
        draft = next; changed();
    }
    function preview() { frozen = clone(payload()); run("preview", ["--values", JSON.stringify(frozen)]); }
    function apply() { if (previewToken && !externalChange) run("apply", ["--values", JSON.stringify(frozen), "--token", previewToken]); }
    function history() { run("history"); }
    function previewRestore(snapshot) { restoreToken="";restoreSnapshot=snapshot;run("restore-preview",["--snapshot",snapshot]); }
    function restore(snapshot) { run("restore", ["--snapshot", snapshot, "--token",restoreToken]); }
    function readFile(path) { run("read", ["--path", path]); }
    function reload() { run("reload"); }
    function snapshot() { run("snapshot"); }
    function savePreset(name) { run("preset", ["--name", name, "--values", JSON.stringify(payload())]); }
    function importSettings(path) { run("import", ["--path", path]); }
    function exportSettings(path) { run("export", ["--path", path, "--values", JSON.stringify(payload())]); }
    function resetManaged() { draft = {options:{},records:{}}; changed(); }
    function stageJson(text) {
        try {
            const data=JSON.parse(text);
            if (!data || !data.options || !data.records || typeof data.options !== "object" || typeof data.records !== "object"
                || Array.isArray(data.options) || Array.isArray(data.records) || Object.keys(data).some(k=>["options","records"].indexOf(k)<0)) throw new Error("Expected options and records objects");
            draft=clone(data); changed(); return true;
        } catch (error) { failed=true; message="Invalid managed settings JSON: " + error; return false; }
    }
    // No polling: watch the detected entrypoint and statically resolved includes.
    property Instantiator configWatches: Instantiator {
        model: Object.keys(root.state.files || {})
        delegate: FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            onFileChanged: {
                if (root.operation === "apply" || root.operation === "restore") return;
                root.externalChange = true;
                root.previewToken = "";
                root.restoreToken = "";
                root.message = "Configuration changed outside the studio. Revert drafts and refresh before applying.";
            }
        }
    }
    property Process request: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                timeout.stop();
                try {
                    const response = JSON.parse(text);
                    root.failed = response.ok !== true;
                    root.message = response.message || "";
                    if (root.failed) return;
                    if (root.operation === "status") {
                        const keepDraft = root.initialized && root.dirty;
                        root.state = response;
                        if (!keepDraft) { root.draft = root.clone(response.data); root.revision = response.revision; root.externalChange = false; }
                        root.initialized = true;
                    } else if (root.operation === "preview") {
                        root.diff = response.diff; root.previewToken = response.token;
                    } else if (root.operation === "history") root.snapshots = response.snapshots;
                    else if (root.operation === "restore-preview") { root.restoreDiff=response.diff;root.restoreToken=response.token; }
                    else if (root.operation === "read") { root.editorText = response.text; root.editorPath = response.path; }
                    else if (root.operation === "preset") root.state = Object.assign({},root.state,{presets:Object.assign({},root.state.presets,response.presets)});
                    else if (root.operation === "import") { root.draft = response.data; root.changed(); root.message = response.message; }
                    else if (root.operation === "snapshot") Qt.callLater(root.history);
                    else if (root.operation === "reload") {
                        root.previewToken=""; root.diff="";
                        Qt.callLater(root.refresh);
                    } else if (["apply", "restore"].indexOf(root.operation) >= 0) {
                        root.restoreToken="";
                        root.initialized = false; root.changed();
                        Qt.callLater(root.refresh);
                    }
                } catch (error) { root.failed = true; root.message = "The configuration backend returned an invalid response."; }
            }
        }
        stderr: StdioCollector { /* Never echo config values or commands to shell logs. */ }
        onExited: (code, status) => {
            timeout.stop();
            if (code !== 0 && !root.message) { root.failed = true; root.message = "Configuration backend failed (exit " + code + ")."; }
        }
    }
    property Timer timeout: Timer {
        interval: 110000
        onTriggered: { request.running = false; root.failed = true; root.message = "Hyprland did not respond in time. No new operation was started."; }
    }
}
