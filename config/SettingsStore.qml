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
    property bool showTaskView: true
    property bool desktopCalendar: false
    property bool desktopSystem: false
    property bool desktopClock: false
    property bool desktopMedia: false
    property bool desktopWeather: false
    property bool desktopConnectivity: false
    property bool showDock: false
    property bool dockFiles: true
    property bool dockBrowser: true
    property bool dockSettings: true
    property bool dockTaskView: true
    property bool dockAI: true
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
            if (typeof data.showMenuBar === "boolean") showMenuBar = data.showMenuBar;
            for (const key of ["showMenuEdit", "showMenuView", "showMenuShare", "showMenuFile", "showMenuShell", "showMenuTools", "showNotifications", "showLauncher", "showTaskView", "desktopCalendar", "desktopSystem", "desktopClock", "desktopMedia", "desktopWeather", "desktopConnectivity", "showDock", "dockAutoHide", "dockFiles", "dockBrowser", "dockSettings", "dockTaskView", "dockAI", "cleanRightDetails", "showArch", "showTime", "showDate", "showWifi", "showBluetooth", "showBattery", "showAudio", "showQuickControl"])
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
            showTaskView: showTaskView,
            desktopCalendar: desktopCalendar,
            desktopSystem: desktopSystem,
            desktopClock: desktopClock,
            desktopMedia: desktopMedia,
            desktopWeather: desktopWeather,
            desktopConnectivity: desktopConnectivity,
            showDock: showDock,
            dockFiles: dockFiles,
            dockBrowser: dockBrowser,
            dockSettings: dockSettings,
            dockTaskView: dockTaskView,
            dockAI: dockAI,
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
