import QtQuick
import Quickshell
import "config"
import "modules/main"
import "modules/bar"
import "modules/ai"
import "modules/settings"

// Satu bar untuk setiap monitor, satu sidebar sesuai monitor yang diklik.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
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
