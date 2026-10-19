import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "config"
import "modules/main"
import "modules/bar"
import "modules/ai"
import "modules/settings"
import "modules/power"
import "services"

// Satu bar untuk setiap monitor, satu sidebar sesuai monitor yang diklik.
ShellRoot {
    id: root
    // Resolve keyboard shortcuts from Hyprland focus, not Quickshell.screens[0].
    // A workspace is displayed by its monitor, so focusing workspace 2 on DP-2
    // opens every overlay on DP-2 without spawning a second Quickshell process.
    function focusedScreen() {
        const focused = Hyprland.focusedMonitor || (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.monitor : null);
        const name = focused ? focused.name : "";
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
        }
        // Only an initialization/unplugged-monitor fallback; never hardcode primary in the successful case.
        return Store.launcherScreen || Store.sidebarScreen || (Quickshell.screens.length ? Quickshell.screens[0] : null);
    }
    function dispatchShortcut(action) {
        const screen = focusedScreen();
        const screenName = screen ? screen.name : "";
        if (action === "bar-toggle") { SettingsStore.toggleBar(); return; }
        if (action === "bar-show") { SettingsStore.setBarVisible(true); return; }
        if (action === "bar-hide") { SettingsStore.setBarVisible(false); return; }
        if (action === "bar-menu") { Store.shortcutBarRequested("menu-default", screenName); return; }
        if (action === "bar-quick-modes") { Store.shortcutBarRequested("quick-modes", screenName); return; }
        if (action === "bar-network") {
            Store.shortcutBarRequested(WifiService.ethernetConnected ? "ethernet" : "wifi", screenName); return;
        }
        if (action === "power") { Store.togglePowerMenu(screen); return; }
        if (action === "lock") { Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/rusticq-native-lock.py"), "start"]); return; }
        if (action === "launcher") { Store.toggleLauncher(screen); return; }
        if (action === "quick") { Store.toggleQuick(screen); return; }
        if (action === "ai") { Store.toggleAi(screen); return; }
        if (action === "monitor") { Store.monitorScreen = screen; Store.systemMonitorVisible = !Store.systemMonitorVisible; return; }
        if (action === "settings") { Store.showSettings("appearance", screen); return; }
        if (action.indexOf("settings-") === 0) {
            const tab = action.substring(9);
            if (["appearance", "bar", "modules", "widgets", "dock", "launcher", "display", "os", "hardware", "apps", "storage", "updates", "shortcuts", "integration", "ai", "about"].indexOf(tab) >= 0)
                Store.showSettings(tab, screen);
            return;
        }
        if (action.indexOf("popup-") === 0) {
            const popup = action.substring(6);
            if (["wifi", "ethernet", "bluetooth", "battery", "audio", "weather", "time", "date", "task", "notifications"].indexOf(popup) >= 0)
                Store.shortcutBarRequested(popup, screenName);
            return;
        }
        if (action.indexOf("menu-") === 0) {
            const menu = action.substring(5);
            if (["file", "edit", "view", "share", "shell", "tools"].indexOf(menu) >= 0)
                Store.shortcutBarRequested("menu-" + menu, screenName);
            return;
        }
        if (action.indexOf("mode-") === 0) {
            const mode = action.substring(5);
            if (["awake", "silent", "gaming", "night", "mic"].indexOf(mode) >= 0)
                QuickModesService.toggle(mode);
            return;
        }
        if (/^workspace-(10|[1-9])$/.test(action)) {
            const ws = Number(action.substring(10));
            Hyprland.dispatch(Hyprland.usingLua
                ? "hl.dsp.focus({ workspace = " + ws + ", on_current_monitor = true })"
                : "workspace " + ws);
            return;
        }
        // Exact existing ContextMenu subactions, not arbitrary shell commands.
        if (action.indexOf("item-file-") === 0 || action === "item-shell-terminal") {
            const id = action.substring(5);
            if (["file-home", "file-downloads", "file-config", "shell-terminal"].indexOf(id) >= 0)
                Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/rustiq-menu-action.sh"), id]);
            return;
        }
        if (action === "item-shell-power") { Store.togglePowerMenu(screen); return; }
        if (action === "item-shell-monitor") { Store.monitorScreen = screen; Store.systemMonitorVisible = true; return; }
        if (action === "item-tools-settings") { Store.showSettings("bar", screen); return; }
        if (action === "item-tools-region") {
            Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/rustiq-capture.sh"), "region"]); return;
        }
        if (action.indexOf("item-view-") === 0) {
            const mode = action.substring(10);
            if (["compact", "clean-compact", "separated", "professional", "simple"].indexOf(mode) >= 0) {
                SettingsStore.barMode = mode;
                SettingsStore.save();
            }
            return;
        }
        if (action.indexOf("item-share-") === 0) {
            const id = action.substring(11);
            if (["start-screen", "start-region", "start-audio", "stop", "portal-check", "record-folder"].indexOf(id) >= 0) {
                ScreenRecorder.action(id === "record-folder" ? "folder" : id);
            } else if (["full", "region", "folder"].indexOf(id) >= 0) {
                Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/rustiq-capture.sh"), id]);
            }
            return;
        }
        if (action === "dock-files") { Quickshell.execDetached(["sh", "-c", "xdg-open \"$HOME\""]); return; }
        if (action === "dock-browser") { Quickshell.execDetached(["xdg-open", "https://www.google.com"]); return; }
    }
    // Keep older, saved RC4 shortcuts functioning alongside v3's dispatch action.
    IpcHandler {
        target: "rusticq"
        function settings(): void { root.dispatchShortcut("settings"); }
        function launcher(): void { root.dispatchShortcut("launcher"); }
        function quick(): void { root.dispatchShortcut("quick"); }
        function ai(): void { root.dispatchShortcut("ai"); }
        function monitor(): void { root.dispatchShortcut("monitor"); }
        function power(): void { root.dispatchShortcut("power"); }
        function lock(): void { root.dispatchShortcut("lock"); }
        function dispatch(action: string): void { root.dispatchShortcut(action); }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        BarRecoveryHandle { required property var modelData; screen: modelData }
    }

    // Wallpaper restore is opt-in, once per shell, and never silently stops
    // another running wallpaper service. Same managed process reused on reload.
    Process {
        id: wallpaperStartup
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text.trim());
                if (!result.ok) console.warn("Wallpaper: " + result.message);
            } catch(e) { console.warn("Wallpaper restore response invalid: " + String(e)); }
        } }
    }
    Timer {
        interval: 1400; repeat: false; running: true
        onTriggered: {
            if (!SettingsStore.wallpaperAutoRestore || SettingsStore.wallpaperBackend !== "swaybg" || !SettingsStore.wallpaperPath.length) return;
            const args = ["python3", Quickshell.shellPath("scripts/rusticq-wallpaper.py"), SettingsStore.wallpaperPath,
                          "--backend", "swaybg", "--mode", SettingsStore.wallpaperFitMode];
            if (SettingsStore.wallpaperReplaceOnRestore) args.push("--replace-conflicts");
            wallpaperStartup.exec(args);
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

    // Keep the AI window instantiated while hidden to preserve active threads
    // and avoid interrupting its in-flight cloud request on presentation changes.
    // Optional: unload only the hidden AI window, not chat/session services.
    // Opt-in because closing it can cancel active replies or unsent drafts.
    LazyLoader {
        active: !SettingsStore.lowMemoryShellMode || Store.aiVisible
        AiWrapper {
            visible: Store.aiVisible
            screen: Store.aiScreen
        }
    }

    LazyLoader {
        active: Store.settingsVisible
        SettingsWindow {}
    }
    LazyLoader {
        active: Store.powerMenuVisible
        PowerMenu {}
    }
    // Keep the QR owner alive while hidden so its cleanup process can finish.
    WifiShareOverlay {}
    LazyLoader {
        active: Store.confirmationVisible
        PackageConfirmationWindow {}
    }
    LazyLoader {
        active: Store.shortcutConfirmVisible
        ShortcutBackupConfirmationWindow {}
    }


    LazyLoader {
        active: Store.sidebarVisible
        BarWrapper {
            screen: Store.sidebarScreen
        }
    }
}
