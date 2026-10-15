import Quickshell
import Quickshell.Networking
import QtQuick

// ============================================================
// WifiManager.qml
// Service layer - NO UI dependencies (no Theme, no Fonts, etc.)
// ============================================================

Scope {
    id: root

    // ===== Public Properties =====

    property var wifiDevice: {
        const vals = Networking.devices.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].type === DeviceType.Wifi)
                return vals[i];
        }
        return null;
    }

    property bool scanning: wifiDevice ? wifiDevice.scannerEnabled : false
    property bool wifiEnabled: Networking.wifiEnabled
    property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    property var processingNetwork: null

    // ===== Private =====

    Timer {
        id: processingResetTimer
        interval: 15000
        onTriggered: root.processingNetwork = null
    }

    onWifiDeviceChanged: {
        if (wifiDevice) {
            console.log("[WifiManager] Device found:", wifiDevice.name);
            wifiDevice.scannerEnabled = true;
        } else {
            console.log("[WifiManager] No WiFi device found");
        }
    }

    // ===== Public Functions =====

    function scan() {
        if (wifiDevice) {
            console.log("[WifiManager] Scanning...");
            // Restart a scan if it is already active.
            wifiDevice.scannerEnabled = false;
            wifiDevice.scannerEnabled = true;
        }
    }

    function toggleScan() {
        if (wifiDevice && wifiEnabled && wifiHardwareEnabled)
            wifiDevice.scannerEnabled = !wifiDevice.scannerEnabled;
    }

    Component.onDestruction: {
        if (wifiDevice) wifiDevice.scannerEnabled = false;
    }

    function connectNetwork(network) {
        if (!network) { console.log("[WifiManager] connectNetwork: null"); return; }
        processingNetwork = network;
        processingResetTimer.start();
        console.log("[WifiManager] Connecting to:", network.name);
        network.connect();
    }

    function connectWithPassword(network, password) {
        if (!network) { console.log("[WifiManager] connectWithPassword: null"); return; }
        processingNetwork = network;
        processingResetTimer.start();
        if (network.security === WifiSecurityType.Open) {
            console.log("[WifiManager] Open network:", network.name);
            network.connect();
        } else if (password.length > 0) {
            network.connectWithPsk(password);
        } else {
            root.clearProcessing(network);
        }
    }

    function disconnectNetwork(network) {
        if (!network) { console.log("[WifiManager] disconnectNetwork: null"); return; }
        processingNetwork = network;
        processingResetTimer.start();
        console.log("[WifiManager] Disconnecting:", network.name);
        network.disconnect();
    }

    function forgetNetwork(network) {
        if (!network) { console.log("[WifiManager] forgetNetwork: null"); return; }
        processingNetwork = network;
        processingResetTimer.start();
        console.log("[WifiManager] Forgetting:", network.name);
        network.forget();
    }

    function refresh() { scan(); }

    // Lets the UI clear the "processing" (spinner/disabled buttons) state for a
    // network as soon as it knows the attempt is over (e.g. connectionFailed),
    // instead of waiting the full 15s for processingResetTimer.
    function clearProcessing(network) {
        if (processingNetwork === network)
            processingNetwork = null;
    }

    function toggleWifi() {
        console.log("[WifiManager] Toggle WiFi:", !Networking.wifiEnabled);
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // ===== UI Helpers (return primitives only, no Theme) =====

    function signalIcon(strength) {
        if (strength >= 0.75) return "\ue1d8";
        if (strength >= 0.50) return "\uebe1";
        if (strength >= 0.25) return "\uebd6";
        return "\uebe4";
    }

    function securityIcon(security) {
        return security === WifiSecurityType.Open ? "" : "\ue899";
    }

    function stateText(network) {
        if (!network) return "";
        if (network.connected) return "Connected";
        if (network.state === ConnectionState.Connecting) return "Connecting...";
        if (network.state === ConnectionState.Disconnecting) return "Disconnecting...";
        if (network.known) return "Saved";
        if (network.security === WifiSecurityType.Open) return "Open";
        if (network.security === WifiSecurityType.Unknown) return "Security unknown";
        return "Password required";
    }

    // Return string color names instead of Theme colors
    function stateColorName(network) {
        if (!network) return "foreground";
        if (network.connected || network.state === ConnectionState.Connecting)
            return "accent";
        return "muted";
    }

    // Human-readable reason for a failed connection attempt (Network.connectionFailed)
    function failReasonText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "Incorrect password";
        case ConnectionFailReason.WifiAuthTimeout:
            return "Authentication timed out";
        case ConnectionFailReason.WifiNetworkLost:
            return "Network is out of range";
        case ConnectionFailReason.WifiClientFailed:
            return "Wi-Fi connection failed";
        case ConnectionFailReason.WifiClientDisconnected:
            return "Disconnected before finishing";
        default:
            return "Couldn't connect";
        }
    }
}
