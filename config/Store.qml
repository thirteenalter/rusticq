pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool sidebarVisible: false
    property bool advancedVisible: false
    property var sidebarScreen: null
    property bool aiVisible: false
    property var aiScreen: null
    property bool settingsVisible: false
    property bool launcherVisible: false
    property var launcherScreen: null
    property bool taskViewVisible: false
    property string settingsTab: "appearance"

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
    function showSettings(tab) {
        if (tab) settingsTab = tab;
        settingsVisible = true;
        launcherVisible = false;
        sidebarVisible = false;
        aiVisible = false;
    }
    onSidebarVisibleChanged: { if (!sidebarVisible) advancedVisible = false; }
}
