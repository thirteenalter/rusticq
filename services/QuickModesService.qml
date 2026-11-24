pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "../config"

Singleton {
    id: root
    property bool awakeRequested: false
    readonly property bool keepAwake: awakeRequested && awakeHold.running
    property int previousProfile: PowerProfile.Balanced
    readonly property var microphone: Pipewire.defaultAudioSource
    // Process.running becomes true asynchronously. Reserve the helper before
    // exec() so rapid slider commits cannot replace a process that is starting.
    property bool backendActive: false
    readonly property bool busy: backendActive
    property string error: ""
    property bool refreshQueued: false
    property bool nightApplyQueued: false
    property bool requestedNightState: false
    property int requestedProfile: -1
    readonly property bool gamingPending: profileCheck.running
    property var states: ({
        night: { available: false, active: false, detail: "Checking night light…" }
    })
    readonly property bool anyActive: keepAwake || NotificationCenter.doNotDisturb || states.night.active
        || PowerProfiles.profile === PowerProfile.Performance || (microphone && microphone.audio && microphone.audio.muted)

    PwObjectTracker { objects: [root.microphone] }

    function active(key) {
        if (key === "awake") return keepAwake;
        if (key === "silent") return NotificationCenter.doNotDisturb;
        if (key === "gaming") return PowerProfiles.profile === PowerProfile.Performance;
        if (key === "mic") return !!(microphone && microphone.audio && microphone.audio.muted);
        return !!(states[key] && states[key].active);
    }
    function available(key) {
        if (key === "awake") return true;
        if (key === "silent") return true;
        if (key === "gaming") return PowerProfiles.hasPerformanceProfile;
        if (key === "mic") return !!(microphone && microphone.audio);
        return !!(states[key] && states[key].available);
    }
    function detail(key) {
        if (key === "awake") return "Prevent idle lock and automatic sleep, including while the bar is hidden";
        if (key === "silent") return "Do Not Disturb for RusticQ notifications; clock sounds have a separate switch";
        if (key === "gaming") return available(key) ? "Use the Performance power profile" : "Performance power profile unavailable";
        if (key === "mic") return available(key) ? "Mute the default microphone" : "No microphone available";
        return states[key] ? states[key].detail + (key === "night" ? "\nAdjust warmth in Settings → Modules → Night Light" : "") : "Unavailable";
    }
    function refresh() {
        refreshQueued = true;
        flushBackend();
    }
    function flushBackend() {
        if (busy) return;
        if (nightApplyQueued) {
            nightApplyQueued = false;
            backend.applying = true;
            backendActive = true;
            backend.exec(["python3", Quickshell.shellPath("scripts/quick_modes.py"), "set", "night",
                requestedNightState ? "on" : "off", "--temperature", String(SettingsStore.nightLightTemperature)]);
        } else if (refreshQueued) {
            refreshQueued = false;
            backend.applying = false;
            backendActive = true;
            backend.exec(["python3", Quickshell.shellPath("scripts/quick_modes.py"), "status"]);
        }
    }
    function setNightLightTemperature(value) {
        if (!SettingsStore.setNightLightTemperature(value)) return;
        if ((nightApplyQueued || (busy && backend.applying)) ? requestedNightState : active("night")) {
            requestedNightState = true;
            nightApplyQueued = true;
            error = "";
            flushBackend();
        }
    }
    function toggle(key) {
        if (!available(key)) return;
        error = "";
        if (key === "awake") {
            awakeRequested = !awakeRequested;
            if (awakeRequested && !awakeHold.running) awakeHold.running = true;
            return;
        }
        if (key === "silent") { NotificationCenter.doNotDisturb = !NotificationCenter.doNotDisturb; return; }
        if (key === "mic") { microphone.audio.muted = !microphone.audio.muted; return; }
        if (key === "gaming") {
            if (gamingPending) return;
            if (active(key)) requestedProfile = previousProfile === PowerProfile.Performance ? PowerProfile.Balanced : previousProfile;
            else { previousProfile = PowerProfiles.profile; requestedProfile = PowerProfile.Performance; }
            PowerProfiles.profile = requestedProfile;
            profileCheck.restart();
            return;
        }
        if (key !== "night") return;
        requestedNightState = nightApplyQueued || (busy && backend.applying) ? !requestedNightState : !active(key);
        nightApplyQueued = true;
        flushBackend();
    }
    Timer {
        id: profileCheck
        interval: 900
        onTriggered: if (PowerProfiles.profile !== root.requestedProfile)
            root.error = "The power service did not apply the requested profile.";
    }
    // cat exits on EOF when the mode is disabled or Quickshell closes its pipe.
    // This releases logind's inhibitor without leaving a background sleep process.
    Process {
        id: awakeHold
        command: ["systemd-inhibit", "--what=idle:sleep", "--mode=block", "--who=RusticQ", "--why=Keep Awake", "cat"]
        stdinEnabled: root.awakeRequested
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() && root.awakeRequested)
                root.error = "Keep Awake: " + text.trim().slice(0, 180)
        }
        onExited: (code, status) => {
            if (root.awakeRequested) {
                root.awakeRequested = false;
                if (!root.error) root.error = "Keep Awake could not acquire the system idle inhibitor.";
            }
        }
    }
    Process {
        id: backend
        property bool applying: false
        property bool received: false
        onStarted: received = false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text);
                    if (!response.states || !response.states.night) throw Error("Invalid mode response");
                    root.states = response.states;
                    backend.received = true;
                    if (!response.ok) root.error = response.error || "Mode change failed";
                } catch (e) { root.error = "Quick modes: " + e; }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !received) root.error = "Quick modes helper failed (exit " + code + ")";
            root.backendActive = false;
            Qt.callLater(root.flushBackend);
        }
    }
    Component.onCompleted: refresh()
}
