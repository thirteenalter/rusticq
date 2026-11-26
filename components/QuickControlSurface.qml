import QtQuick
import QtQuick.Window
import "../config"

Rectangle {
    id: root
    property bool selected: false
    property bool hovered: false
    property bool pressed: false
    property bool registerInput: true
    opacity: enabled ? 1 : 0.45
    readonly property var quickWindow: Window.window
    radius: QuickControlStyle.radius
    color: QuickControlStyle.surface(selected,hovered,pressed)
    border.width: SettingsStore.quickControlComponentOutline || activeFocus ? 1 : 0
    border.color: activeFocus ? Theme.accent : Theme.glassEnabled ? Theme.glassBorderColor : Qt.alpha(Theme.foreground,.18)
    Behavior on color {enabled:QuickControlStyle.motion;ColorAnimation{duration:Theme.motionFastDuration}}
    scale: pressed ? .98 : 1
    Behavior on scale {enabled:QuickControlStyle.motion;NumberAnimation{duration:100;easing.type:Easing.OutCubic}}
    Component.onCompleted: if(registerInput)Store.addQuickControlInput(root)
    Component.onDestruction: Store.removeQuickControlInput(root)
}
