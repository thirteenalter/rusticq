import QtQuick
import Quickshell

// Each desktop card is its own anchored Bottom-layer window.
// A drag gesture changes only that widget's position on its monitor.
Scope {
    id: root
    property var screen
    DesktopWidgetWindow { kind: "clock"; screen: root.screen }
    DesktopWidgetWindow { kind: "calendar"; screen: root.screen }
    DesktopWidgetWindow { kind: "system"; screen: root.screen }
    DesktopWidgetWindow { kind: "media"; screen: root.screen }
    DesktopWidgetWindow { kind: "weather"; screen: root.screen }
    DesktopWidgetWindow { kind: "connectivity"; screen: root.screen }
    DesktopWidgetWindow { kind: "notes"; screen: root.screen }
    DesktopWidgetWindow { kind: "kanban"; screen: root.screen }
    DesktopWidgetWindow { kind: "randomImage"; screen: root.screen }
}
