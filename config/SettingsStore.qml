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
