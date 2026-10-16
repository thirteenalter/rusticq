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
    function showSettings(tab) {
        if (tab) settingsTab = tab;
        settingsVisible = true;
        sidebarVisible = false;
        aiVisible = false;
    }
    onSidebarVisibleChanged: { if (!sidebarVisible) advancedVisible = false; }
}
