pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
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
    property var osdScreen: null
    function showOsd(kind, percent, label, hasLevel, muted, screen) {
        if (!SettingsStore.osdEnabled) return;
        if (["volume", "microphone", "brightness", "keyboard", "touchpad", "error"].indexOf(kind) < 0) return;
        osdKind = kind;
        osdPercent = Math.max(0, Math.min(100, Math.round(Number(percent) || 0)));
        osdLabel = String(label || "").slice(0, 110);
        osdHasLevel = hasLevel === true;
        osdMuted = muted === true;
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
    property bool quickReorderMode: false
    property var sidebarScreen: null
    property bool aiVisible: false
    property bool aiFullMode: false
    property var aiScreen: null
    property var settingsScreen: null
    property bool settingsVisible: false
    property bool launcherVisible: false
    property var launcherScreen: null
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
    signal notesChanged()
    property string settingsTab: "appearance"
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
    signal shortcutBackupApproved()
    property bool shortcutConfirmVisible: false
    property string shortcutConfirmTitle: ""
    property string shortcutConfirmTarget: ""
    property bool shortcutConfirmRecovery: false
    property var shortcutConfirmScreen: null
    function requestShortcutConfirmation(title, target, recovery) {
        shortcutConfirmTitle = title;
        shortcutConfirmTarget = target;
        shortcutConfirmRecovery = !!recovery;
        shortcutConfirmScreen = settingsScreen;
        shortcutConfirmVisible = true;
    }
    function cancelShortcutConfirmation() { shortcutConfirmVisible = false; }
    function approveShortcutConfirmation() {
        if (!shortcutConfirmVisible) return;
        shortcutConfirmVisible = false;
        shortcutBackupApproved();
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
    function toggleLauncher(screen) {
        if (launcherVisible && launcherScreen === screen) { launcherVisible = false; return; }
        launcherScreen = screen;
        sidebarVisible = false;
        aiVisible = false;
        launcherVisible = true;
    }
    function showSettings(tab, screen) {
        if (screen) settingsScreen = screen;
        if (tab) settingsTab = tab;
        settingsVisible = true;
        launcherVisible = false;
        sidebarVisible = false;
        aiVisible = false;
    }
    onSidebarVisibleChanged: { if (!sidebarVisible) { advancedVisible = false; quickReorderMode = false; } }
}
