import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../services"
import "../../modules/bar"
import "../../components"

// This is a separate lightweight window, reusing the same quick widgets.
PopupWindow {
    id: popup
    required property var hostWindow
    property string kind: ""
    property string retainedKind: ""
    readonly property string contentKind: kind || retainedKind
    property string menuSection: "view"
    readonly property bool singleSystem: contentKind === "wifi" || contentKind === "ethernet" || contentKind === "bluetooth" || contentKind === "battery" || contentKind === "audio" || contentKind === "notifications"
    property real targetX: 0
    property real targetY: 0
    property string barPosition: "top"
    signal dismissed()
    signal menuSectionNavigated(string sectionKey)
    implicitWidth: contentKind === "task" ? 480 : contentKind === "notifications" ? 405 : contentKind === "menu" ? 358 : 368
    // Wi-Fi popup fits content, including *all* Advanced controls, without a
    // second nested scroll viewport or an artificially tall empty footer.
    implicitHeight: contentKind === "task" ? 585 : contentKind === "wifi"
                    ? Math.min(hostWindow && hostWindow.screen ? Math.max(240, hostWindow.screen.height - 95) : 900,
                               Math.max(265, widgetLoader.item ? widgetLoader.item.implicitHeight : 405))
                    : contentKind === "notifications" ? Math.min(hostWindow && hostWindow.screen ? Math.max(360, hostWindow.screen.height - 92) : 670, 620)
                    : contentKind === "time" || contentKind === "date" ? Math.min(hostWindow && hostWindow.screen ? Math.max(180, hostWindow.screen.height - 95) : 700,
                                                 Math.max(198, widgetLoader.item ? widgetLoader.item.implicitHeight + 16 : 450))
                    : contentKind === "ethernet" ? 260 : contentKind === "bluetooth" ? 375 : contentKind === "battery" ? 405 :
                    contentKind === "weather" ? 262 : contentKind === "menu" ? (menuSection === "share" ? 530 : 345) : contentKind === "audio" ? Math.min(620, Math.max(140, (widgetLoader.item ? widgetLoader.item.implicitHeight : 180))) : 190
    anchor.window: hostWindow
    anchor.edges: barPosition === "bottom" ? (Edges.Bottom | Edges.Left) : (Edges.Top | Edges.Left)
    anchor.gravity: barPosition === "bottom" ? (Edges.Top | Edges.Right)
        : barPosition === "right" ? (Edges.Bottom | Edges.Left) : (Edges.Bottom | Edges.Right)
    // All Edit / View / Share / Shell menus share one aligned left-edge anchor.
    anchor.rect.x: barPosition === "left" ? hostWindow.width + 8 : barPosition === "right" ? -8
        : contentKind === "menu" ? 14
        : Math.max(8, Math.min(Math.max(8, hostWindow.width - implicitWidth - 8), targetX - implicitWidth / 2))
    anchor.rect.y: barPosition === "top" ? hostWindow.barHeight + 8
        : barPosition === "bottom" ? -1
        : Math.max(8, Math.min(Math.max(8, hostWindow.height - implicitHeight - 8), targetY - implicitHeight / 2))
    onTargetXChanged: if (visible) anchor.updateAnchor()
    onTargetYChanged: if (visible) anchor.updateAnchor()
    onBarPositionChanged: if (visible) anchor.updateAnchor()
    onImplicitHeightChanged: if (visible) anchor.updateAnchor()
    grabFocus: kind !== ""
    readonly property bool presented: motion.presented
    visible: presented
    onKindChanged: if (kind !== "") {
        retainedKind = kind;
        motion.replay();
    }
    SurfaceMotion {
        id: motion
        shown: popup.kind !== ""
        target: popupSurface
        edge: popup.barPosition
        style: SettingsStore.barAnimationStyle
    }
    function focusMenu() {
        if (visible && kind === "menu" && widgetLoader.item && widgetLoader.item.forceActiveFocus)
            widgetLoader.item.forceActiveFocus();
    }
    onVisibleChanged: {
        if (!visible && kind !== "") dismissed();
        else if (visible && kind === "menu") Qt.callLater(focusMenu);
        else if (visible && kind === "notifications") NotificationCenter.markRead();
    }
    // PopupWindow's focus grab must be released BEFORE opening a Wlr Overlay.
    // Otherwise the old popup can clear the new overlay's grab instantly.
    property var pendingQrScreen: null
    property string pendingQrSsid: ""
    function beginWifiQr(screen, ssid) {
        pendingQrScreen = screen || (hostWindow ? hostWindow.screen : null);
        pendingQrSsid = String(ssid || "");
        dismissed();
        wifiQrDelay.restart();
    }
    Timer {
        id: wifiQrDelay
        interval: 260
        repeat: false
        onTriggered: Store.openWifiQr(popup.pendingQrScreen, popup.pendingQrSsid)
    }
    onMenuSectionChanged: if (visible && kind === "menu") Qt.callLater(focusMenu)
    color: "transparent"

    Connections {
        target: Store
        function onDeviceSettingsRequested() {
            if (popup.visible) popup.dismissed();
        }
    }

    Rectangle {
        id: popupSurface
        anchors.fill: parent
        transform: Translate { x: motion.offsetX; y: motion.offsetY }
        radius: Theme.sectionRadius
        color: Theme.background
        border.width: popup.singleSystem ? 0 : 1
        border.color: Theme.borderaccent
        Loader {
            id: widgetLoader
            onLoaded: if (popup.kind === "menu") Qt.callLater(popup.focusMenu)
            anchors.fill: parent
            anchors.margins: popup.singleSystem ? 0 : 8
            sourceComponent: popup.contentKind === "task" ? taskComponent : popup.contentKind === "wifi" ? wifiComponent :
                                 popup.contentKind === "ethernet" ? ethernetComponent : popup.contentKind === "bluetooth" ? bluetoothComponent :
                                 popup.contentKind === "battery" ? batteryComponent :
                                 popup.contentKind === "audio" ? audioComponent :
                                 popup.contentKind === "notifications" ? notificationsComponent :
                                 popup.contentKind === "weather" ? weatherComponent :
                                 popup.contentKind === "time" ? timeComponent :
                                 popup.contentKind === "date" ? dateComponent :
                                 popup.contentKind === "menu" ? menuComponent : null
        }
    }

    Component { id: taskComponent; SystemDashboard {} }
    Component { id: wifiComponent; BarWifi {
        standalone: true
        popupScreen: popup.hostWindow ? popup.hostWindow.screen : null
        onShareQrRequested: (screen, ssid) => popup.beginWifiQr(screen, ssid)
    } }
    Component { id: ethernetComponent; MiniEthernetInfo {} }
    Component { id: bluetoothComponent; BarBluetooth { standalone: true; targetScreen: popup.hostWindow ? popup.hostWindow.screen : null } }
    Component { id: batteryComponent; BarBattery { standalone: true; targetScreen: popup.hostWindow ? popup.hostWindow.screen : null } }
    Component { id: audioComponent; MiniAudio { targetScreen: popup.hostWindow ? popup.hostWindow.screen : null } }
    Component { id: notificationsComponent; BarNotifications { standalone: true; expanded: true } }
    Component { id: weatherComponent; MiniWeather {} }
    Component { id: timeComponent; MiniTime {} }
    Component { id: dateComponent; MiniDate {} }
    Component { id: menuComponent; ContextMenu {
        section: popup.menuSection
        onSectionNavigated: function(sectionKey) { popup.menuSectionNavigated(sectionKey); }
        onActionFinished: popup.dismissed()
    } }
}
