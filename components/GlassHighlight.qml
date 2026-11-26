import QtQuick
import "../config"

// Bounded lighting and one top glint; no full-height shadow plate, duplicated
// frame, offscreen buffer or foreground blur. The parent owns the only border.
Item {
    id: root
    property real cornerRadius: Theme.sectionRadius
    property bool reflectionsEnabled: Theme.glassReflections
    property bool shadowsEnabled: Theme.glassShadows
    property bool edgeEnabled: true
    property color shadowColor: Theme.glassShadowColor
    enabled: false
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        visible: root.reflectionsEnabled
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.glassLighting }
            GradientStop { position: 0.20; color: "transparent" }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        x: Math.min(parent.width / 2, root.cornerRadius + 8)
        y: 0
        width: Math.max(0, parent.width - x * 2)
        height: 1
        visible: root.reflectionsEnabled && root.edgeEnabled
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.glassSpecular }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        x: Math.min(parent.width / 2, root.cornerRadius)
        y: parent.height - height - 1
        width: Math.max(0, parent.width - x * 2)
        height: 2
        radius: 1
        visible: root.shadowsEnabled
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: root.shadowColor }
        }
    }
}
