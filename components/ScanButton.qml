import QtQuick
import QtQuick.Layouts
import "../config"

Rectangle {
    id: root
    property bool scanning: false
    readonly property string label: scanning ? "Stop scan" : "Scan"
    signal clicked()
    implicitWidth: 100
    implicitHeight: 32
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    radius: 10
    color: Theme.surface
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
        Icon { icon: "\ue1aa"; font.pixelSize: 17; color: Theme.accent }
        Text {
            text: root.label
            color: Theme.foreground
            font.family: Fonts.poppins.name
            font.pixelSize: 11
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
