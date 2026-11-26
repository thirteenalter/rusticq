import QtQuick
import "../config"

// One material resolver for the unified canvas or either detached box.
GlassSurface {
    id: root
    property string part: "main"
    readonly property bool inputPart: part === "input"
    readonly property bool separate: part !== "main"
    readonly property bool backgroundVisible: separate
        ? (inputPart ? SettingsStore.detachedLauncherInputBackgroundEnabled : SettingsStore.detachedLauncherResultsBackgroundEnabled)
        : SettingsStore.launcherBackgroundEnabled
    readonly property bool outlineVisible: separate
        ? (inputPart ? SettingsStore.detachedLauncherInputOutlineEnabled : SettingsStore.detachedLauncherResultsOutlineEnabled)
        : SettingsStore.launcherOutlineEnabled
    readonly property bool materialGlass: Theme.glassEnabled && SettingsStore.launcherGlassmorphismEnabled
        && SettingsStore.launcherMaterialMode !== "solid" && (!separate
            || (inputPart ? SettingsStore.detachedLauncherInputGlassEnabled : SettingsStore.detachedLauncherResultsGlassEnabled))
    readonly property bool inheritedMaterial: !separate || (inputPart ? SettingsStore.detachedLauncherInputInheritMaterial : SettingsStore.detachedLauncherResultsInheritMaterial)
    readonly property real requestedOpacity: inheritedMaterial ? SettingsStore.launcherOpacity
        : inputPart ? SettingsStore.detachedLauncherInputOpacity : SettingsStore.detachedLauncherResultsOpacity
    readonly property real materialAlpha: requestedOpacity < 0 ? Theme.glassPopup.a : Math.max(requestedOpacity,
        Store.launcherBlurActive && !Theme.glassEconomy ? 0.15 : 0.86)
    readonly property real shadowIntensity: inheritedMaterial ? SettingsStore.glassShadowIntensity
        : inputPart ? SettingsStore.detachedLauncherInputShadowIntensity : SettingsStore.detachedLauncherResultsShadowIntensity
    surfaceRole: "popup"
    color: !backgroundVisible ? "transparent" : materialGlass ? Qt.alpha(Theme.glassTint,materialAlpha) : Theme.background
    radius: separate ? (inputPart ? SettingsStore.detachedLauncherInputRadius : SettingsStore.detachedLauncherResultsRadius)
        : SettingsStore.launcherCornerRadius >= 0 ? SettingsStore.launcherCornerRadius : SettingsStore.glassCornerRadius
    border.width: outlineVisible ? 1 : 0
    border.color: materialGlass ? Theme.glassBorderColor : Theme.borderaccent
    reflectionsEnabled: materialGlass && outlineVisible && SettingsStore.launcherHighlightsEnabled && Theme.glassReflections
        && (!separate || (inputPart ? SettingsStore.detachedLauncherInputHighlights : SettingsStore.detachedLauncherResultsHighlights))
    shadowsEnabled: materialGlass && backgroundVisible && shadowIntensity>0 && Theme.glassShadows
    materialShadowColor: Qt.alpha(Theme.shadow,Theme.glassShadowAlpha(shadowIntensity))
}
