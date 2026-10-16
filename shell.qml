import QtQuick
import Quickshell
import "config"
import "modules/main"
import "modules/bar"
import "modules/ai"
import "modules/settings"
import "services"

// Satu bar untuk setiap monitor, satu sidebar sesuai monitor yang diklik.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // One server for the whole shell. Toast is rendered once, independent of monitors.
    NotificationToasts {}

    Variants {
        model: Quickshell.screens
        DesktopWidgets { required property var modelData; screen: modelData }
    }
    Variants {
        model: Quickshell.screens
        RusticDock { required property var modelData; screen: modelData }
    }
    LazyLoader {
        active: Store.launcherVisible
        LauncherOverlay { screen: Store.launcherScreen }
    }
    LazyLoader {
        active: Store.taskViewVisible
        TaskViewWindow {}
    }
    LazyLoader {
        active: Store.systemMonitorVisible
        SystemMonitorWindow {}
    }

    LazyLoader {
        active: Store.aiVisible
        AiWrapper {
            screen: Store.aiScreen
        }
    }

    LazyLoader {
        active: Store.settingsVisible
        SettingsWindow {}
    }

    LazyLoader {
        active: Store.sidebarVisible
        BarWrapper {
            screen: Store.sidebarScreen
        }
    }
}
