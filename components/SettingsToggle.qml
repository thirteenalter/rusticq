import QtQuick
import QtQuick.Layouts
import "../config"

// Reusable setting row; one persistent key per visible module or menu section.
Rectangle {
    id: root
    required property var modelData
    property bool perBarMode: false
    readonly property bool checked: perBarMode ? SettingsStore.modeIconVisible(modelData.key) : SettingsStore[modelData.key] === true
    Layout.fillWidth: true
    Layout.preferredHeight: 59
    radius: 12
    color: mouse.containsMouse ? Qt.alpha(Theme.accent, .075) : Theme.surface
    border.width: 1
    border.color: mouse.containsMouse ? Qt.alpha(Theme.accent, .3) : Qt.alpha(Theme.foreground, .045)
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        Rectangle {
            Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 10
            color: Qt.alpha(Theme.accent, root.checked ? .17 : .075)
            Icon { anchors.centerIn: parent; icon: root.modelData.icon; font.pixelSize: Fonts.scale(19); color: root.checked ? Theme.accent : Theme.muted }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: root.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); Layout.fillWidth: true; elide: Text.ElideRight }
            Text { text: root.modelData.desc; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); Layout.fillWidth: true; elide: Text.ElideRight }
        }
        Rectangle {
            Layout.preferredWidth: 38; Layout.preferredHeight: 21; radius: 11
            color: root.checked ? Theme.accent : Theme.borderaccent
            Rectangle {
                width: 15; height: 15; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? parent.width - width - 3 : 3
                color: root.checked ? Theme.background : Theme.muted
                Behavior on x { NumberAnimation { duration: 110 } }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.perBarMode) SettingsStore.setModeIconVisible(root.modelData.key, !root.checked);
            else { SettingsStore[root.modelData.key] = !root.checked; SettingsStore.save(); }
        }
    }
}
