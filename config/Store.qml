pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Raised by the IPC dispatcher; each per-monitor bar consumes only its own actions.
    signal shortcutBarRequested(string kind, string screenName)
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
    property bool taskViewVisible: false
    property var monitorScreen: null
    property bool systemMonitorVisible: false
    property string settingsTab: "appearance"
    // The confirmation is a separate overlay window, never an inline Settings card.
    signal packageOperationConfirmed(string action, string packageName)
    property bool confirmationVisible: false
    property string confirmationAction: ""
    property string confirmationPackage: ""
    property var confirmationScreen: null
    function requestPackageConfirmation(action, packageName) {
        if ((action !== "remove" && action !== "install") || !packageName) return;
        confirmationAction = action;
        confirmationPackage = packageName;
        confirmationScreen = settingsScreen;
        confirmationVisible = true;
    }
    function cancelPackageConfirmation() {
        confirmationVisible = false;
        confirmationAction = "";
        confirmationPackage = "";
    }
    function acceptPackageConfirmation() {
        if (!confirmationVisible || !confirmationAction || !confirmationPackage) return;
        const action = confirmationAction, name = confirmationPackage;
        cancelPackageConfirmation();
        packageOperationConfirmed(action, name);
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
