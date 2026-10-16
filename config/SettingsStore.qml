pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Small persistent, non-secret UI settings. Never store API keys here.
Singleton {
    id: root
    property string accentName: "orange"
    // Explicit opt-in: keep original Gruvbox when Aether is unavailable.
    property string colorSource: "gruvbox"
    property string barMode: "separated"
    property string barPosition: "top"
    property bool showNotifications: true
    property bool showLauncher: true
    // App launcher geometry and density (persisted; monitor size is still clamped).
    property string launcherLayoutMode: "compact" // compact | clean-hover
    property int launcherWidth: 660
    property int launcherHeight: 605
    property int launcherIconSize: 30
    property int launcherRowHeight: 56
    property int launcherFavoriteColumns: 3
    function updateLauncherSize(key, value, persist) {
        const limits = {
            launcherWidth: [440, 1000], launcherHeight: [360, 850],
            launcherIconSize: [20, 64], launcherRowHeight: [50, 92],
            launcherFavoriteColumns: [2, 5]
        };
        if (!limits[key] || !Number.isFinite(value)) return;
        root[key] = Math.max(limits[key][0], Math.min(limits[key][1], Math.round(value)));
        if (persist !== false) save();
    }
    function resetLauncherSize() {
        launcherWidth = 660;
        launcherHeight = 605;
        launcherIconSize = 30;
        launcherRowHeight = 56;
        launcherFavoriteColumns = 3;
        save();
    }
    property bool showTaskView: true
    property bool desktopCalendar: false
    property bool desktopSystem: false
    property bool desktopClock: false
    property bool desktopMedia: false
    property bool desktopWeather: false
    property bool desktopConnectivity: false
    // Per-monitor widget positions in normalized available screen space (0..1).
    property var widgetPositions: ({})
    function widgetKey(kind, monitor) { return String(monitor || "default") + ":" + kind; }
    function widgetPosition(kind, monitor) { return widgetPositions[widgetKey(kind, monitor)] || null; }
    function setWidgetPosition(kind, monitor, x, y) {
        if (["clock", "calendar", "system", "media", "weather", "connectivity"].indexOf(kind) < 0) return;
        if (!Number.isFinite(x) || !Number.isFinite(y)) return;
        const copy = Object.assign({}, widgetPositions);
        copy[widgetKey(kind, monitor)] = {x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y))};
        widgetPositions = copy;
        save();
    }
    function resetWidgetPositions() { widgetPositions = ({}); save(); }
    property bool showDock: false
    property bool dockFiles: true
    property bool dockBrowser: true
    property bool dockSettings: true
    property bool dockTaskView: true
    property bool dockAI: true
    property bool dockRunningApps: false
    // User-controlled Quick Control card order, stored independently of layout modes.
    readonly property var defaultQuickOrder: ["wifi", "bluetooth", "battery", "system", "notifications"]
    property var quickControlOrder: ["wifi", "bluetooth", "battery", "system", "notifications"]
    function validQuickOrder(input) {
        if (!Array.isArray(input) || input.length !== defaultQuickOrder.length) return false;
        return input.every((v, i) => defaultQuickOrder.indexOf(v) >= 0 && input.indexOf(v) === i);
    }
    function moveQuickCard(kind, beforeIndex) {
        const order = quickControlOrder.slice();
        const from = order.indexOf(kind);
        const to = Math.max(0, Math.min(order.length - 1, Math.floor(beforeIndex)));
        if (from < 0 || from === to) return;
        order.splice(from, 1);
        order.splice(to, 0, kind);
        quickControlOrder = order;
        save();
    }
    function resetQuickOrder() { quickControlOrder = defaultQuickOrder.slice(); save(); }
    property bool dockAutoHide: true
    property bool showMenuBar: false // Optional RusticQ contextual menu; off by default
    // Edit, View and Share remain the default menu sections when enabled.
    property bool showMenuEdit: true
    property bool showMenuView: true
    property bool showMenuShare: true
    property bool showMenuFile: false
    property bool showMenuShell: false
    property bool showMenuTools: false
    // Clean Compact: optional detail labels only for the right-hand group.
    // Battery and volume values are always retained.
    property bool cleanRightDetails: true // RC2 migration compatibility
    // clean-compact labels: icons, details, or reveal all on group hover
    property string cleanRightMode: "details"
    // Per-mode edge margins. Empty means keep the original mode defaults.
    property var marginOverrides: ({})
    function marginFor(edge, fallback) {
        const mode = marginOverrides[barMode] || {};
        return typeof mode[edge] === "number" ? mode[edge] : fallback;
    }
    function setBarMargin(edge, value, persist) {
        if (["top", "bottom", "left", "right"].indexOf(edge) === -1) return;
        const all = Object.assign({}, marginOverrides);
        const current = Object.assign({}, all[barMode] || {});
        current[edge] = Math.max(0, Math.min(32, Math.round(value)));
        all[barMode] = current;
        marginOverrides = all; // replace object to notify QML bindings
        if (persist !== false) save();
    }
    function resetBarMargins() {
        const all = Object.assign({}, marginOverrides);
        delete all[barMode];
        marginOverrides = all;
        save();
    }
    // Manual icon spacing is independent for each bar mode and each side.
    // "before" and "after" are extra pixels on top of the side's base gap.
    readonly property var spacingModes: ["compact", "clean-compact", "separated", "professional", "simple"]
    readonly property var spacingLeftItems: ["arch", "launcher", "menu", "workspaces"]
    readonly property var spacingRightItems: ["weather", "time", "date", "bluetooth", "wifi", "battery", "audio", "task", "quickModes", "quickControl"]
    property var barSpacingOverrides: ({})
    function validSpacingItem(side, key) {
        return (side === "left" ? spacingLeftItems : side === "right" ? spacingRightItems : []).indexOf(key) !== -1;
    }
    function spacingGroup(side, fallback) {
        const sideSettings = (barSpacingOverrides[barMode] || {})[side] || {};
        return Number.isInteger(sideSettings.gap) ? sideSettings.gap : fallback;
    }
    function spacingIcon(side, key, edge) {
        if (!validSpacingItem(side, key) || ["before", "after"].indexOf(edge) === -1) return 0;
        const record = (((barSpacingOverrides[barMode] || {})[side] || {}).items || {})[key] || {};
        return Number.isInteger(record[edge]) ? record[edge] : 0;
    }
    function setGroupSpacing(side, value, persist) {
        if (["left", "right"].indexOf(side) < 0 || !Number.isFinite(value)) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        const group = Object.assign({}, mode[side] || {});
        group.gap = Math.max(0, Math.min(16, Math.round(value)));
        mode[side] = group; all[barMode] = mode; barSpacingOverrides = all;
        if (persist !== false) save();
    }
    function setIconSpacing(side, key, edge, value, persist) {
        if (!validSpacingItem(side, key) || ["before", "after"].indexOf(edge) < 0 || !Number.isFinite(value)) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        const group = Object.assign({}, mode[side] || {});
        const items = Object.assign({}, group.items || {});
        const item = Object.assign({}, items[key] || {});
        item[edge] = Math.max(0, Math.min(24, Math.round(value)));
        items[key] = item; group.items = items; mode[side] = group;
        all[barMode] = mode; barSpacingOverrides = all;
        if (persist !== false) save();
    }
    function resetIconSpacing(side, key) {
        if (!validSpacingItem(side, key)) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        const group = Object.assign({}, mode[side] || {});
        const items = Object.assign({}, group.items || {});
        delete items[key]; group.items = items; mode[side] = group;
        all[barMode] = mode; barSpacingOverrides = all; save();
    }
    function resetSideSpacing(side) {
        if (["left", "right"].indexOf(side) < 0) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        delete mode[side]; all[barMode] = mode; barSpacingOverrides = all; save();
    }
    function validateSpacingOverrides(raw) {
        const result = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return result;
        for (const mode of spacingModes) {
            const sourceMode = raw[mode];
            if (!sourceMode || typeof sourceMode !== "object" || Array.isArray(sourceMode)) continue;
            const parsedMode = {};
            for (const side of ["left", "right"]) {
                const source = sourceMode[side];
                if (!source || typeof source !== "object" || Array.isArray(source)) continue;
                const parsed = { items: {} };
                if (Number.isInteger(source.gap) && source.gap >= 0 && source.gap <= 16) parsed.gap = source.gap;
                const candidates = side === "left" ? spacingLeftItems : spacingRightItems;
                for (const key of candidates) {
                    const item = (source.items || {})[key];
                    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
                    const value = {};
                    for (const edge of ["before", "after"])
                        if (Number.isInteger(item[edge]) && item[edge] >= 0 && item[edge] <= 24) value[edge] = item[edge];
                    if (Object.keys(value).length > 0) parsed.items[key] = value;
                }
                parsedMode[side] = parsed;
            }
            result[mode] = parsedMode;
        }
        return result;
    }
    // Individual bar modules/icons (all enabled initially, safely migrates RC1).
    property bool showArch: true
    property bool showTime: true
    property bool showDate: true
    property bool showWifi: true
    property bool showBluetooth: true
    property bool showBattery: true
    property bool showAudio: true
    property bool showQuickControl: true
    property bool showWeather: true
    property bool showWorkspaces: true
    property bool showIndicators: true
    property bool showQuickModes: true
    property bool quickModesAutoHide: true
    property bool showKeepAwake: true
    property bool showSilent: true
    property bool showGamingMode: true
    property bool showNightMode: true
    property bool showMicMute: true
    property string aiProvider: "openai"
    property string aiModel: "gpt-4.1-mini"
    readonly property color accentColor: accentName === "green" ? "#b8bb26" :
        accentName === "blue" ? "#83a598" :
        accentName === "purple" ? "#d3869b" : "#d65d0e"

    FileView {
        id: settingsFile
        path: Qt.resolvedUrl("../user-settings.json")
        blockLoading: true
    }
    Component.onCompleted: {
        try {
            const data = JSON.parse(settingsFile.text());
            if (["aether", "gruvbox"].indexOf(data.colorSource) !== -1) colorSource = data.colorSource;
            if (["orange", "green", "blue", "purple"].indexOf(data.accentName) !== -1)
                accentName = data.accentName;
            if (["compact", "clean-compact", "separated", "professional", "simple"].indexOf(data.barMode) !== -1) barMode = data.barMode;
            if (["top", "bottom", "left", "right"].indexOf(data.barPosition) !== -1) barPosition = data.barPosition;
            if (["icons", "details", "hover"].indexOf(data.cleanRightMode) !== -1)
                cleanRightMode = data.cleanRightMode;
            else if (typeof data.cleanRightDetails === "boolean")
                cleanRightMode = data.cleanRightDetails ? "details" : "icons";
            if (data.marginOverrides && typeof data.marginOverrides === "object" && !Array.isArray(data.marginOverrides)) {
                const validated = {};
                for (const mode of ["compact", "clean-compact", "separated", "professional", "simple"]) {
                    const m = data.marginOverrides[mode];
                    if (!m || typeof m !== "object" || Array.isArray(m)) continue;
                    const values = {};
                    for (const edge of ["top", "bottom", "left", "right"])
                        if (Number.isInteger(m[edge]) && m[edge] >= 0 && m[edge] <= 32) values[edge] = m[edge];
                    validated[mode] = values;
                }
                marginOverrides = validated;
            }
            barSpacingOverrides = validateSpacingOverrides(data.barSpacingOverrides);
            if (["compact", "clean-hover"].indexOf(data.launcherLayoutMode) !== -1)
                launcherLayoutMode = data.launcherLayoutMode;
            for (const key of ["launcherWidth", "launcherHeight", "launcherIconSize", "launcherRowHeight", "launcherFavoriteColumns"])
                if (Number.isInteger(data[key])) updateLauncherSize(key, data[key], false);
            if (data.widgetPositions && typeof data.widgetPositions === "object" && !Array.isArray(data.widgetPositions)) {
                const validPositions = {};
                for (const key in data.widgetPositions) {
                    const v = data.widgetPositions[key];
                    if (/^[a-zA-Z0-9_.:-]{1,120}$/.test(key) && v && typeof v === "object" &&
                        Number.isFinite(v.x) && Number.isFinite(v.y) && v.x >= 0 && v.x <= 1 && v.y >= 0 && v.y <= 1)
                        validPositions[key] = { x:v.x, y:v.y };
                }
                widgetPositions = validPositions;
            }
            if (validQuickOrder(data.quickControlOrder)) quickControlOrder = data.quickControlOrder.slice();
            if (typeof data.showMenuBar === "boolean") showMenuBar = data.showMenuBar;
            for (const key of ["showMenuEdit", "showMenuView", "showMenuShare", "showMenuFile", "showMenuShell", "showMenuTools", "showNotifications", "showLauncher", "showTaskView", "desktopCalendar", "desktopSystem", "desktopClock", "desktopMedia", "desktopWeather", "desktopConnectivity", "showDock", "dockAutoHide", "dockFiles", "dockBrowser", "dockSettings", "dockTaskView", "dockAI", "dockRunningApps", "cleanRightDetails", "showArch", "showTime", "showDate", "showWifi", "showBluetooth", "showBattery", "showAudio", "showQuickControl"])
                if (typeof data[key] === "boolean") root[key] = data[key];
            if (typeof data.showWeather === "boolean") showWeather = data.showWeather;
            if (typeof data.showWorkspaces === "boolean") showWorkspaces = data.showWorkspaces;
            if (typeof data.showIndicators === "boolean") showIndicators = data.showIndicators;
            for (const key of ["showQuickModes", "quickModesAutoHide", "showKeepAwake", "showSilent", "showGamingMode", "showNightMode", "showMicMute"])
                if (typeof data[key] === "boolean") root[key] = data[key];
            if (["openai", "anthropic", "gemini"].indexOf(data.aiProvider) !== -1) aiProvider = data.aiProvider;
            if (typeof data.aiModel === "string" && data.aiModel.length > 0 && data.aiModel !== "llama3.2") aiModel = data.aiModel;
        } catch (e) {
            console.warn("Settings: defaults in use (user-settings.json): " + e);
        }
    }
    function save() {
        settingsFile.setText(JSON.stringify({
            accentName: accentName,
            colorSource: colorSource,
            barMode: barMode,
            barPosition: barPosition,
            showNotifications: showNotifications,
            showLauncher: showLauncher,
            launcherLayoutMode: launcherLayoutMode,
            launcherWidth: launcherWidth,
            launcherHeight: launcherHeight,
            launcherIconSize: launcherIconSize,
            launcherRowHeight: launcherRowHeight,
            launcherFavoriteColumns: launcherFavoriteColumns,
            showTaskView: showTaskView,
            desktopCalendar: desktopCalendar,
            desktopSystem: desktopSystem,
            desktopClock: desktopClock,
            desktopMedia: desktopMedia,
            desktopWeather: desktopWeather,
            desktopConnectivity: desktopConnectivity,
            widgetPositions: widgetPositions,
            showDock: showDock,
            dockFiles: dockFiles,
            dockBrowser: dockBrowser,
            dockSettings: dockSettings,
            dockTaskView: dockTaskView,
            dockAI: dockAI,
            dockRunningApps: dockRunningApps,
            quickControlOrder: quickControlOrder,
            dockAutoHide: dockAutoHide,
            showMenuBar: showMenuBar,
            showMenuEdit: showMenuEdit,
            showMenuView: showMenuView,
            showMenuShare: showMenuShare,
            showMenuFile: showMenuFile,
            showMenuShell: showMenuShell,
            showMenuTools: showMenuTools,
            cleanRightDetails: cleanRightMode === "details", // older clients
            cleanRightMode: cleanRightMode,
            marginOverrides: marginOverrides,
            barSpacingOverrides: barSpacingOverrides,
            showArch: showArch,
            showTime: showTime,
            showDate: showDate,
            showWifi: showWifi,
            showBluetooth: showBluetooth,
            showBattery: showBattery,
            showAudio: showAudio,
            showQuickControl: showQuickControl,
            showWeather: showWeather,
            showWorkspaces: showWorkspaces,
            showIndicators: showIndicators,
            showQuickModes: showQuickModes,
            quickModesAutoHide: quickModesAutoHide,
            showKeepAwake: showKeepAwake,
            showSilent: showSilent,
            showGamingMode: showGamingMode,
            showNightMode: showNightMode,
            showMicMute: showMicMute,
            aiProvider: aiProvider,
            aiModel: aiModel
        }, null, 2) + "\n");
    }
}
