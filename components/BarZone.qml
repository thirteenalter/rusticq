import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../config"
import "../services"

// One reusable, relocatable bar zone. Instantiates only icons assigned to this zone.
// This avoids duplicated service watchers and makes Left / Center / Right consistent.
Item {
    id: root
    required property var hostWindow
    property string zone: "left"
    property bool vertical: false
    property bool compact: false
    property bool clean: false
    property bool separated: false
    property bool professional: false
    property bool simple: false
    property int controlHeight: 24
    property bool hovered: zoneHover.hovered
    readonly property bool showDetails: !clean || SettingsStore.cleanRightMode === "details" ||
        (SettingsStore.cleanRightMode === "hover" && hovered)
    readonly property var keys: SettingsStore.iconsInZone(zone)
    readonly property var activeKeys: keys.filter(k => isEnabled(k))
    implicitWidth: activeKeys.length ? (vertical ? verticalColumn.implicitWidth + 8 : horizontalRow.implicitWidth + 10) : 0
    implicitHeight: activeKeys.length ? (vertical ? verticalColumn.implicitHeight : Math.max(controlHeight + (separated ? 8 : 0), horizontalRow.implicitHeight + (separated ? 8 : 0))) : 0
    HoverHandler { id: zoneHover }
    Rectangle {
        visible: root.separated && root.activeKeys.length > 0
        anchors.fill: parent
        radius: 12
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderaccent
        z: -1
    }
    function popup(kind, item, offset) {
        const point = hostWindow.mapFromItem(item, offset === undefined ? item.width / 2 : offset, item.height / 2);
        hostWindow.openMini(kind, point.x, point.y);
    }
    function componentFor(key) {
        switch (key) {
        case "rusticq": return rusticqPart;
        case "arch": return archPart;
        case "launcher": return launcherPart;
        case "menu": return menuPart;
        case "workspaces": return workspacePart;
        case "weather": return weatherPart;
        case "time": return timePart;
        case "date": return datePart;
        case "bluetooth": return bluetoothPart;
        case "wifi": return wifiPart;
        case "battery": return batteryPart;
        case "audio": return audioPart;
        case "barToggle": return barTogglePart;
        case "notifications": return notificationsPart;
        case "task": return taskPart;
        case "quickModes": return quickModesPart;
        case "quickControl": return controlPart;
        case "mic": return micPart;
        case "down": return downPart;
        case "up": return upPart;
        }
        return null;
    }
    function isEnabled(key) {
        const shown = propertyKey => SettingsStore.modeIconVisible(propertyKey);
        switch (key) {
        case "rusticq": return shown("showRusticQIcon");
        case "arch": return shown("showArch");
        case "launcher": return shown("showLauncher");
        case "menu": return shown("showMenuBar") && ["showMenuFile", "showMenuEdit", "showMenuView", "showMenuShare", "showMenuShell", "showMenuTools"].some(shown);
        case "workspaces": return shown("showWorkspaces");
        case "weather": return shown("showWeather");
        case "time": return shown("showTime");
        case "date": return shown("showDate");
        case "bluetooth": return shown("showIndicators") && shown("showBluetooth");
        case "wifi": return shown("showIndicators") && shown("showWifi");
        case "battery": return shown("showIndicators") && shown("showBattery") && BatteryService.available;
        case "audio": return shown("showIndicators") && shown("showAudio");
        case "barToggle": return shown("showBarToggleIcon");
        case "notifications": return shown("showNotificationIcon") && SettingsStore.showNotifications;
        case "task": return shown("showTaskView");
        case "quickModes": return shown("showQuickModes") && ["showKeepAwake", "showSilent", "showGamingMode", "showNightMode", "showMicMute"].some(shown);
        case "quickControl": return shown("showQuickControl");
        case "mic": return shown("showMicrophoneStatus");
        case "down": return shown("showDownloadSpeed");
        case "up": return shown("showUploadSpeed");
        }
        return false;
    }

    RowLayout {
        id: horizontalRow
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: SettingsStore.spacingGroup(root.zone, root.zone === "right" && root.compact ? 3 : root.compact ? 4 : 5)
        Repeater {
            model: root.vertical ? [] : root.activeKeys
            delegate: Loader {
                id: itemLoader
                required property string modelData
                sourceComponent: root.componentFor(modelData)
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: SettingsStore.spacingIcon(root.zone, modelData, "before")
                Layout.rightMargin: SettingsStore.spacingIcon(root.zone, modelData, "after")
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.preferredHeight: item ? item.implicitHeight : root.controlHeight
            }
        }
    }
    ColumnLayout {
        id: verticalColumn
        visible: root.vertical
        anchors.centerIn: parent
        spacing: SettingsStore.spacingGroup(root.zone, root.compact ? 3 : 6)
        Repeater {
            model: root.vertical ? root.activeKeys : []
            delegate: Loader {
                required property string modelData
                sourceComponent: root.componentFor(modelData)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: SettingsStore.spacingIcon(root.zone, modelData, "before")
                Layout.bottomMargin: SettingsStore.spacingIcon(root.zone, modelData, "after")
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.preferredHeight: item ? item.implicitHeight : 0
            }
        }
    }

    Component {
        id: rusticqPart
        Rectangle {
            implicitWidth: root.vertical ? 32 : root.compact ? 29 : 34
            implicitHeight: root.controlHeight
            radius: height / 2
            color: root.clean ? "transparent" : Theme.borderaccent
            RusticQIcon { anchors.centerIn: parent; iconSize: 18 }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.hostWindow.closeMini(); Store.showSettings("appearance", root.hostWindow.screen); }
            }
        }
    }
    Component {
        id: archPart
        Arch {
            backgroundEnabled: !root.clean
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.hostWindow.closeMini(); Store.toggleAi(root.hostWindow.screen); }
            }
        }
    }
    Component {
        id: launcherPart
        Rectangle {
            implicitWidth: root.vertical ? 32 : root.compact ? 29 : 34
            implicitHeight: root.controlHeight
            radius: height / 2
            color: root.clean ? "transparent" : Theme.borderaccent
            Icon { anchors.centerIn: parent; icon: "\ue8b6"; font.pixelSize: Fonts.scale(18); color: Theme.accent }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { root.hostWindow.closeMini(); Store.toggleLauncher(root.hostWindow.screen); }
            }
        }
    }
    Component {
        id: menuPart
        ContextMenuBar {
            vertical: root.vertical
            onMenuRequested: (section, item) => root.hostWindow.openMenu(section, item)
        }
    }
    Component {
        id: workspacePart
        Item {
            implicitWidth: root.vertical ? 32 : workspaceHorizontal.implicitWidth
            implicitHeight: root.vertical ? verticalWorkspaces.implicitHeight : workspaceHorizontal.implicitHeight
            Workspaces {
                id: workspaceHorizontal
                visible: !root.vertical
                backgroundEnabled: !root.clean
                buttonSize: root.compact ? root.controlHeight : 23
            }
            ColumnLayout {
                id: verticalWorkspaces
                visible: root.vertical
                spacing: 3
                Repeater {
                    model: 6
                    delegate: Rectangle {
                        id: cell
                        required property int index
                        readonly property int workspaceId: index + 1
                        readonly property bool focused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === workspaceId
                        Layout.preferredWidth: 30; Layout.preferredHeight: 27
                        radius: 8; color: focused ? Theme.accent : Theme.surface
                        Text { anchors.centerIn: parent; text: String(cell.workspaceId); color: cell.focused ? Theme.background : Theme.foreground; font.pixelSize: Fonts.scale(10) }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({ workspace = "' + cell.workspaceId + '" })' : 'workspace ' + cell.workspaceId)
                        }
                    }
                }
            }
        }
    }
    Component {
        id: weatherPart
        Weather {
            id: zoneWeather
            showDetails: root.showDetails && !root.vertical
            onActivated: offset => root.popup("weather", zoneWeather, offset)
        }
    }
    Component {
        id: timePart
        Clock {
            id: zoneTime
            showDate: false
            showTime: true
            showDetails: root.showDetails && !root.vertical
            onTimeActivated: offset => root.popup("time", zoneTime, offset)
        }
    }
    Component {
        id: datePart
        Clock {
            id: zoneDate
            showDate: true
            showTime: false
            showDetails: root.showDetails && !root.vertical
            onDateActivated: offset => root.popup("date", zoneDate, offset)
        }
    }
    Component {
        id: bluetoothPart
        Bluetooth {
            id: bluetoothZoneIcon
            cleanStyle: root.clean || root.vertical
            forceDetails: root.clean && root.showDetails && !root.vertical
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            onActivated: root.popup("bluetooth", bluetoothZoneIcon)
        }
    }
    Component {
        id: wifiPart
        Wifi {
            id: wifiZoneIcon
            cleanStyle: root.clean || root.vertical
            forceDetails: root.clean && root.showDetails && !root.vertical
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            onActivated: root.popup(WifiService.ethernetConnected ? "ethernet" : "wifi", wifiZoneIcon)
        }
    }
    Component {
        id: batteryPart
        Battery {
            id: batteryZoneIcon
            cleanStyle: root.clean || root.vertical
            showValue: !root.vertical
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            onActivated: root.popup("battery", batteryZoneIcon)
        }
    }
    Component {
        id: audioPart
        Audio {
            id: audioZoneIcon
            cleanStyle: root.clean || root.vertical
            showValue: !root.vertical
            iconSlotWidth: root.compact ? Theme.barIconSlotSize : 14
            onActivated: root.popup("audio", audioZoneIcon)
        }
    }
    Component {
        id: notificationsPart
        Rectangle {
            implicitWidth: root.vertical ? 32 : root.compact ? 29 : 32
            implicitHeight: root.controlHeight
            radius: height / 2
            color: root.clean ? "transparent" : Theme.borderaccent
            Icon {
                anchors.centerIn: parent
                icon: NotificationCenter.doNotDisturb ? "\ue7f6" : "\ue7f4"
                color: NotificationCenter.unread > 0 ? Theme.accent : Theme.foreground
                font.pixelSize: Fonts.scale(17)
            }
            Rectangle {
                visible: NotificationCenter.unread > 0
                anchors.right: parent.right; anchors.top: parent.top
                width: 7; height: 7; radius: 4
                color: Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.popup("notifications", parent)
            }
        }
    }
    Component {
        id: barTogglePart
        Rectangle {
            implicitWidth: root.vertical ? 32 : 30
            implicitHeight: root.controlHeight
            radius: height / 2
            color: root.clean ? "transparent" : Theme.borderaccent
            Icon {
                anchors.centerIn: parent
                icon: "\ue5cd"
                color: Theme.foreground
                font.pixelSize: Fonts.scale(17)
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.setBarVisible(false)
            }
        }
    }
    Component {
        id: taskPart
        Rectangle {
            implicitWidth: root.vertical ? 32 : root.compact ? 29 : 34
            implicitHeight: root.controlHeight
            radius: height / 2
            color: root.clean ? "transparent" : Theme.borderaccent
            Icon { anchors.centerIn: parent; icon: "\ue322"; font.pixelSize: Fonts.scale(18); color: Theme.accent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.popup("task", parent) }
        }
    }
    Component {
        id: quickModesPart
        QuickModes {
            targetScreen: root.hostWindow.screen
            backgroundEnabled: !root.clean
            controlHeight: root.controlHeight
        }
    }
    Component {
        id: controlPart
        Rectangle {
            readonly property bool filledStyle: SettingsStore.quickControlButtonStyle === "filled"
            implicitWidth: root.vertical ? 32 : root.compact ? 32 : 40
            implicitHeight: root.controlHeight
            radius: height / 2
            color: filledStyle ? Theme.borderaccent : "transparent"
            Icon { anchors.centerIn: parent; icon: "\ue69b"; font.pixelSize: Theme.barSymbolSize; color: filledStyle ? Theme.accent : Theme.foreground }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { root.hostWindow.closeMini(); Store.toggleQuick(root.hostWindow.screen); }
            }
        }
    }
    Component { id: micPart; BarSignal { kind: "mic"; vertical: root.vertical; showDetails: root.showDetails } }
    Component { id: downPart; BarSignal { kind: "down"; vertical: root.vertical; showDetails: root.showDetails } }
    Component { id: upPart; BarSignal { kind: "up"; vertical: root.vertical; showDetails: root.showDetails } }
}
