pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io

Singleton {
    id: wifi

    property string fallbackDevice: "No Wi-Fi adapter"

    // One shared request survives closing a popup or switching monitors.
    property bool hiddenConnecting: false
    property bool hiddenFailed: false
    property string hiddenMessage: ""
    property string hiddenPayload: ""

    function connectHidden(ssid, security, password) {
        if (hiddenConnecting) return false;
        hiddenFailed = false;
        hiddenMessage = "";
        if (!wifiDevice || !Networking.wifiEnabled || !Networking.wifiHardwareEnabled) {
            hiddenFailed = true;
            hiddenMessage = "Enable an available Wi-Fi adapter first";
            return false;
        }
        hiddenPayload = JSON.stringify({ssid: ssid, security: security,
                                       password: password, interface: wifiDevice.name});
        hiddenConnecting = true;
        hiddenRequest.running = true;
        return true;
    }

    Process {
        id: hiddenRequest
        command: ["python3", Quickshell.shellPath("scripts/rusticq-wifi-hidden.py")]
        stdinEnabled: true
        onStarted: {
            write(wifi.hiddenPayload + "\n");
            wifi.hiddenPayload = "";
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text.trim());
                    wifi.hiddenFailed = !result.ok;
                    wifi.hiddenMessage = result.message || "Hidden Wi-Fi request failed";
                } catch (e) {
                    wifi.hiddenFailed = true;
                    wifi.hiddenMessage = "Could not read the hidden Wi-Fi connection result";
                }
            }
        }
        onExited: (code, status) => {
            wifi.hiddenPayload = "";
            wifi.hiddenConnecting = false;
            if (code !== 0 && !wifi.hiddenMessage) {
                wifi.hiddenFailed = true;
                wifi.hiddenMessage = "Could not connect to hidden Wi-Fi";
            }
        }
    }

    // ============================================================
    // Native Quickshell WiFi Objects (NetworkManager backend)
    // ============================================================

    property var wifiDevice: {
        let vals = Networking.devices.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].type === DeviceType.Wifi)
                return vals[i];
        }
        return null;
    }

    // Wired links are detected via NetworkManager, not by interface name.
    readonly property var wiredDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            const dev = devices[i];
            if (dev.type === DeviceType.Wired && dev.connected && dev.hasLink)
                return dev;
        }
        return null;
    }
    readonly property bool ethernetConnected: wiredDevice !== null
    readonly property string ethernetName: wiredDevice ? wiredDevice.name : ""
    readonly property int ethernetMbps: wiredDevice ? wiredDevice.linkSpeed : 0

    property var connectedNetwork: {
        if (!wifiDevice)
            return null;
        let nets = wifiDevice.networks.values;
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].connected)
                return nets[i];
        }
        return null;
    }

    // ============================================================
    // Public API (sama persis dengan kode lama agar UI tidak rusak)
    // ============================================================

    property string device: wifiDevice ? wifiDevice.name : fallbackDevice

    readonly property bool enabled: tethering || (wifiDevice !== null && Networking.wifiEnabled && Networking.wifiHardwareEnabled)

    readonly property bool connected: tethering || connectedNetwork !== null

    property bool tethering: false

    readonly property int strength: {
        if (tethering && !connectedNetwork)
            return 100;
        if (!connectedNetwork)
            return 0;
        return Math.round(connectedNetwork.signalStrength * 100);
    }

    readonly property string ssid: {
        return connectedNetwork ? connectedNetwork.name : (tethering ? "USB Tethering" : "");
    }

    readonly property var tetherDrivers: /^(rndis_host|cdc_ether|cdc_ncm|cdc_acm|usbnet|ipheth|cdc_subset)$/i

    readonly property string icon: {
        if (tethering && !connectedNetwork)
            return "\ue1e2";

        if (!enabled)
            return "\ue1da";

        if (!connected)
            return "\uf0ef";

        if (strength < 25)
            return "\uebe4";

        if (strength < 50)
            return "\uebd6";

        if (strength < 75)
            return "\uebe1";

        return "\ue1d8";
    }

    // ============================================================
    // USB Tethering Detection (tidak ada native API di Quickshell)
    // ============================================================

    Timer {
        interval: 15000 // USB driver discovery is a fallback, not a real-time poll.
        running: true
        repeat: true

        triggeredOnStart: true

        onTriggered: {
            tetherProc.exec(["sh", "-c", `
for path in /sys/class/net/*/; do
  iface=$(basename "$path")
  [ "$iface" = "lo" ] && continue
  drv=$(readlink -f "$path/device/driver" 2>/dev/null | xargs -n1 basename 2>/dev/null)
  ip4count=$(ip -4 addr show dev "$iface" 2>/dev/null | grep -c "inet ")
  echo "$iface|$drv|$ip4count"
done
`]);
        }
    }

    Process {
        id: tetherProc

        stdout: StdioCollector {
            onStreamFinished: {
                let tetherIface = "";
                const lines = text.trim().split("\n");
                for (const line of lines) {
                    const parts = line.split("|");
                    if (parts.length < 3)
                        continue;
                    const iface = parts[0];
                    const drv = parts[1];
                    const ip4count = Number(parts[2]);
                    if (!drv)
                        continue;
                    if (wifi.tetherDrivers.test(drv.trim()) && ip4count > 0) {
                        tetherIface = iface;
                        break;
                    }
                }
                wifi.tethering = tetherIface.length > 0;
                if (wifi.tethering) {
                    console.log("[WiFi] USB Tethering via", tetherIface);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length)
                    console.log("[WiFi tether stderr]", text);
            }
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                console.log("[WiFi tether] process exited", exitCode);
        }
    }
}
