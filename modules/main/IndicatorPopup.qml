import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../modules/bar"
import "../../components"

// This is a separate lightweight window, reusing the *same* Quick Control
// widgets instead of reimplementing Wi-Fi / Bluetooth / Battery logic.
PopupWindow {
    id: popup
    required property var hostWindow
    property string kind: ""
    property real targetX: 0
    signal dismissed()
    // QsWindow.width/height are actual dimensions; Quickshell 0.3.1 requires
    // implicitWidth/implicitHeight for requested window sizes.
    implicitWidth: 368
    implicitHeight: kind === "wifi" ? 465 : kind === "bluetooth" ? 375 : kind === "battery" ? 405 :
                    kind === "weather" ? 262 : kind === "date" ? 370 : kind === "time" ? 198 : 190
    anchor.window: hostWindow
    // Anchor is in panel-window coordinates, never a QQuickItem or screen pixel.
    anchor.rect.x: Math.max(8, Math.min(hostWindow.width - implicitWidth - 8,
                                         targetX - implicitWidth / 2))
    anchor.rect.y: hostWindow.barHeight + 10
    grabFocus: true
    // Keep visibility imperative. When Quickshell dismisses a grabFocus popup,
    // C++ may set visible=false, which would sever a declarative binding.
    visible: false
    onKindChanged: visible = kind !== ""
    onVisibleChanged: if (!visible && kind !== "") dismissed()
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: Theme.sectionRadius
        color: Theme.background
        border.width: 1
        border.color: Theme.borderaccent
        // One card fills one popup. The Loader owns explicit geometry so the
        // card never inherits the Quick Control accordion's collapsed height.
        Loader {
            id: widgetLoader
            anchors.fill: parent
            anchors.margins: 8
            sourceComponent: popup.kind === "wifi" ? wifiComponent :
                                 popup.kind === "bluetooth" ? bluetoothComponent :
                                 popup.kind === "battery" ? batteryComponent :
                                 popup.kind === "audio" ? audioComponent :
                                 popup.kind === "weather" ? weatherComponent :
                                 popup.kind === "time" ? timeComponent :
                                 popup.kind === "date" ? dateComponent : null
        }
    }
    // Non-collapsible: the mini popup contains only one feature, not an accordion.
    Component { id: wifiComponent; BarWifi { standalone: true } }
    Component { id: bluetoothComponent; BarBluetooth { standalone: true } }
    Component { id: batteryComponent; BarBattery { standalone: true } }
    Component { id: audioComponent; MiniAudio {} }
    Component { id: weatherComponent; MiniWeather {} }
    Component { id: timeComponent; MiniTime {} }
    Component { id: dateComponent; MiniDate {} }
}
