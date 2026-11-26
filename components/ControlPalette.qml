import QtQuick
import "../config"

// Qt Controls consume the same resolved provider as hand-drawn shell controls.
Palette {
    id:root
    property var anchorItem:null
    readonly property var controlTheme:SettingsMaterial.forItem(anchorItem)
    window: root.controlTheme.background
    windowText: root.controlTheme.foreground
    base: root.controlTheme.glassColor("control", root.controlTheme.surface)
    alternateBase: root.controlTheme.surface
    text: root.controlTheme.foreground
    placeholderText: root.controlTheme.contentMuted
    button: root.controlTheme.surface
    buttonText: root.controlTheme.foreground
    brightText: root.controlTheme.foreground
    highlight: root.controlTheme.accent
    highlightedText: root.controlTheme.background
    toolTipBase: root.controlTheme.background
    toolTipText: root.controlTheme.foreground
    light: root.controlTheme.edge
    midlight: root.controlTheme.borderaccent
    mid: root.controlTheme.borderaccent
    dark: root.controlTheme.background
    shadow: root.controlTheme.shadow
    link: root.controlTheme.info
    linkVisited: root.controlTheme.info
}
