pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One sampler for the entire shell. Throughput is a difference of read-only
// kernel counters; unknown sensors remain null and are never guessed.
Singleton {
    id: root
    property string gpuName: "GPU"
    property var gpuPercent: null
    property var vramUsed: null
    property var vramTotal: null
    property var interfaces: []
    property var disks: []
    property real rxPerSec: 0
    property real txPerSec: 0
    property real diskReadPerSec: 0
    property real diskWritePerSec: 0
    property var gpuHistory: []
    property var rxHistory: []
    property var txHistory: []
    property var readHistory: []
    property var writeHistory: []
    property int historyLimit: 72
    property string error: ""
    property var previous: null
    property double previousTime: 0

    function append(history, value) {
        return history.concat([Math.max(0, Number(value) || 0)]).slice(-historyLimit)
    }
    function sample(data) {
        const now = Date.now();
        const net = data.network || {};
        const disk = data.diskIo || {};
        const gpu = data.gpu || {};
        gpuName = gpu.name || "GPU";
        gpuPercent = gpu.usage === null || gpu.usage === undefined ? null : Number(gpu.usage);
        vramUsed = gpu.vramUsed;
        vramTotal = gpu.vramTotal;
        interfaces = net.interfaces || [];
        disks = disk.devices || [];
        gpuHistory = append(gpuHistory, gpuPercent === null ? 0 : gpuPercent / 100);
        if (previous && now > previousTime) {
            const seconds = (now - previousTime) / 1000;
            function rate(next, old) { return Math.max(0, (Number(next || 0) - Number(old || 0)) / seconds); }
            rxPerSec = rate(net.rxBytes, previous.network.rxBytes);
            txPerSec = rate(net.txBytes, previous.network.txBytes);
            diskReadPerSec = rate(disk.readBytes, previous.diskIo.readBytes);
            diskWritePerSec = rate(disk.writeBytes, previous.diskIo.writeBytes);
            rxHistory = append(rxHistory, rxPerSec);
            txHistory = append(txHistory, txPerSec);
            readHistory = append(readHistory, diskReadPerSec);
            writeHistory = append(writeHistory, diskWritePerSec);
        }
        previous = {network:net, diskIo:disk};
        previousTime = now;
        error = "";
    }
    function speed(bytes) {
        if (bytes < 1024) return bytes.toFixed(0) + " B/s";
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KiB/s";
        return (bytes / 1048576).toFixed(2) + " MiB/s";
    }
    Process {
        id: dataProcess
        command: ["python3", Quickshell.shellPath("scripts/rustiq-system-metrics.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.sample(JSON.parse(this.text)); }
                catch (e) { root.error = "Unable to read kernel metrics"; }
            }
        }
        onExited: (exitCode, exitStatus) => { if (exitCode !== 0) root.error = "Metrics helper unavailable"; }
    }
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!dataProcess.running) dataProcess.running = true
    }
}
