import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../services"

// One controller per launcher session. Every frontend shares these providers,
// ranking, usage and safe execution paths; no style creates another index.
Item {
    id: root
    signal launched()
    signal selectionMoved()
    property var applicationEntries: DesktopEntries.applications.values
    // Built-in application entry: discoverable without the :settings prefix,
    // and opens this shell's existing settings window on the launcher screen.
    readonly property var settingsEntry: ({
        id: "org.rusticq.Settings",
        name: "RusticQ Settings",
        genericName: "Pengaturan RusticQ",
        comment: "Appearance, Quick Control, networking, audio and system settings",
        icon: Quickshell.shellPath("assets/rusticq-app-icon.svg"),
        categories: ["Settings", "System"],
        keywords: ["settings rusticq", "rustiq", "preferences", "pengaturan", "konfigurasi"],
        execute: function() { Store.showSettings("home", Store.launcherScreen); }
    })
    readonly property var hyprSettingsEntry: ({
        id: "org.rusticq.HyprlandSettings",
        name: "RusticQ Hyprland Settings",
        genericName: "Hyprland Configuration Studio",
        comment: "Configure Hyprland windows, effects, input, rules and workspaces",
        icon: Quickshell.shellPath("assets/rusticq-hypr-settings.svg"),
        categories: ["Settings", "System"],
        keywords: ["hypr", "hyprland", "compositor", "blur", "gaps", "rounding", "pengaturan hyprland"],
        execute: function() { Store.openHyprSettings("overview", Store.launcherScreen); }
    })
    property var allApps: []
    property string category: "all"
    readonly property var favorites: allApps.filter(entry => AppUsage.stats(entry).pinned)
    readonly property var recent: allApps.filter(entry => AppUsage.stats(entry).last > 0)
        .sort((a,b) => AppUsage.stats(b).last-AppUsage.stats(a).last).slice(0,12)
    readonly property var recentCommands: AppUsage.recentCommands
    readonly property var categoryNames: ({Development:"Development",Network:"Internet",Office:"Office",Graphics:"Graphics",AudioVideo:"Media",Game:"Games",System:"System",Utility:"Utilities",Education:"Education"})
    function categoriesOf(entry) {
        const value=entry ? entry.categories : null;
        return typeof value === "string" ? value.split(";") : value && value.length !== undefined ? Array.from(value) : [];
    }
    readonly property var categories: {
        const available=new Set();
        for(const entry of allApps) for(const name of categoriesOf(entry)) if(categoryNames[name]) available.add(name);
        return [{key:"all",label:"All applications"},{key:"favorites",label:"Favorites"},{key:"recent",label:"Recent"}]
            .concat(Array.from(available).sort().map(name=>({key:name,label:categoryNames[name]})));
    }
    readonly property var displayedResults: {
        if (category === "favorites") return results.filter(entry=>AppUsage.stats(entry).pinned);
        if (category === "recent") return results.filter(entry=>AppUsage.stats(entry).last>0).sort((a,b)=>AppUsage.stats(b).last-AppUsage.stats(a).last);
        return category === "all" ? results : results.filter(entry=>categoriesOf(entry).indexOf(category)>=0);
    }
    property string presentation: "all"
    property bool catalogAll: false
    property int resultLimit: 0
    readonly property var rows: {
        let list=toolsMode ? toolRows : displayedResults;
        if(!toolsMode && query.trim()==="" && category==="all" && presentation==="fluent" && !catalogAll)
            list=favorites.length ? favorites : frequent.length ? frequent : list.slice(0,12);
        return resultLimit>0 ? list.slice(0,resultLimit) : list;
    }
    onRowsChanged: if(selectedIndex>=rows.length) selectedIndex=Math.max(0,rows.length-1)
    readonly property var selected: rows.length ? rows[Math.min(selectedIndex,rows.length-1)] : null
    onCategoryChanged: { selectedIndex=0;keyboardNavigation=false;selectionMoved(); }
    onApplicationEntriesChanged: rebuild()
    property int generation:0
    property int actionGeneration:0
    property string actionQuery:""
    function beginSession() { generation++;toolDismissTimer.stop();category="all";catalogAll=false;query="";selectedIndex=0;toolMessage="";toolError=false; }
    function togglePinned(entry) { if(entry && !toolsMode && !calculatorMode) AppUsage.togglePinned(entry); }
    function pinned(entry) { return entry ? AppUsage.stats(entry).pinned : false; }
    property real pointerX: NaN
    property real pointerY: NaN
    function pointerSelection(index,x,y) {
        const hadPosition=Number.isFinite(pointerX);
        const moved=hadPosition && Math.abs(pointerX-x)+Math.abs(pointerY-y)>2;
        pointerX=x;pointerY=y;
        if(!moved) return;
        keyboardNavigation=false;selectedIndex=index;
    }
    property string query: ""
    property var results: []
    property var frequent: []
    property bool showAll: false
    // Reuse the existing launcher for local tools; no independent search daemon.
    readonly property var providerMatch: /^:(emoji|settings|wallpaper|color|ocr|files|folders|windows|workspaces|notes)(?:\s+(.*))?$/i.exec(query.trim())
    readonly property bool toolsMode: providerMatch !== null
    readonly property string toolName: providerMatch ? providerMatch[1].toLowerCase() : ""
    readonly property string toolQuery: providerMatch ? (providerMatch[2] || "") : ""
    property var toolRows: []
    property string toolMessage: ""
    property bool toolError: false
    property string searchInflight: ""
    readonly property bool searchBusy: toolsMode && (providerUpdate.running || toolSearchTimer.running || toolSearchProcess.running)
    readonly property int selectionCount: rows.length
    function requestToolSearch() {
        if (!toolsMode) { toolSearchTimer.stop(); toolRows = []; return; }
        toolRows = [];
        toolMessage = "";
        toolSearchTimer.restart();
    }
    Timer { id: toolSearchTimer; interval: 170; repeat: false; onTriggered: {
        if (toolSearchProcess.running) return;
        root.searchInflight = root.toolName + "|" + root.toolQuery;
        toolSearchProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-launcher-tools.py"),
                                "search", root.toolName, root.toolQuery]);
    } }
    Process {
        id: toolSearchProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const response = JSON.parse(this.text);
                if (root.toolsMode && root.toolName === response.mode && root.toolQuery === response.query) {
                    root.toolRows = response.ok === true ? (response.items || []) : [];
                    root.selectedIndex = 0;
                    root.toolError = response.ok !== true;
                    root.toolMessage = response.ok === true ? "" : (response.message || "Search unavailable");
                }
            } catch (e) { if (root.toolsMode) { root.toolError = true; root.toolMessage = "Tool search failed: " + e; } }
        } }
        onExited: (code, status) => {
            if (root.toolsMode && root.searchInflight !== root.toolName + "|" + root.toolQuery)
                toolSearchTimer.restart();
        }
    }
    Process {
        id: toolRunProcess
        stdout: StdioCollector { onStreamFinished: {
            if(root.actionGeneration!==root.generation) return;
            try {
                const response = JSON.parse(this.text);
                root.toolError = response.ok !== true;
                root.toolMessage = response.message || (root.toolError ? "Action failed" : "Done");
                if (!root.toolError && root.query===root.actionQuery) toolDismissTimer.restart();
            } catch (e) { root.toolError = true; root.toolMessage = "Action failed: " + e; }
        } }
        onExited: (code, status) => {
            if (code !== 0 && !root.toolMessage.length) { root.toolError = true; root.toolMessage = "Tool exited with code " + code; }
        }
    }
    Timer { id: toolDismissTimer; interval: 850; repeat: false; onTriggered: if(root.actionGeneration===root.generation && root.query===root.actionQuery) root.launched() }
    function chooseTool(entry) {
        if (!entry || toolRunProcess.running) return;
        AppUsage.noteCommand(entry);
        if (entry.action === "settings") {
            Store.showSettings(entry.payload, Store.launcherScreen);
            launched();
            return;
        }
        if (entry.action === "file" || entry.action === "folder" ||
            entry.action === "window" || entry.action === "workspace") {
            // The actual open/focus operation runs independently after the layer closes.
            Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/rusticq-launcher-tools.py"),
                                     "execute", entry.action, entry.payload]);
            launched();
            return;
        }
        if (entry.action === "ocr" || entry.action === "color") {
            // Close the full-screen layer before capture/picker starts.
            // An independent process finishes even when this LazyLoader unloads.
            Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/rusticq-launcher-tools.py"),
                                     "execute-later", entry.action, entry.payload]);
            launched();
            return;
        }
        toolMessage = "Running " + entry.action + "…";
        actionGeneration=generation;
        actionQuery=query;
        toolError = false;
        toolRunProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-launcher-tools.py"),
                             "execute", entry.action, entry.payload]);
    }
    // Explicit calculator mode: `=2*(3+4)`; no arbitrary Python/JS evaluation.
    readonly property bool calculatorMode: query.trim().startsWith("=")
    property string calculatorResult: ""
    property string calculatorError: ""
    property string calculatorInFlight: ""
    function calculateLater() {
        calculatorResult = "";
        calculatorError = "";
        if (calculatorMode && query.trim().length > 1) calcDebounce.restart();
        else calcDebounce.stop();
    }
    Timer {
        id: calcDebounce
        interval: 150
        repeat: false
        onTriggered: {
            if (calcProcess.running) return;
            root.calculatorInFlight = root.query.trim().substring(1);
            calcProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-calc.py"), root.calculatorInFlight]);
        }
    }
    Process {
        id: calcProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const response = JSON.parse(this.text);
                if (root.calculatorMode && root.query.trim().substring(1) === response.expression) {
                    root.calculatorResult = response.ok === true ? String(response.result) : "";
                    root.calculatorError = response.ok === true ? "" : (response.error || "Invalid expression");
                }
            } catch (e) {
                if (root.calculatorMode) root.calculatorError = "Calculator unavailable";
            }
        } }
        onExited: (code, status) => {
            if (root.calculatorMode && root.query.trim().substring(1) !== root.calculatorInFlight)
                calcDebounce.restart();
        }
    }
    function copyResult() {
        if (!calculatorMode || calculatorResult.length === 0) return;
        Quickshell.execDetached(["wl-copy", "--", calculatorResult]);
    }
    property int selectedIndex: 0
    property bool keyboardNavigation: false
    onResultsChanged: selectedIndex = 0
    function moveSelection(delta) {
        keyboardNavigation = true;
        if (!selectionCount) return;
        selectedIndex = Math.max(0, Math.min(selectionCount - 1, selectedIndex + delta));
        selectionMoved();
    }
    function launchSelected() {
        if (calculatorMode) { copyResult(); return; }
        if (toolsMode) { if (toolRows.length) chooseTool(toolRows[Math.min(selectedIndex, toolRows.length-1)]); return; }
        if (rows.length) launch(rows[Math.min(selectedIndex, rows.length - 1)]);
    }
    function launch(entry) {
        try {
            entry.execute();
            AppUsage.noteLaunch(entry);
            launched();
        } catch (e) { console.warn("Launcher failed to start " + textOf(entry.name) + ": " + e); }
    }

    function rebuild() {
        const entries = applicationEntries.filter(entry => entry && [settingsEntry.id, hyprSettingsEntry.id].indexOf(String(entry.id || "").replace(/\.desktop$/, "")) < 0).concat([settingsEntry, hyprSettingsEntry]);
        const visibleEntries = entries.filter(entry => entry && !entry.noDisplay);
        if (allApps.length!==visibleEntries.length || allApps.some((entry,index)=>entry!==visibleEntries[index]))
            allApps = visibleEntries;
        const found = [];
        const searching = query.trim().length > 0;
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            if (!entry || entry.noDisplay) continue;
            const relevance = searching ? searchScore(entry, query.trim().toLowerCase()) : 1;
            if (relevance > 0) found.push({entry: entry, score: relevance});
        }
        found.sort((a, b) => {
            if (searching && a.score !== b.score) return b.score - a.score;
            const sa = AppUsage.stats(a.entry), sb = AppUsage.stats(b.entry);
            if (sa.pinned !== sb.pinned) return sa.pinned ? -1 : 1;
            if (sa.count !== sb.count) return sb.count - sa.count;
            if (sa.last !== sb.last) return sb.last - sa.last;
            return textOf(a.entry.name).localeCompare(textOf(b.entry.name));
        });
        const ordered = found.map(item => item.entry);
        frequent = ordered.filter(e => {
            const st = AppUsage.stats(e);
            return st.pinned || st.count > 0;
        }).slice(0, 6);
        results = ordered;
    }
    // Let providerMode/toolQuery bindings settle before arming their debounce.
    // This timer belongs to the controller and cannot outlive its session.
    Timer { id: providerUpdate; interval:0;onTriggered:{root.calculateLater();root.requestToolSearch();} }
    onQueryChanged: { toolDismissTimer.stop();selectedIndex = 0; keyboardNavigation = false; rebuild(); providerUpdate.restart(); }
    Connections {
        target: AppUsage
        function onUsageChanged() { root.rebuild(); }
    }
    Component.onCompleted: rebuild()
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.rebuild(); }
    }

    property var unavailableIcons: ({})
    function markIconUnavailable(source) {
        if (!source || unavailableIcons[source]) return;
        const failed=Object.assign({},unavailableIcons);failed[source]=true;unavailableIcons=failed;
    }
    function iconSource(entry) {
        const icon = textOf(entry.icon);
        const path=icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true);
        return unavailableIcons[path] ? "" : path;
    }
    function textOf(value) {
        return value === undefined || value === null ? "" : String(value);
    }
    // Bounded typo tolerance: only names/words, no extra subprocess or indexer.
    function editDistance2(a, b) {
        if (!a || !b || Math.abs(a.length - b.length) > 2) return 3;
        if (a === b) return 0;
        let previous = [];
        for (let j = 0; j <= b.length; j++) previous.push(j);
        for (let i = 1; i <= a.length; i++) {
            const row = [i];
            let lowest = row[0];
            for (let j = 1; j <= b.length; j++) {
                const cost = a.charAt(i-1) === b.charAt(j-1) ? 0 : 1;
                const value = Math.min(row[j-1]+1, previous[j]+1, previous[j-1]+cost);
                row.push(value);
                if (value < lowest) lowest = value;
            }
            if (lowest > 2) return 3;
            previous = row;
        }
        return previous[b.length];
    }
    function searchScore(entry, text) {
        const q = text.trim().toLowerCase();
        if (!q) return 1;
        if (q.startsWith("=") || q.startsWith(":")) return 0;
        const name = textOf(entry.name).toLowerCase();
        const generic = textOf(entry.genericName).toLowerCase();
        const comment = textOf(entry.comment).toLowerCase();
        const appId = textOf(entry.id).toLowerCase();
        const keywords = Array.isArray(entry.keywords) ? entry.keywords.join(" ").toLowerCase() : "";
        if (name === q) return 150;
        if (name.startsWith(q)) return 140;
        if (name.split(/[\s\-_.,\/]+/).some(token => token.startsWith(q))) return 110;
        if (name.includes(q)) return 90;
        if (appId.startsWith(q)) return 80;
        if (generic.includes(q) || keywords.includes(q)) return 65;
        if (comment.includes(q) || appId.includes(q)) return 40;
        if (q.length >= 4 && q.length <= 24) {
            const words = name.split(/[\s\-_.,\/]+/).filter(token => token.length >= 3).slice(0, 8);
            let best = 3;
            for (const word of words) best = Math.min(best, editDistance2(word.slice(0, 24), q));
            if (best <= 2) return 38 - best * 8;
        }
        return 0;
    }

}
