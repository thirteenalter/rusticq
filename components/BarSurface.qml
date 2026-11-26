import QtQuick
import "../config"

// Decoration only: never changes content, input, implicit size or window state.
GlassSurface {
    id: root
    property string barLayer: "module"
    property color feedbackColor: "transparent"
    property color feedbackBorderColor: Theme.accent
    property real feedbackBorderWidth: 0
    readonly property bool decorationBackgroundEnabled: Theme.barBackgroundVisible(barLayer)
    readonly property bool decorationOutlineEnabled: Theme.barOutlineVisible(barLayer)
    surfaceRole: barLayer === "module" ? "control" : "primary"
    baseBorderWidth: 0
    color: feedbackColor.a > 0 ? feedbackColor : Theme.barSurfaceColor(barLayer,baseColor)
    radius: Theme.barSurfaceRadius(barLayer,baseRadius,Math.min(width,height))
    border.width: feedbackBorderWidth > 0 ? feedbackBorderWidth : Theme.barSurfaceBorderWidth(barLayer,baseBorderWidth)
    border.color: feedbackBorderWidth > 0 ? feedbackBorderColor : Theme.barSurfaceBorder(barLayer,baseBorderColor)
    reflectionsEnabled: decorationBackgroundEnabled && decorationOutlineEnabled && Theme.barGlassActive && Theme.glassReflections
    shadowsEnabled: decorationBackgroundEnabled && Theme.barGlassActive && Theme.glassShadows
}
