pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root
    // Prefer the actual laptop battery. On some machines DisplayDevice is a
    // synthetic aggregate and can briefly report a misleading low value.
    readonly property var battery: {
        const devices = UPower.devices.values;
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i];
            if (device.ready && device.isLaptopBattery && device.isPresent)
                return device;
        }
        const display = UPower.displayDevice;
        return display && display.ready && display.isPresent ? display : null;
    }
    readonly property bool available: battery !== null
    // Quickshell converts the UPower wire value (0..100) to 0..1.
    // Rounding the raw value was the root cause of the "1%" bug.
    readonly property int percentage: available && isFinite(battery.percentage)
        ? Math.max(0, Math.min(100, Math.round(battery.percentage * 100))) : 0
    // Battery state, NOT the inverse of UPower.onBattery (that includes full/idle).
    readonly property bool charging: available && (
        battery.state === UPowerDeviceState.Charging ||
        battery.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: available && battery.state === UPowerDeviceState.FullyCharged
    readonly property string status: !available ? "No battery" :
        full ? "Fully charged" : charging ? "Charging" :
        battery.state === UPowerDeviceState.Discharging ? "Discharging" :
        battery.state === UPowerDeviceState.PendingDischarge ? "Plugged in" : "Idle"
    readonly property real timeToFull: available ? battery.timeToFull : 0
    readonly property real timeToEmpty: available ? battery.timeToEmpty : 0
    readonly property string icon: {
        if (!available) return "\ue1a6"; // battery_unknown
        if (charging) return "\ue1a3";  // battery_charging_full
        if (percentage <= 10) return "\ue19c"; // battery_alert
        if (percentage < 25) return "\uf09c"; // battery_1_bar
        if (percentage < 40) return "\uf09d"; // battery_2_bar
        if (percentage < 55) return "\uf09f"; // battery_4_bar
        if (percentage < 75) return "\uf0a0"; // battery_5_bar
        if (percentage < 90) return "\uf0a1"; // battery_6_bar
        return "\ue1a4"; // battery_full
    }
}
