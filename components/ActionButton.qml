import QtQuick
import QtQuick.Layouts
import "../config"

Rectangle {
    id: button
    property string label: ""
    property string symbol: ""
    property bool selected: false
    property bool destructive: false
    readonly property color actionColor: destructive ? Theme.error : Theme.accent
    signal clicked()
    implicitHeight: 36
    implicitWidth: buttonContent.implicitWidth + 18
    radius: Theme.rowRadius
    color: selected || pointer.containsMouse || activeFocus ? Qt.alpha(actionColor, 0.16) : Theme.surface
    border.width: activeFocus ? 1 : 0
    border.color: actionColor
    opacity: enabled ? 1 : 0.45
    scale: pointer.pressed ? 0.98 : 1
    Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
    Behavior on scale { enabled: Theme.motionEnabled; NumberAnimation { duration: Theme.motionFastDuration; easing.type: Easing.OutCubic } }
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label || symbol
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()
    RowLayout {
        id: buttonContent
        anchors.centerIn: parent
        spacing: 5
        Icon { visible: button.symbol.length > 0; icon: button.symbol; color: button.actionColor; font.pixelSize: Fonts.scale(18) }
        Text { visible: button.label.length > 0; text: button.label; color: button.destructive ? button.actionColor : Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            button.forceActiveFocus();
            button.clicked();
        }
    }
}
