import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../../config"

// Only one monitor watcher for the whole shell; audio events use native PipeWire.
Item {
    id: root
    width: 0; height: 0
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    property bool ready: false
    function activeScreen() {
        const hypr = Hyprland.focusedMonitor;
        const name = hypr ? hypr.name : "";
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
        return Quickshell.screens.length ? Quickshell.screens[0] : null;
    }
    function present(kind, level, text, hasLevel, muted) {
        if (!root.ready) return;
        Store.showOsd(kind, level, text, hasLevel, muted, root.activeScreen());
    }
    Timer { interval: 1500; repeat: false; running: true; onTriggered: root.ready = true }
    PwObjectTracker { objects: [root.sink, root.source].filter(item => item !== null) }
    Connections {
        target: root.sink ? root.sink.audio : null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            if (root.sink && root.sink.audio)
                root.present("volume", root.sink.audio.volume * 100,
                             root.sink.audio.muted ? "Volume muted" : "Speaker volume", true, root.sink.audio.muted);
        }
        function onMutedChanged() {
            if (root.sink && root.sink.audio)
                root.present("volume", root.sink.audio.volume * 100,
                             root.sink.audio.muted ? "Volume muted" : "Speaker unmuted", true, root.sink.audio.muted);
        }
    }
    Connections {
        target: root.source ? root.source.audio : null
        ignoreUnknownSignals: true
        function onMutedChanged() {
            if (root.source && root.source.audio)
                root.present("microphone", root.source.audio.volume * 100,
                             root.source.audio.muted ? "Microphone muted" : "Microphone on", true, root.source.audio.muted);
        }
    }
    // One tiny Python watcher reads /sys/class/backlight and kbd_backlight.
    // No repeated brightnessctl subprocesses or per-screen watchers.
    Process {
        id: hardwareWatch
        running: SettingsStore.osdEnabled
        command: ["python3", Quickshell.shellPath("scripts/rusticq-osd-hardware.py"), "watch"]
        stdout: SplitParser { onRead: message => {
            try {
                const info = JSON.parse(message);
                if (info.kind === "brightness" || info.kind === "keyboard")
                    root.present(info.kind, info.percent, info.kind === "brightness" ? "Screen brightness" : "Keyboard backlight", true, false);
            } catch(e) { /* Ignore non-JSON diagnostic output, never crash OSD. */ }
        } }
        stderr: SplitParser { onRead: message => console.warn("OSD hardware: " + message) }
    }
    Process {
        id: controlProc
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text.trim());
                if (!result.ok) root.present("error", 0, result.message || "Device unavailable", false, true);
                else if (result.kind === "touchpad")
                    root.present("touchpad", 0, result.enabled ? "Touchpad enabled" : "Touchpad disabled", false, !result.enabled);
                else if (result.kind === "keyboard" || result.kind === "brightness")
                    root.present(result.kind, result.percent,
                         result.kind === "keyboard" ? "Keyboard backlight" : "Screen brightness", true, false);
            } catch(e) { root.present("error", 0, "Hardware control unavailable", false, true); }
        } }
    }
    function control(action) {
        if (controlProc.running) return;
        controlProc.exec(["python3", Quickshell.shellPath("scripts/rusticq-osd-hardware.py"), action]);
    }
    function adjustVolume(action) {
        const audio = root.sink && root.sink.audio;
        if (!audio) { root.present("error",0,"Audio output unavailable",false,true); return; }
        if (action === "volume-mute") audio.muted = !audio.muted;
        else {
            audio.volume = Math.max(0, Math.min(1.5, audio.volume + (action === "volume-up" ? 0.05 : -0.05)));
            if (audio.muted) audio.muted = false;
        }
        root.present("volume", audio.volume * 100, audio.muted ? "Volume muted" : "Speaker volume", true, audio.muted);
    }
    function adjustMicrophone() {
        const audio = root.source && root.source.audio;
        if (!audio) { root.present("error",0,"Microphone unavailable",false,true); return; }
        audio.muted = !audio.muted;
        root.present("microphone", audio.volume * 100, audio.muted ? "Microphone muted" : "Microphone on", true, audio.muted);
    }
    Connections {
        target: Store
        function onOsdControlRequested(action) {
            if (!SettingsStore.osdEnabled && action === "preview") return;
            if (action === "preview") root.present("volume", 67, "RusticQ system OSD", true, false);
            else if (["volume-up","volume-down","volume-mute"].indexOf(action) >= 0) root.adjustVolume(action);
            else if (action === "microphone-mute") root.adjustMicrophone();
            else if (["brightness-up","brightness-down","keyboard-up","keyboard-down","touchpad-toggle"].indexOf(action) >= 0) root.control(action);
        }
    }
}
