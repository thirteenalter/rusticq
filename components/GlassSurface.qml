import QtQuick
import "../config"

Rectangle {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    property string surfaceRole: "primary"
    property color baseColor: root.settingsTheme.background
    property real baseRadius: root.settingsTheme.sectionRadius
    property color baseBorderColor: root.settingsTheme.borderaccent
    property real baseBorderWidth: 1
    property bool reflectionsEnabled: root.settingsTheme.glassReflections
    property bool shadowsEnabled: root.settingsTheme.glassShadows
    property color materialShadowColor: root.settingsTheme.glassShadowColor
    color: root.settingsTheme.glassColor(surfaceRole, baseColor)
    radius: root.settingsTheme.glassRadius(surfaceRole, baseRadius)
    border.width: root.settingsTheme.glassBorderWidth(surfaceRole, baseBorderWidth)
    border.color: root.settingsTheme.glassBorder(surfaceRole, baseBorderColor)
    Loader {
        objectName: "glassSurfaceEffects"
        anchors.fill: parent
        active: root.visible && root.color.a > 0 && (root.reflectionsEnabled || root.shadowsEnabled)
            && ["primary", "popup", "tooltip", "modal", "authentication"].indexOf(root.surfaceRole) >= 0
        sourceComponent: GlassHighlight {
            cornerRadius: root.radius
            reflectionsEnabled: root.reflectionsEnabled
            shadowsEnabled: root.shadowsEnabled
            edgeEnabled: root.border.width > 0 && root.border.color.a > 0
            shadowColor: root.materialShadowColor
        }
    }
}
