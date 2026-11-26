pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"

Singleton {
    id: root
    property bool started: false
    property bool pending: false
    property string payload: ""
    readonly property string owner: Date.now().toString(36) + "-" + Math.floor(Math.random() * 1000000000).toString(36)
    function initialize() { if (!started) { started = true; refresh(); } }
    function refresh() { if (started) debounce.restart(); }
    // Prepare exact namespace rules while closed. No backdrop window exists
    // until opening; spawning a capability probe midway through every entry
    // animation caused a late blur/opacity switch and visible hesitation.
    function requestData() {
        const flags={};
        for(const key of Object.keys(SettingsStore.surfaceMaterialOverrides)) {
            const p=SettingsStore.surfaceMaterialOverrides[key];
            if(p.inherit===false)flags[key]=p.glass && p.background && Theme.glassEnabled;
        }
        return {surfaceBlurFlags:flags,settingsPresentation:true, settingsBlur:SettingsMaterial.wantsBlur("rusticq"),
                hyprSettingsBlur:SettingsMaterial.wantsBlur("hyprland"),
                settingsRadius:SettingsMaterial.preferences("rusticq").radius,
                hyprSettingsRadius:SettingsMaterial.preferences("hyprland").radius,
                enabled:SettingsStore.glassmorphismEnabled,
                blur:SettingsStore.glassBlurEnabled, performance:SettingsStore.glassPerformanceMode,
                lowMemory:SettingsStore.lowMemoryShellMode, owner:root.owner,
                launcherBlur:SettingsStore.launcherGlassmorphismEnabled && SettingsStore.launcherMaterialMode!=="solid"
                    && !(["blur","dim-blur"].indexOf(LauncherStyle.backdrop(SettingsStore.launcherLayoutMode))>=0)
                    && (SettingsStore.launcherLayoutMode==="detached"
                        ? (SettingsStore.detachedLauncherInputGlassEnabled && SettingsStore.detachedLauncherInputBackgroundEnabled)
                            || (SettingsStore.detachedLauncherResultsGlassEnabled && SettingsStore.detachedLauncherResultsBackgroundEnabled)
                        : SettingsStore.launcherBackgroundEnabled),
                launcherBackdropBlur:["blur","dim-blur"].indexOf(LauncherStyle.backdrop(SettingsStore.launcherLayoutMode))>=0,
                barBlur:SettingsStore.barGlassEnabled && (SettingsStore.barBackgroundEnabled
                    || (SettingsStore.barMode === "separated" && SettingsStore.barSegmentBackgroundEnabled)
                    || SettingsStore.barModuleBackgroundEnabled)};
    }
    Timer {
        id: debounce
        interval: 180
        onTriggered: {
            if (request.running) { root.pending = true; return; }
            root.pending = false;
            root.payload = JSON.stringify(root.requestData());
            request.running = true;
        }
    }
    Process {
        id: request
        command: ["python3", "-B", Quickshell.shellPath("scripts/rusticq-glass.py"), "apply"]
        stdinEnabled: true
        onStarted: write(root.payload + "\n")
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    Store.glassBackend = data.backend || "unknown";
                    Store.glassBlurSupported = data.supported === true;
                    Store.glassBlurActive = data.active === true;
                    Store.settingsBlurActive=data.settingsActive===true;
                    Store.hyprSettingsBlurActive=data.hyprSettingsActive===true;
                    Store.launcherBlurActive = data.launcherActive === true || data.backdropActive === true;
                    Store.launcherBackdropBlurActive = data.backdropActive === true;
                    Store.glassBlurStrengthEditable = data.independentStrength === true;
                    Store.glassCompositorStatus = data.message || "Readable tinted fallback is active.";
                } catch (error) {
                    Store.glassBlurActive = false;
                    Store.settingsBlurActive=false;Store.hyprSettingsBlurActive=false;
                    Store.launcherBlurActive = false;
                    Store.launcherBackdropBlurActive = false;
                    Store.glassCompositorStatus = "Compositor status unavailable; readable tinted fallback is active.";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                Store.glassBlurActive = false;
                    Store.settingsBlurActive=false;Store.hyprSettingsBlurActive=false;
                Store.launcherBlurActive = false;
                Store.launcherBackdropBlurActive = false;
            }
            if (root.pending) debounce.restart();
        }
    }
    Connections {
        target: SettingsStore
        function onSurfaceMaterialOverridesChanged() { root.refresh(); }
        function onSettingsWindowAppearanceChanged() { root.refresh(); }
        function onGlassmorphismEnabledChanged() { root.refresh(); }
        function onGlassBlurEnabledChanged() { root.refresh(); }
        function onGlassPerformanceModeChanged() { root.refresh(); }
        function onLowMemoryShellModeChanged() { root.refresh(); }
        function onBarGlassEnabledChanged() { root.refresh(); }
        function onBarBackgroundEnabledChanged() { root.refresh(); }
        function onBarSegmentBackgroundEnabledChanged() { root.refresh(); }
        function onBarModuleBackgroundEnabledChanged() { root.refresh(); }
        function onBarModeChanged() { root.refresh(); }
        function onLauncherLayoutModeChanged() { root.refresh(); }
        function onLauncherBackdropModeChanged() { root.refresh(); }
        function onLauncherGlassmorphismEnabledChanged() { root.refresh(); }
        function onLauncherMaterialModeChanged() { root.refresh(); }
        function onLauncherBackgroundEnabledChanged() { root.refresh(); }
        function onDetachedLauncherInputGlassEnabledChanged() { root.refresh(); }
        function onDetachedLauncherResultsGlassEnabledChanged() { root.refresh(); }
        function onDetachedLauncherInputBackgroundEnabledChanged() { root.refresh(); }
        function onDetachedLauncherResultsBackgroundEnabledChanged() { root.refresh(); }
    }
    Connections {
        target: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? Hyprland : null
        function onRawEvent(event) { if (event.name === "configreloaded") root.refresh(); }
    }
    Component.onDestruction: if (started)
        Quickshell.execDetached(["python3", "-B", Quickshell.shellPath("scripts/rusticq-glass.py"), "disable", "--owner", root.owner])
}
