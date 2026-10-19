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
    property string menuSection: "view"
    readonly property bool singleSystem: kind === "wifi" || kind === "ethernet" || kind === "bluetooth" || kind === "battery" || kind === "audio" || kind === "notifications"
    property real targetX: 0
    property real targetY: 0
    property string barPosition: "top"
    signal dismissed()
    signal menuSectionNavigated(string sectionKey)
    implicitWidth: kind === "task" ? 480 : kind === "notifications" ? 405 : kind === "menu" ? 358 : 368
    // Wi-Fi popup fits content, including *all* Advanced controls, without a
    // second nested scroll viewport or an artificially tall empty footer.
    implicitHeight: kind === "task" ? 585 : kind === "wifi"
                    ? Math.min(hostWindow && hostWindow.screen ? Math.max(240, hostWindow.screen.height - 95) : 900,
                               Math.max(265, widgetLoader.item ? widgetLoader.item.implicitHeight : 405))
                    : kind === "notifications" ? Math.min(hostWindow && hostWindow.screen ? Math.max(360, hostWindow.screen.height - 92) : 670, 620)
                    : kind === "ethernet" ? 260 : kind === "bluetooth" ? 375 : kind === "battery" ? 405 :
                    kind === "weather" ? 262 : kind === "date" ? 370 : kind === "time" ? 198 : kind === "menu" ? (menuSection === "share" ? 530 : 345) : kind === "audio" ? Math.min(620, Math.max(140, (widgetLoader.item ? widgetLoader.item.implicitHeight : 180))) : 190
    anchor.window: hostWindow
    anchor.edges: barPosition === "bottom" ? (Edges.Bottom | Edges.Left) : (Edges.Top | Edges.Left)
    anchor.gravity: barPosition === "bottom" ? (Edges.Top | Edges.Right)
        : barPosition === "right" ? (Edges.Bottom | Edges.Left) : (Edges.Bottom | Edges.Right)
    // All Edit / View / Share / Shell menus share one aligned left-edge anchor.
    anchor.rect.x: barPosition === "left" ? hostWindow.width + 8 : barPosition === "right" ? -8
        : kind === "menu" ? 14
        : Math.max(8, Math.min(Math.max(8, hostWindow.width - implicitWidth - 8), targetX - implicitWidth / 2))
    anchor.rect.y: barPosition === "top" ? hostWindow.barHeight + 8
        : barPosition === "bottom" ? -1
        : Math.max(8, Math.min(Math.max(8, hostWindow.height - implicitHeight - 8), targetY - implicitHeight / 2))
    onTargetXChanged: if (visible) anchor.updateAnchor()
    onTargetYChanged: if (visible) anchor.updateAnchor()
    onBarPositionChanged: if (visible) anchor.updateAnchor()
    grabFocus: true
    visible: false
    onKindChanged: visible = kind !== ""
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

    Rectangle {
        anchors.fill: parent
        radius: Theme.sectionRadius
        color: Theme.background
        border.width: popup.singleSystem ? 0 : 1
        border.color: Theme.borderaccent
        Loader {
            id: widgetLoader
            onLoaded: if (popup.kind === "menu") Qt.callLater(popup.focusMenu)
            anchors.fill: parent
            anchors.margins: popup.singleSystem ? 0 : 8
            sourceComponent: popup.kind === "task" ? taskComponent : popup.kind === "wifi" ? wifiComponent :
                                 popup.kind === "ethernet" ? ethernetComponent : popup.kind === "bluetooth" ? bluetoothComponent :
                                 popup.kind === "battery" ? batteryComponent :
                                 popup.kind === "audio" ? audioComponent :
                                 popup.kind === "notifications" ? notificationsComponent :
                                 popup.kind === "weather" ? weatherComponent :
                                 popup.kind === "time" ? timeComponent :
                                 popup.kind === "date" ? dateComponent :
                                 popup.kind === "menu" ? menuComponent : null
        }
    }

    Component { id: taskComponent; SystemDashboard {} }
    Component { id: wifiComponent; BarWifi {
        standalone: true
        popupScreen: popup.hostWindow ? popup.hostWindow.screen : null
        onShareQrRequested: (screen, ssid) => popup.beginWifiQr(screen, ssid)
    } }
    Component { id: ethernetComponent; MiniEthernetInfo {} }
    Component { id: bluetoothComponent; BarBluetooth { standalone: true } }
    Component { id: batteryComponent; BarBattery { standalone: true } }
    Component { id: audioComponent; MiniAudio {} }
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
