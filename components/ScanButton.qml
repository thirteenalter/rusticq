import QtQuick
import QtQuick.Layouts
import "../config"

Rectangle {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    property bool scanning: false
    readonly property string label: scanning ? "Stop scan" : "Scan"
    signal clicked()
    implicitWidth: 100
    implicitHeight: 32
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    radius: root.settingsTheme.glassRadius("control", 10)
    color: root.settingsTheme.glassColor("control", pointer.containsMouse ? Qt.alpha(root.settingsTheme.accent, 0.12) : root.settingsTheme.surface)
    scale: pointer.pressed ? 0.98 : 1
    Behavior on color { enabled: root.settingsTheme.motionEnabled; ColorAnimation { duration: root.settingsTheme.motionFastDuration } }
    Behavior on scale { enabled: root.settingsTheme.motionEnabled; NumberAnimation { duration: root.settingsTheme.motionFastDuration; easing.type: Easing.OutCubic } }
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()

    RowLayout {
        anchors.centerIn: parent
        spacing: 5
        Icon { icon: "\ue1aa"; font.pixelSize: Fonts.scale(17); color: root.settingsTheme.accent }
        GlassLabel {
            text: root.label
            color: root.settingsTheme.foreground
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(11)
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
