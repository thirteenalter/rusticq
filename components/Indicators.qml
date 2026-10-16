import QtQuick
import QtQuick.Layouts
import "../config"

Pill {
    id: root
    signal iconClicked(string kind, real localX)
    property bool compact: false
    property bool backgroundEnabled: true
    property bool showDetails: true
    readonly property bool cleanStyle: compact && !backgroundEnabled
    color: backgroundEnabled ? Theme.borderaccent : "transparent"
    horizontalPadding: !backgroundEnabled ? 0 : compact ? 8 : 14
    verticalPadding: compact ? 3 : 7

    function notify(kind, item) {
        const center = item.mapToItem(root, item.width / 2, item.height / 2);
        iconClicked(kind, center.x);
    }
    RowLayout {
        spacing: root.cleanStyle ? Theme.barInfoGap : root.compact ? 8 : 12
        Bluetooth {
            id: btIndicator
            visible: SettingsStore.showBluetooth
            forceDetails: root.cleanStyle && root.showDetails
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            cleanStyle: root.cleanStyle
            onActivated: root.notify("bluetooth", btIndicator)
        }
        Wifi {
            id: wifiIndicator
            visible: SettingsStore.showWifi
            forceDetails: root.cleanStyle && root.showDetails
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            cleanStyle: root.cleanStyle
            onActivated: root.notify("wifi", wifiIndicator)
        }
        Battery {
            id: batteryIndicator
            visible: SettingsStore.showBattery
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            cleanStyle: root.cleanStyle
            onActivated: root.notify("battery", batteryIndicator)
        }
        Audio {
            id: audioIndicator
            visible: SettingsStore.showAudio
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            cleanStyle: root.cleanStyle
            onActivated: root.notify("audio", audioIndicator)
        }
    }
}
