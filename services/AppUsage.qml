pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var usage: ({})
    // Session-only action history: never write provider payloads or note/file
    // contents into the application's persistent usage JSON.
    property var recentCommands: []
    function noteCommand(entry) {
        if (!entry || typeof entry.action!=="string" || typeof entry.payload!=="string") return;
        if (entry.payload.length>4096) return;
        if (["settings","file","folder","window","workspace","ocr","color"].indexOf(entry.action)<0) return;
        const item={label:String(entry.label || entry.action).slice(0,120),action:entry.action,payload:entry.payload,icon:String(entry.icon || "›")};
        recentCommands=[item].concat(recentCommands.filter(old=>old.action!==item.action || old.payload!==item.payload)).slice(0,8);
    }
    FileView {
        id: usageFile
        path: Qt.resolvedUrl("../app-usage.json")
        blockLoading: true
    }
    Component.onCompleted: {
        try {
            const data = JSON.parse(usageFile.text());
            if (data && typeof data === "object" && !Array.isArray(data)) {
                const safe = {};
                for (const key in data) {
                    const item = data[key];
                    if (key.length <= 256 && item && Number.isInteger(item.count) && item.count >= 0 && item.count <= 1000000)
                        safe[key] = {count:item.count, last:typeof item.last === "number" ? item.last : 0, pinned:item.pinned === true};
                }
                usage = safe;
            }
        } catch (e) {} // No usage file on first launch.
    }
    function keyOf(entry) { return String(entry.id || entry.name || ""); }
    function stats(entry) { return usage[keyOf(entry)] || {count:0, last:0, pinned:false}; }
    function noteLaunch(entry) {
        const key = keyOf(entry);
        if (!key || key.length > 256) return;
        const all = Object.assign({}, usage);
        const old = all[key] || {count:0, last:0, pinned:false};
        all[key] = {count:Math.min(1000000, old.count + 1),last:Date.now(),pinned:old.pinned === true};
        usage = all;
        persist();
    }
    function togglePinned(entry) {
        const key = keyOf(entry);
        if (!key || key.length > 256) return;
        const all = Object.assign({}, usage);
        const old = all[key] || {count:0,last:0,pinned:false};
        all[key] = {count:old.count,last:old.last,pinned:!old.pinned};
        usage = all;
        persist();
    }
    function persist() { usageFile.setText(JSON.stringify(usage, null, 2) + "\n"); }
}
