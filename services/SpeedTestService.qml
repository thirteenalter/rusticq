pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: service
    // Session state survives popup destruction and is shared across monitors.
    readonly property bool running: request.running
    readonly property bool checking: probe.running
    readonly property bool online: Networking.devices.values.some(device => device.connected)
        && !(Networking.canCheckConnectivity && Networking.connectivityCheckEnabled
             && (Networking.connectivity === NetworkConnectivity.None || Networking.connectivity === NetworkConnectivity.Portal))
    property string phase: "idle"
    property string dependencyState: "checking"
    property string backend: ""
    property real progress: 0
    property real pingMs: -1
    property real downloadMbps: -1
    property real uploadMbps: -1
    property double lastTestTime: 0
    property var lastResult: null
    property string error: ""
    readonly property string state: running ? phase : !online ? "offline" : dependencyState === "missing" ? "missing" : phase
    readonly property string statusText: state === "offline" ? "No connection. Connect or sign in to Wi-Fi first."
        : state === "missing" ? "Install Ookla Speedtest CLI (speedtest) or speedtest-cli."
        : state === "preparing" ? "Connecting to a test server…"
        : state === "ping" ? "Measuring latency…"
        : state === "download" ? "Measuring download…" : state === "upload" ? "Measuring upload…"
        : state === "complete" ? "Test complete" : state === "cancelled" ? "Test cancelled"
        : state === "error" ? error : checking ? "Checking speed test backend…" : "Ready · Uses internet data"
    readonly property string actionText: running ? "Cancel Test" : !online ? "No Connection"
        : state === "error" || state === "missing" ? "Retry" : state === "complete" || lastResult ? "Test Again" : "Test Speed"

    function start() {
        if (running || checking || !online) return;
        pingMs = downloadMbps = uploadMbps = -1;
        progress = 0;
        error = "";
        phase = "preparing";
        request.running = true;
    }
    function stopProcess() {
        request.signal(15);
        forceStop.restart();
    }
    function cancel() {
        if (!running) return;
        phase = "cancelled";
        progress = 0;
        pingMs = lastResult ? lastResult.pingMs : -1;
        downloadMbps = lastResult ? lastResult.downloadMbps : -1;
        uploadMbps = lastResult ? lastResult.uploadMbps : -1;
        stopProcess();
    }
    function fail(message) {
        phase = "error";
        error = message;
        if (running) stopProcess();
    }
    function applyEvent(line) {
        if (!running || ["cancelled", "error", "missing"].includes(phase)) return;
        try {
            const event = JSON.parse(line);
            if (!["preparing", "ping", "download", "upload", "complete", "error", "missing", "cancelled"].includes(event.phase)) throw Error("phase");
            for (const key of ["pingMs", "downloadMbps", "uploadMbps"])
                if (event[key] !== undefined && (typeof event[key] !== "number" || !Number.isFinite(event[key]) || event[key] < 0)) throw Error("metric");
            if (event.progress !== undefined && (typeof event.progress !== "number" || !Number.isFinite(event.progress) || event.progress < 0 || event.progress > 1)) throw Error("progress");
            if (event.phase === "complete" && ![event.pingMs, event.downloadMbps, event.uploadMbps].every(value => typeof value === "number" && Number.isFinite(value) && value >= 0)) throw Error("result");
            phase = event.phase;
            if (event.backend === "ookla" || event.backend === "sivel") {
                backend = event.backend;
                dependencyState = "ready";
            }
            if (event.progress !== undefined) progress = event.progress;
            for (const key of ["pingMs", "downloadMbps", "uploadMbps"])
                if (event[key] !== undefined) service[key] = event[key];
            if (phase === "missing") dependencyState = "missing";
            if (phase === "error") error = typeof event.message === "string" && event.message.length > 0
                ? event.message : "Speed test failed. Retry the test.";
            if (phase === "complete") {
                lastResult = {pingMs: pingMs, downloadMbps: downloadMbps, uploadMbps: uploadMbps};
                lastTestTime = Date.now();
            }
        } catch (e) { fail("Could not read speed test results. Retry the test."); }
    }
    Component.onCompleted: probe.running = true
    Process {
        id: probe
        command: ["python3", Quickshell.shellPath("scripts/rusticq-speedtest.py"), "--probe"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const event = JSON.parse(this.text.trim());
                    if (event.phase === "ready" && ["ookla", "sivel"].includes(event.backend)) {
                        service.backend = event.backend;
                        service.dependencyState = "ready";
                    } else service.dependencyState = "missing";
                } catch (e) { service.dependencyState = "missing"; }
            }
        }
        onExited: (code, status) => { if (service.dependencyState === "checking") service.dependencyState = "missing"; }
    }
    Process {
        id: request
        command: ["python3", Quickshell.shellPath("scripts/rusticq-speedtest.py")]
        stdout: SplitParser { onRead: data => service.applyEvent(data) }
        onExited: (code, status) => {
            forceStop.stop();
            if (["cancelled", "error", "missing"].includes(service.phase)) return;
            if (code !== 0 || service.phase !== "complete") service.fail("Speed test stopped before finishing. Retry the test.");
        }
    }
    Timer {
        objectName: "speedTestWatchdog"
        interval: 130000
        running: service.running
        onTriggered: service.fail("Speed test timed out. Check your connection and retry.")
    }
    Timer { id: forceStop; interval: 1500; onTriggered: if (service.running) request.signal(9) }
}
