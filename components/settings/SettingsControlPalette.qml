import QtQuick
Palette {
    required property var design
    window:design.popover
    windowText:design.foreground
    base:design.popover
    text:design.foreground
    button:design.interactive
    buttonText:design.foreground
    highlight:design.accent
    highlightedText:"white"
    placeholderText:design.muted
    toolTipBase:design.popover
    toolTipText:design.foreground
}
