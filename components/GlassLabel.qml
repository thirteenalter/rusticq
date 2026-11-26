import QtQuick
import "../config"

// A small local contrast guard for translucent content. It leaves the glyph
// opaque and sharp, without adding another background or changing its palette.
Text {
    id: settingsScopedRoot
    readonly property var settingsTheme: SettingsMaterial.forItem(settingsScopedRoot)
    style: settingsScopedRoot.settingsTheme.glassEnabled && !settingsScopedRoot.settingsTheme.lightPalette ? Text.Raised : Text.Normal
    styleColor: settingsScopedRoot.settingsTheme.glassTextShadow
}
