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
                {label: "File", key: "file", enabled: SettingsStore.modeIconVisible("showMenuFile")},
                {label: "Edit", key: "edit", enabled: SettingsStore.modeIconVisible("showMenuEdit")},
                {label: "View", key: "view", enabled: SettingsStore.modeIconVisible("showMenuView")},
                {label: "Share", key: "share", enabled: SettingsStore.modeIconVisible("showMenuShare")},
                {label: "Shell", key: "shell", enabled: SettingsStore.modeIconVisible("showMenuShell")},
                {label: "Tools", key: "tools", enabled: SettingsStore.modeIconVisible("showMenuTools")}
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
            onClicked: root.menuRequested(SettingsStore.modeIconVisible("showMenuView") ? "view" : SettingsStore.modeIconVisible("showMenuEdit") ? "edit" : SettingsStore.modeIconVisible("showMenuShare") ? "share" : SettingsStore.modeIconVisible("showMenuFile") ? "file" : SettingsStore.modeIconVisible("showMenuShell") ? "shell" : "tools", verticalTrigger)
        }
    }
}
