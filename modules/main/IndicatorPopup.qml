import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../modules/bar"
import "../../components"

// This is a separate lightweight window, reusing the same quick widgets.
PopupWindow {
    id: popup
    required property var hostWindow
    property string kind: ""
    property string menuSection: "view"
    readonly property bool singleSystem: kind === "wifi" || kind === "bluetooth" || kind === "battery"
    property real targetX: 0
    property real targetY: 0
    property string barPosition: "top"
    signal dismissed()
    implicitWidth: kind === "task" ? 480 : kind === "menu" ? 358 : 368
    implicitHeight: kind === "task" ? 585 : kind === "wifi" ? 465 : kind === "bluetooth" ? 375 : kind === "battery" ? 405 :
                    kind === "weather" ? 262 : kind === "date" ? 370 : kind === "time" ? 198 : kind === "menu" ? 345 : kind === "audio" ? ((widgetLoader.item && widgetLoader.item.advancedOpen) ? 407 : 286) : 190
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
    onVisibleChanged: if (!visible && kind !== "") dismissed()
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: Theme.sectionRadius
        color: Theme.background
        border.width: popup.singleSystem ? 0 : 1
        border.color: Theme.borderaccent
        Loader {
            id: widgetLoader
            anchors.fill: parent
            anchors.margins: popup.singleSystem ? 0 : 8
            sourceComponent: popup.kind === "task" ? taskComponent : popup.kind === "wifi" ? wifiComponent :
                                 popup.kind === "bluetooth" ? bluetoothComponent :
                                 popup.kind === "battery" ? batteryComponent :
                                 popup.kind === "audio" ? audioComponent :
                                 popup.kind === "weather" ? weatherComponent :
                                 popup.kind === "time" ? timeComponent :
                                 popup.kind === "date" ? dateComponent :
                                 popup.kind === "menu" ? menuComponent : null
        }
    }

    Component { id: taskComponent; SystemDashboard {} }
    Component { id: wifiComponent; BarWifi { standalone: true } }
    Component { id: bluetoothComponent; BarBluetooth { standalone: true } }
    Component { id: batteryComponent; BarBattery { standalone: true } }
    Component { id: audioComponent; MiniAudio {} }
    Component { id: weatherComponent; MiniWeather {} }
    Component { id: timeComponent; MiniTime {} }
    Component { id: dateComponent; MiniDate {} }
    Component { id: menuComponent; ContextMenu { section: popup.menuSection; onActionFinished: popup.dismissed() } }
}
