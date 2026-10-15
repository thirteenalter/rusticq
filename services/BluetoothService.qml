pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth as Native

Singleton {
    id: root
    readonly property var adapter: Native.Bluetooth.defaultAdapter
    readonly property bool enabled: adapter !== null && adapter.enabled
    readonly property var connectedDevice: {
        const devices = Native.Bluetooth.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].connected) return devices[i];
        }
        return null;
    }
    readonly property bool connected: connectedDevice !== null
    readonly property string deviceName: connected ? connectedDevice.name : ""
    readonly property string address: connected ? connectedDevice.address : ""
    readonly property string icon: !enabled ? "\ue1a9" : connected ? "\ue1a8" : "\ue1a7"
}
