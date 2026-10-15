pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// SysMonService.qml
// Taruh file ini di folder "services/" project quickshell kamu.
// Pastikan ada file "services/qmldir" berisi:
//
//   singleton SysMonService 1.0 SysMonService.qml
//
// Lalu import dari widget lain dengan:
//   import "../../services/" as Services
//   Services.SysMonService.cpuUsage

Singleton {
    id: root

    // ---- konfigurasi ----
    property string diskPath: "/"
    property string thermalZonePath: "/sys/class/thermal/thermal_zone0/temp"
    property int updateIntervalMs: 1000

    // ---- CPU ----
    property real cpuUsage: 0        // 0 - 100
    property var _prevIdle: -1
    property var _prevTotal: -1

    // ---- Memory ----
    property real memUsedGB: 0
    property real memTotalGB: 0
    property real memUsedPercent: 0  // 0 - 1

    // ---- Disk ----
    property real diskUsedGB: 0
    property real diskTotalGB: 0
    property real diskAvailableGB: 0
    property real diskUsedPercent: 0 // 0 - 1

    // ---- Temperature ----
    property real temperature: -1    // -1 when thermal sensor is unavailable

    // Satu proses shell per tick, gabungkan semua sumber data
    // supaya tidak spawn banyak proses sekaligus tiap detik.
    Process {
        id: statsProc
        command: ["sh", "-c",
            "cat /proc/stat | head -n1; " +
            "echo '###'; " +
            "cat /proc/meminfo; " +
            "echo '###'; " +
            "df -B1 " + root.diskPath + " | tail -n1; " +
            "echo '###'; " +
            "cat " + root.thermalZonePath + " 2>/dev/null || echo NaN"
        ]

        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Timer {
        interval: root.updateIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProc.running)
                statsProc.running = true
        }
    }

    function _parse(output) {
        const parts = output.split("###")
        if (parts.length < 4)
            return

        _parseCpu(parts[0])
        _parseMemory(parts[1])
        _parseDisk(parts[2])
        _parseTemperature(parts[3])
    }

    function _parseCpu(text) {
        // format: cpu  user nice system idle iowait irq softirq steal guest guest_nice
        const fields = text.trim().split(/\s+/)
        if (fields.length < 5)
            return

        const values = fields.slice(1).map(Number)
        const idle = values[3] + values[4]
        // guest/guest_nice are already included in user/nice counters.
        const total = values.slice(0, 8).reduce((a, b) => a + b, 0)

        if (root._prevTotal >= 0) {
            const totalDiff = total - root._prevTotal
            const idleDiff = idle - root._prevIdle

            if (totalDiff > 0) {
                const usage = 100 * (1 - idleDiff / totalDiff)
                root.cpuUsage = Math.max(0, Math.min(100, usage))
            }
        }

        root._prevIdle = idle
        root._prevTotal = total
    }

    function _parseMemory(text) {
        const lines = text.trim().split("\n")
        let totalKb = 0
        let availKb = 0

        for (const line of lines) {
            if (line.startsWith("MemTotal:")) {
                totalKb = parseInt(line.match(/\d+/)[0])
            } else if (line.startsWith("MemAvailable:")) {
                availKb = parseInt(line.match(/\d+/)[0])
            }
        }

        const usedKb = totalKb - availKb

        root.memTotalGB = totalKb / 1024 / 1024
        root.memUsedGB = usedKb / 1024 / 1024
        root.memUsedPercent = totalKb > 0 ? usedKb / totalKb : 0
    }

    function _parseDisk(text) {
        // format df -B1: Filesystem 1B-blocks Used Available Use% Mounted
        const fields = text.trim().split(/\s+/)
        if (fields.length < 4)
            return

        const totalBytes = Number(fields[1])
        const usedBytes = Number(fields[2])
        const availableBytes = Number(fields[3])

        root.diskTotalGB = totalBytes / 1024 / 1024 / 1024
        root.diskUsedGB = usedBytes / 1024 / 1024 / 1024
        root.diskAvailableGB = availableBytes / 1024 / 1024 / 1024
        root.diskUsedPercent = totalBytes > 0 ? usedBytes / totalBytes : 0
    }

    function _parseTemperature(text) {
        const raw = Number(text.trim())
        if (isNaN(raw)) {
            root.temperature = -1
            return
        }

        // /sys/class/thermal biasanya dalam millidegree celcius
        root.temperature = raw > 1000 ? raw / 1000 : raw
    }
}
