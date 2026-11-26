import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../modules/bar"
import "../../components"

// One anchored layer surface supports click, hover and keyboard opening.
// It owns keyboard focus and a single compositor outside-click grab.
PanelWindow {
    id: popup
    WlrLayershell.namespace: "rusticq-popups"
    screen: hostWindow ? hostWindow.screen : null
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    readonly property bool grabFocus: kind !== ""
    property bool keyboardPrimed: false
    WlrLayershell.keyboardFocus: popup.grabFocus ? (popup.keyboardPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
    Timer {
        id: keyboardPrime
        interval: 75
        onTriggered: if (popup.grabFocus) {
            popup.keyboardPrimed = true;
            // The mode change itself can clear a compositor grab. Wait until
            // that Wayland commit has settled before arming outside dismissal.
            armDismissal.restart();
        }
    }
    onBackingWindowVisibleChanged: if (backingWindowVisible && grabFocus) keyboardPrime.restart()
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
                                                 Math.max(198, widgetLoader.item ? widgetLoader.item.implicitHeight : 450))
                    : contentKind === "ethernet" ? Math.max(220, widgetLoader.item ? widgetLoader.item.implicitHeight : 260) : contentKind === "bluetooth" ? 375 : contentKind === "battery" ? 405 :
                    contentKind === "weather" ? Math.min(hostWindow && hostWindow.screen ? Math.max(180, hostWindow.screen.height - 95) : 700,
                        Math.max(230, (widgetLoader.item ? widgetLoader.item.implicitHeight : 320)))
                    : contentKind === "menu" ? (menuSection === "share" ? 530 : 345) : contentKind === "audio" ? Math.min(620, Math.max(140, (widgetLoader.item ? widgetLoader.item.implicitHeight : 180))) : 190
    function hostInset(edge) {
        return hostWindow && hostWindow.margins ? Number(hostWindow.margins[edge]) || 0 : 0;
    }
    readonly property real hostX: hostWindow && hostWindow.anchors && hostWindow.anchors.right && !hostWindow.anchors.left
        ? (screen ? screen.width : 0) - hostInset("right") - hostWindow.width : hostInset("left")
    readonly property real hostY: hostWindow && hostWindow.anchors && hostWindow.anchors.bottom && !hostWindow.anchors.top
        ? (screen ? screen.height : 0) - hostInset("bottom") - hostWindow.height : hostInset("top")
    readonly property real desiredX: barPosition === "left" ? hostX + (hostWindow ? hostWindow.width : 0) + 8
        : barPosition === "right" ? hostX - implicitWidth - 8
        : contentKind === "menu" ? hostX + 14 : hostX + targetX - implicitWidth / 2
    readonly property real desiredY: barPosition === "top" ? hostY + (hostWindow ? hostWindow.barHeight : 0) + 8
        : barPosition === "bottom" ? hostY - implicitHeight - 1 : hostY + targetY - implicitHeight / 2
    margins.left: Math.round(Math.max(8,Math.min((screen ? screen.width : implicitWidth+16)-implicitWidth-8,desiredX)))
    margins.top: Math.round(Math.max(8,Math.min((screen ? screen.height : implicitHeight+16)-implicitHeight-8,desiredY)))
    mask: Region { item: popup.grabFocus ? popupSurface : null }
    property bool dismissalArmed: false
    Timer {
        id: armDismissal
        interval: 80
        onTriggered: popup.dismissalArmed = popup.kind !== "" && popup.visible
    }
    HyprlandFocusGrab {
        id: outsideGrab
        active: popup.kind !== "" && popup.visible && popup.dismissalArmed
        windows: [popup]
        onCleared: if (popup.dismissalArmed && popup.kind !== "") popup.dismissed()
    }
    readonly property bool outsideGrabActive: outsideGrab.active
    readonly property bool presented: motion.presented
    visible: presented && hostWindow !== null && hostWindow.visible
    onKindChanged: if (kind !== "") {
        dismissalArmed = false;
        armDismissal.stop();
        keyboardPrimed = false;
        keyboardPrime.restart();
        retainedKind = kind;
        motion.replay();
    } else {
        keyboardPrime.stop();
        keyboardPrimed = false;
        armDismissal.stop();
        dismissalArmed = false;
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
    // Release this panel's focus grab before the QR overlay acquires its own.
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
        function onBarPopupOpened(owner) {
            if (owner !== popup.hostWindow && popup.kind !== "") popup.dismissed();
        }
        function onSidebarVisibleChanged() { if (Store.sidebarVisible && popup.kind !== "") popup.dismissed(); }
        function onLauncherVisibleChanged() { if (Store.launcherVisible && popup.kind !== "") popup.dismissed(); }
        function onAiVisibleChanged() { if (Store.aiVisible && popup.kind !== "") popup.dismissed(); }
        function onPowerMenuVisibleChanged() { if (Store.powerMenuVisible && popup.kind !== "") popup.dismissed(); }
        function onDeviceSettingsRequested() {
            if (popup.visible) popup.dismissed();
        }
    }

    GlassSurface {
        Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
        surfaceRole: "popup"
        id: popupSurface
        Keys.onEscapePressed: popup.dismissed()
        anchors.fill: parent
        transform: Translate { x: motion.offsetX; y: motion.offsetY }
        radius: Theme.surfaceRadius(popup.contentKind==="notifications"?"notifications":"popovers","popup", Theme.sectionRadius)
        color: Theme.surfaceColor(popup.contentKind==="notifications"?"notifications":"popovers","popup", Theme.background)
        border.width: Theme.surfaceBorderWidth(popup.contentKind==="notifications"?"notifications":"popovers","popup", popup.singleSystem ? 0 : 1)
        border.color: Theme.surfaceBorder(popup.contentKind==="notifications"?"notifications":"popovers","popup", Theme.borderaccent)
        Loader {
            id: widgetLoader
            onLoaded: if (popup.kind === "menu") Qt.callLater(popup.focusMenu)
            anchors.fill: parent
            // Loaded cards own their content inset; do not double-pad them.
            anchors.margins: 0
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
    Component { id: wifiComponent; NetworkPanel {
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
