import QtQuick
import QtQuick.Layouts
import "../config"

// Optional RusticQ-only menu; not a DBus global menu for the active app.
Item {
    id: root
    property bool vertical: false
    signal menuRequested(string section, var sourceItem)
    implicitWidth: vertical ? 40 : menuRow.implicitWidth
    implicitHeight: vertical ? 36 : 28

    RowLayout {
        id: menuRow
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 4
        Repeater {
            model: [
                {label: "File", key: "file", enabled: SettingsStore.showMenuFile},
                {label: "Edit", key: "edit", enabled: SettingsStore.showMenuEdit},
                {label: "View", key: "view", enabled: SettingsStore.showMenuView},
                {label: "Share", key: "share", enabled: SettingsStore.showMenuShare},
                {label: "Shell", key: "shell", enabled: SettingsStore.showMenuShell},
                {label: "Tools", key: "tools", enabled: SettingsStore.showMenuTools}
            ].filter(item => item.enabled)
            delegate: Rectangle {
                id: menuButton
                required property var modelData
                readonly property bool hovered: mouse.containsMouse
                Layout.preferredWidth: Math.max(44, label.implicitWidth + 18)
                Layout.preferredHeight: 28
                radius: 8
                color: hovered ? Theme.surface : "transparent"
                border.width: hovered ? 1 : 0
                border.color: Qt.alpha(Theme.accent, 0.28)
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: menuButton.modelData.label
                    color: menuButton.hovered ? Theme.accent : Theme.foreground
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(11)
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.menuRequested(menuButton.modelData.key, menuButton)
                }
            }
        }
    }

    Rectangle {
        id: verticalTrigger
        anchors.fill: parent
        visible: root.vertical
        radius: 10
        color: verticalMouse.containsMouse ? Theme.surface : "transparent"
        border.width: verticalMouse.containsMouse ? 1 : 0
        border.color: Qt.alpha(Theme.accent, 0.28)
        Icon { anchors.centerIn: parent; icon: "\ue5d2"; font.pixelSize: Fonts.scale(20); color: Theme.accent }
        MouseArea {
            id: verticalMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.menuRequested(SettingsStore.showMenuView ? "view" : SettingsStore.showMenuEdit ? "edit" : SettingsStore.showMenuShare ? "share" : SettingsStore.showMenuFile ? "file" : SettingsStore.showMenuShell ? "shell" : "tools", verticalTrigger)
        }
    }
}
