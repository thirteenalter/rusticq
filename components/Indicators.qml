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
    horizontalPadding: !backgroundEnabled ? 0 : compact ? 5 : 6
    verticalPadding: compact ? 3 : 7

    function notify(kind, item) {
        const center = item.mapToItem(root, item.width / 2, item.height / 2);
        iconClicked(kind, center.x);
    }
    RowLayout {
        spacing: SettingsStore.spacingGroup("right", root.compact ? 3 : 4)
        Bluetooth {
            id: btIndicator
            Layout.leftMargin: SettingsStore.spacingIcon("right", "bluetooth", "before")
            Layout.rightMargin: SettingsStore.spacingIcon("right", "bluetooth", "after")
            visible: SettingsStore.showBluetooth
            forceDetails: root.cleanStyle && root.showDetails
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            cleanStyle: root.cleanStyle
            onActivated: root.notify("bluetooth", btIndicator)
        }
        Wifi {
            id: wifiIndicator
            Layout.leftMargin: SettingsStore.spacingIcon("right", "wifi", "before")
            Layout.rightMargin: SettingsStore.spacingIcon("right", "wifi", "after")
            visible: SettingsStore.showWifi
            forceDetails: root.cleanStyle && root.showDetails
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            cleanStyle: root.cleanStyle
            onActivated: root.notify("wifi", wifiIndicator)
        }
        Battery {
            id: batteryIndicator
            Layout.leftMargin: SettingsStore.spacingIcon("right", "battery", "before")
            Layout.rightMargin: SettingsStore.spacingIcon("right", "battery", "after")
            visible: SettingsStore.showBattery
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            cleanStyle: root.cleanStyle
            onActivated: root.notify("battery", batteryIndicator)
        }
        Audio {
            id: audioIndicator
            Layout.leftMargin: SettingsStore.spacingIcon("right", "audio", "before")
            Layout.rightMargin: SettingsStore.spacingIcon("right", "audio", "after")
            visible: SettingsStore.showAudio
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            cleanStyle: root.cleanStyle
            onActivated: root.notify("audio", audioIndicator)
        }
    }
}
