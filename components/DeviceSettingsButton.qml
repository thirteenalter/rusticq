import QtQuick
import QtQuick.Layouts
import "../config"

Rectangle {
    id: root
    property string kind: "wifi"
    property string section: ""
    property string label: "Advanced settings"
    property string symbol: "\ue8b8"
    property var targetScreen: null
    property bool iconOnly: false
    property bool fullscreen: false
    implicitHeight: 34
    implicitWidth: iconOnly ? 34 : labelText.implicitWidth + 52
    radius: Theme.rowRadius
    color: Theme.surface
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    function open() { Store.openDeviceSettings(kind, targetScreen || Store.sidebarScreen, section, fullscreen); }
    Accessible.onPressAction: open()
    Keys.onReturnPressed: open()
    Keys.onSpacePressed: open()
    RowLayout {
        anchors.centerIn: parent
        spacing: 7
        Icon { icon: root.symbol; color: Theme.accent; font.pixelSize: Fonts.scale(16) }
        Text { id: labelText; visible: !root.iconOnly; text: root.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Theme.helperTextSize }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.open() }
}
