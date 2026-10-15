pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

Singleton {
    id: root
    property bool keepAwake: false
    property int previousProfile: PowerProfile.Balanced
    readonly property var microphone: Pipewire.defaultAudioSource
    readonly property bool busy: backend.running
    property string error: ""
    property var states: ({
        silent: { available: false, active: false, detail: "Checking notification service…" },
        night: { available: false, active: false, detail: "Checking night light…" }
    })
    readonly property bool anyActive: keepAwake || states.silent.active || states.night.active
        || PowerProfiles.profile === PowerProfile.Performance || (microphone && microphone.audio && microphone.audio.muted)

    PwObjectTracker { objects: [root.microphone] }

    function active(key) {
        if (key === "awake") return keepAwake;
        if (key === "gaming") return PowerProfiles.profile === PowerProfile.Performance;
        if (key === "mic") return !!(microphone && microphone.audio && microphone.audio.muted);
        return !!(states[key] && states[key].active);
    }
    function available(key) {
        if (key === "awake") return true;
        if (key === "gaming") return PowerProfiles.hasPerformanceProfile;
        if (key === "mic") return !!(microphone && microphone.audio);
        return !!(states[key] && states[key].available);
    }
    function detail(key) {
        if (key === "awake") return "Prevent idle while this shell is running";
        if (key === "gaming") return available(key) ? "Use the Performance power profile" : "Performance power profile unavailable";
        if (key === "mic") return available(key) ? "Mute the default microphone" : "No microphone available";
        return states[key] ? states[key].detail : "Unavailable";
    }
    function refresh() {
        if (busy) return;
        backend.command = ["python3", Quickshell.shellPath("scripts/quick_modes.py"), "status"];
        backend.running = true;
    }
    function toggle(key) {
        if (!available(key)) return;
        error = "";
        if (key === "awake") { keepAwake = !keepAwake; return; }
        if (key === "mic") { microphone.audio.muted = !microphone.audio.muted; return; }
        if (key === "gaming") {
            if (active(key)) PowerProfiles.profile = previousProfile;
            else { previousProfile = PowerProfiles.profile; PowerProfiles.profile = PowerProfile.Performance; }
            return;
        }
        if (busy || (key !== "silent" && key !== "night")) return;
        backend.command = ["python3", Quickshell.shellPath("scripts/quick_modes.py"), "set", key, active(key) ? "off" : "on"];
        backend.running = true;
    }
    Process {
        id: backend
        property bool received: false
        onStarted: received = false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text);
                    if (!response.states || !response.states.silent || !response.states.night) throw Error("Invalid mode response");
                    root.states = response.states;
                    backend.received = true;
                    if (!response.ok) root.error = response.error || "Mode change failed";
                } catch (e) { root.error = "Quick modes: " + e; }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !received) root.error = "Quick modes helper failed (exit " + code + ")";
        }
    }
    Component.onCompleted: refresh()
}
