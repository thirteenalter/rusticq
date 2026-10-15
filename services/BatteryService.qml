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
    // Material Symbols Rounded from assets/google.ttf, verified in the
    // font cmap. Android family is continuous: 0=f30d, 1=f30c, ... 6=f307.
    readonly property string icon: {
        if (!available) return "\uf302"; // battery_android_question
        if (full) return "\uf304";       // battery_android_full
        if (charging) return "\uf305";   // battery_android_bolt
        if (percentage <= 3) return "\uf30d";  // battery_android_0
        if (percentage <= 15) return "\uf30c"; // battery_android_1
        if (percentage <= 30) return "\uf30b"; // battery_android_2
        if (percentage <= 45) return "\uf30a"; // battery_android_3
        if (percentage <= 60) return "\uf309"; // battery_android_4
        if (percentage <= 75) return "\uf308"; // battery_android_5
        if (percentage < 97) return "\uf307";  // battery_android_6
        return "\uf304"; // battery_android_full
    }
}
