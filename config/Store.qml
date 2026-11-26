pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    signal barPopupOpened(var owner)
    // Session capability state; persistent preferences belong to SettingsStore.
    property string glassBackend: "unknown"
    property bool glassBlurSupported: false
    property bool settingsBlurActive: false
    property bool hyprSettingsBlurActive: false
    property bool glassBlurActive: false
    property bool glassBlurStrengthEditable: false
    property string glassCompositorStatus: "Backdrop blur has not been checked; using the readable tinted fallback."
    // Raised by the IPC dispatcher; each per-monitor bar consumes only its own actions.
    signal shortcutBarRequested(string kind, string screenName)
    // One transient OSD shared by all monitors. No new notification daemon.
    signal osdControlRequested(string action)
    property bool osdVisible: false
    property string osdKind: "volume"
    property string osdLabel: ""
    property int osdPercent: 0
    property bool osdHasLevel: true
    property bool osdMuted: false
    // Keyboard is a discrete stage indicator, not an approximate percentage.
    property int osdStage: 0
    property int osdStages: 3
    property var osdScreen: null
    function showOsd(kind, percent, label, hasLevel, muted, screen, stage, stages) {
        if (!SettingsStore.osdEnabled) return;
        if (["volume", "microphone", "brightness", "keyboard", "touchpad", "error"].indexOf(kind) < 0) return;
        osdKind = kind;
        osdPercent = Math.max(0, Math.min(100, Math.round(Number(percent) || 0)));
        osdLabel = String(label || "").slice(0, 110);
        osdHasLevel = hasLevel === true;
        osdMuted = muted === true;
        osdStage = Math.max(0, Math.round(Number(stage) || 0));
        osdStages = Math.max(1, Math.min(3, Math.round(Number(stages) || 3)));
        osdScreen = screen || osdScreen || (Quickshell.screens.length ? Quickshell.screens[0] : null);
        osdVisible = true;
        osdDismiss.restart();
    }
    Timer {
        id: osdDismiss
        interval: 1650
        repeat: false
        onTriggered: root.osdVisible = false
    }
    property bool sidebarVisible: false
    property bool advancedVisible: false
    property string quickAdvancedTab: "audio"
    property var quickControlInputItems: []
    function addQuickControlInput(item) { if (quickControlInputItems.indexOf(item)<0) quickControlInputItems=quickControlInputItems.concat([item]); }
    function removeQuickControlInput(item) { quickControlInputItems=quickControlInputItems.filter(candidate=>candidate!==item); }
    property bool quickReorderMode: false
    property var sidebarScreen: null
    property bool aiVisible: false
    property bool aiFullMode: false
    property var aiScreen: null
    property var settingsScreen: null
    property bool settingsVisible: false
    property bool hyprSettingsVisible: false
    property var hyprSettingsScreen: null
    property string hyprSettingsPage: "overview"
    property int hyprSettingsActivation: 0
    function openHyprSettings(page, screen) {
        hyprSettingsPage = page || "overview";
        hyprSettingsScreen = screen || hyprSettingsScreen || settingsScreen
            || (Quickshell.screens.length ? Quickshell.screens[0] : null);
        launcherVisible = false;
        sidebarVisible = false;
        hyprSettingsVisible = true;
        hyprSettingsActivation++;
    }
    property bool deviceSettingsVisible: false
    property bool deviceSettingsPending: false
    property bool deviceSettingsFullscreen: false
    property string deviceSettingsKind: "wifi"
    property string deviceSettingsSection: "details"
    property var deviceSettingsScreen: null
    // Anchored popups release their focus grab before a toplevel opens.
    signal deviceSettingsRequested()
    readonly property var deviceSections: ({
        wifi: ["networks", "hidden", "details", "dns", "sharing"],
        audio: ["applications", "output", "microphone"],
        bluetooth: ["devices"],
        power: ["status"]
    })
    function openDeviceSettings(kind, screen, section, fullscreen) {
        const sections = deviceSections[kind];
        if (!sections) return;
        deviceSettingsKind = kind;
        deviceSettingsSection = sections.indexOf(section) >= 0 ? section : sections[0];
        deviceSettingsFullscreen = false;
        deviceSettingsScreen = screen || sidebarScreen || settingsScreen
            || (Quickshell.screens.length ? Quickshell.screens[0] : null);
        sidebarVisible = false;
        launcherVisible = false;
        aiVisible = false;
        deviceSettingsPending = true;
        deviceSettingsRequested();
        deviceSettingsDelay.restart();
    }
    function closeDeviceSettings() {
        deviceSettingsDelay.stop();
        deviceSettingsPending = false;
        deviceSettingsVisible = false;
    }
    Timer {
        id: deviceSettingsDelay
        interval: 260
        onTriggered: {
            root.deviceSettingsPending = false;
            root.deviceSettingsVisible = true;
        }
    }
    property bool launcherVisible: false
    property bool launcherBlurActive: false
    property bool launcherBackdropBlurActive: false
    property var launcherScreen: null
    property var launcherAnchor: null
    property bool powerMenuVisible: false
    property var powerScreen: null
    function togglePowerMenu(screen) {
        if (powerMenuVisible) { powerMenuVisible = false; return; }
        powerScreen = screen || settingsScreen || launcherScreen || null;
        launcherVisible = false;
        sidebarVisible = false;
        aiVisible = false;
        powerMenuVisible = true;
    }
    // Wi-Fi sharing is an independent Wayland overlay, not a QR embedded in
    // the small anchored Wi-Fi popup. Only a label crosses this boundary;
    // credentials live exclusively inside the private PNG until dismissed.
    property bool wifiQrVisible: false
    property var wifiQrScreen: null
    property string wifiQrSsid: ""
    function openWifiQr(screen, ssid) {
        if (wifiQrVisible) return;
        wifiQrScreen = screen || sidebarScreen || powerScreen || null;
        wifiQrSsid = String(ssid || "");
        wifiQrVisible = true;
    }
    function closeWifiQr() {
        wifiQrVisible = false;
        wifiQrSsid = "";
    }
    property bool taskViewVisible: false
    property var monitorScreen: null
    property bool systemMonitorVisible: false
    // One session timer shared by every clock popup, including unloaded ones.
    property string clockTimerState: "idle"
    property int clockTimerDurationSeconds: 300
    property double clockTimerRemainingMs: 300000
    property double clockTimerDeadline: 0
    readonly property int clockTimerRemainingSeconds: Math.max(0, Math.ceil(clockTimerRemainingMs / 1000))
    signal clockTimerCompleted(int durationSeconds)
    signal clockAlarmCompleted()
    signal clockSoundRequested(bool alarm)
    signal clockSoundStopped()
    property string clockAlertKind: ""
    property int clockAlertSequence: 0
    property string clockSoundError: ""
    property bool clockSoundPlaying: false
    property double clockAlarmSnoozeUntil: 0
    readonly property string clockAlarmTime: String(SettingsStore.clockAlarmHour).padStart(2, "0")
        + ":" + String(SettingsStore.clockAlarmMinute).padStart(2, "0")

    function beginClockAlert(kind) {
        clockAlertKind = kind;
        clockAlertSequence++;
        if (SettingsStore.clockSoundEnabled) clockSoundRequested(kind === "alarm");
    }
    function dismissClockAlert() {
        clockAlertKind = "";
        clockSoundStopped();
    }
    function snoozeClockAlarm() {
        if (clockAlertKind !== "alarm") return;
        clockAlarmSnoozeUntil = Date.now() + 300000;
        dismissClockAlert();
    }
    function cancelClockAlarm() {
        clockAlarmSnoozeUntil = 0;
        SettingsStore.disableClockAlarm();
        if (clockAlertKind === "alarm") dismissClockAlert();
    }
    function updateClockAlarm() {
        const now = Date.now();
        const snoozed = clockAlarmSnoozeUntil > 0 && now >= clockAlarmSnoozeUntil;
        const scheduled = SettingsStore.clockAlarmEnabled && SettingsStore.clockAlarmNextAt > 0
            && now >= SettingsStore.clockAlarmNextAt;
        if (!snoozed && !scheduled) return;
        clockAlarmSnoozeUntil = 0;
        if (scheduled) {
            // Advance before emitting so repeated ticks/reloads never ring twice.
            if (SettingsStore.clockAlarmDaily) SettingsStore.clockAlarmNextAt = SettingsStore.nextClockAlarm(now);
            else {
                SettingsStore.clockAlarmEnabled = false;
                SettingsStore.clockAlarmNextAt = 0;
            }
            SettingsStore.save();
        }
        beginClockAlert("alarm");
        clockAlarmCompleted();
    }
    Timer {
        interval: 1000
        repeat: true
        running: SettingsStore.clockAlarmEnabled || root.clockAlarmSnoozeUntil > 0
        onTriggered: root.updateClockAlarm()
    }

    function formatClockTimer(seconds) {
        const value = Math.max(0, Math.floor(Number(seconds) || 0));
        const hours = Math.floor(value / 3600);
        const minutes = Math.floor(value / 60) % 60;
        return String(hours).padStart(2, "0") + ":" + String(minutes).padStart(2, "0")
            + ":" + String(value % 60).padStart(2, "0");
    }
    function setClockTimerDuration(seconds) {
        if (clockTimerState === "running" || clockTimerState === "paused"
                || typeof seconds !== "number" || !isFinite(seconds)
                || Math.floor(seconds) !== seconds || seconds < 1 || seconds > 86399) return false;
        clockTimerDurationSeconds = seconds;
        resetClockTimer();
        return true;
    }
    function startClockTimer() {
        if (clockTimerState === "running") return;
        if (clockAlertKind === "timer") dismissClockAlert();
        if (clockTimerState !== "paused") clockTimerRemainingMs = clockTimerDurationSeconds * 1000;
        clockTimerDeadline = Date.now() + clockTimerRemainingMs;
        clockTimerState = "running";
    }
    function updateClockTimer() {
        if (clockTimerState !== "running") return;
        // Recompute from the deadline so delayed frames and suspend do not drift.
        clockTimerRemainingMs = Math.max(0, clockTimerDeadline - Date.now());
        if (clockTimerRemainingMs > 0) return;
        clockTimerState = "finished";
        clockTimerDeadline = 0;
        beginClockAlert("timer");
        clockTimerCompleted(clockTimerDurationSeconds);
    }
    function pauseClockTimer() {
        updateClockTimer();
        if (clockTimerState !== "running") return;
        clockTimerState = "paused";
        clockTimerDeadline = 0;
    }
    function resetClockTimer() {
        if (clockAlertKind === "timer") dismissClockAlert();
        clockTimerState = "idle";
        clockTimerDeadline = 0;
        clockTimerRemainingMs = clockTimerDurationSeconds * 1000;
    }
    Timer {
        interval: 250
        repeat: true
        running: root.clockTimerState === "running"
        onTriggered: root.updateClockTimer()
    }

    signal notesChanged()
    property string settingsTab: "home"
    // The confirmation is a separate overlay window, never an inline Settings card.
    signal packageOperationConfirmed(string action, string packageName, string provider)
    // Human approval is a distinct, non-privileged layer. Actual credentials
    // are requested ONLY by the already registered system Polkit/PAM agent.
    property bool packageAuthVisible: false
    property bool packageAuthPending: false
    property bool packageAuthAgentDetected: true
    property bool packageAuthNativeBundled: false
    property bool packageAuthCanStartAgent: false
    property bool packageAuthFingerprintConfigured: false
    property var packageAuthScreen: null
    property string packageAuthAction: ""
    property string packageAuthPackage: ""
    property string packageAuthProvider: "pacman"
    function requestPackageAuthorization(action, packageName, provider) {
        if (["install", "remove"].indexOf(action) < 0 || !packageName ||
            ["pacman", "yay", "flatpak"].indexOf(provider) < 0) return;
        packageAuthAction = action;
        packageAuthPackage = packageName;
        packageAuthProvider = provider;
        packageAuthScreen = settingsScreen;
        // The first FloatingWindow must release focus and be destroyed before
        // the fullscreen Wayland authorization layer is made visible.
        packageAuthPending = true;
        packageAuthVisible = false;
    }
    function activatePendingPackageAuthorization() {
        if (!packageAuthPending || !packageAuthAction || !packageAuthPackage) return;
        packageAuthPending = false;
        packageAuthVisible = true;
    }
    function cancelPackageAuthorization() {
        packageAuthPending = false;
        packageAuthVisible = false;
        packageAuthAction = "";
        packageAuthPackage = "";
        packageAuthProvider = "pacman";
    }
    function approvePackageAuthorization() {
        if (!packageAuthVisible || !packageAuthAction || !packageAuthPackage) return;
        const action = packageAuthAction;
        const name = packageAuthPackage;
        const provider = packageAuthProvider;
        cancelPackageAuthorization();
        packageOperationConfirmed(action, name, provider);
    }
    // Explicit confirmation of shortcut backup before changing an existing binding.
    signal shortcutBackupApproved(string owner)
    signal shortcutBackupCancelled(string owner)
    property bool shortcutConfirmVisible: false
    property string shortcutConfirmTitle: ""
    property string shortcutConfirmTarget: ""
    property bool shortcutConfirmRecovery: false
    property var shortcutConfirmScreen: null
    property string shortcutConfirmOwner: ""
    property string shortcutConfirmWindowTitle: "RusticQ · Settings"
    function requestShortcutConfirmation(title, target, recovery, owner, screen, windowTitle) {
        if (shortcutConfirmVisible && shortcutConfirmOwner !== (owner || "")) shortcutBackupCancelled(shortcutConfirmOwner);
        shortcutConfirmTitle = title;
        shortcutConfirmTarget = target;
        shortcutConfirmRecovery = !!recovery;
        shortcutConfirmScreen = settingsScreen;
        if (screen) shortcutConfirmScreen = screen;
        shortcutConfirmOwner = owner || "";
        shortcutConfirmWindowTitle = windowTitle === "RusticQ Hyprland Settings" ? windowTitle : "RusticQ · Settings";
        shortcutConfirmVisible = true;
    }
    function cancelShortcutConfirmation() { shortcutConfirmVisible = false; shortcutBackupCancelled(shortcutConfirmOwner); }
    function approveShortcutConfirmation() {
        if (!shortcutConfirmVisible) return;
        shortcutConfirmVisible = false;
        shortcutBackupApproved(shortcutConfirmOwner);
    }
    property bool confirmationVisible: false
    property string confirmationAction: ""
    property string confirmationPackage: ""
    property string confirmationProvider: "pacman"
    property var confirmationScreen: null
    function requestPackageConfirmation(action, packageName, provider) {
        if ((action !== "remove" && action !== "install") || !packageName) return;
        if (provider !== undefined && ["pacman", "yay", "flatpak"].indexOf(provider) < 0) return;
        confirmationProvider = provider || "pacman";
        confirmationAction = action;
        confirmationPackage = packageName;
        confirmationScreen = settingsScreen;
        confirmationVisible = true;
    }
    function cancelPackageConfirmation() {
        confirmationVisible = false;
        confirmationAction = "";
        confirmationPackage = "";
        confirmationProvider = "pacman";
    }
    function acceptPackageConfirmation() {
        if (!confirmationVisible || !confirmationAction || !confirmationPackage) return;
        const action = confirmationAction, name = confirmationPackage, provider = confirmationProvider;
        cancelPackageConfirmation();
        // First dialog was the package confirmation. The SECOND dialog should
        // be the ACTUAL native Polkit/PAM prompt, not another decorative layer.
        // SettingsInfoPage waits for this window to release focus before pkexec.
        packageOperationConfirmed(action, name, provider);
    }


    function toggleQuick(screen) {
        if (sidebarVisible && sidebarScreen === screen) { sidebarVisible = false; return; }
        aiVisible = false;
        sidebarScreen = screen;
        sidebarVisible = true;
        advancedVisible = false;
    }
    function toggleAi(screen) {
        if (aiVisible && aiScreen === screen) { aiVisible = false; return; }
        sidebarVisible = false;
        aiScreen = screen;
        aiVisible = true;
    }
    function toggleLauncher(screen, anchor) {
        if (launcherVisible && launcherScreen === screen) { launcherVisible = false; return; }
        launcherScreen = screen;
        launcherAnchor = anchor && [anchor.x,anchor.y,anchor.width,anchor.height].every(Number.isFinite) ? anchor : null;
        sidebarVisible = false;
        aiVisible = false;
        launcherVisible = true;
    }
    function showSettings(tab, screen) {
        if (screen) settingsScreen = screen;
        settingsTab = tab || "home";
        settingsVisible = true;
        launcherVisible = false;
        sidebarVisible = false;
        aiVisible = false;
    }
    onSidebarVisibleChanged: { if (!sidebarVisible) { advancedVisible = false; quickReorderMode = false; } }
}
