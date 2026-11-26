import QtQuick
import QtQuick.Layouts
import "../config"

// Optional RusticQ-only menu; not a DBus global menu for the active app.
Item {
    id: root
    property bool vertical: false
    property int verticalControlSize: 40
    signal menuRequested(string section, var sourceItem)
    signal menuHovered(string section, var sourceItem)
    implicitWidth: vertical ? verticalControlSize : menuRow.implicitWidth
    implicitHeight: vertical ? verticalControlSize : 28

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
            delegate: BarSurface {
                id: menuButton
                required property var modelData
                readonly property bool hovered: mouse.containsMouse
                Layout.preferredWidth: Math.max(44, label.implicitWidth + 18)
                Layout.preferredHeight: 28
                baseRadius: 8
                baseColor: "transparent"
                feedbackColor: hovered ? Theme.surface : "transparent"
                feedbackBorderWidth: hovered ? 1 : 0
                feedbackBorderColor: Qt.alpha(Theme.accent, 0.28)
                GlassLabel {
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
                    onEntered: if (SettingsStore.barPopupsOnHover) root.menuHovered(menuButton.modelData.key,menuButton)
                    onClicked: root.menuRequested(menuButton.modelData.key, menuButton)
                }
            }
        }
    }

    BarSurface {
        id: verticalTrigger
        anchors.fill: parent
        visible: root.vertical
        baseRadius: 10
        baseColor: "transparent"
        feedbackColor: verticalMouse.containsMouse ? Theme.surface : "transparent"
        feedbackBorderWidth: verticalMouse.containsMouse ? 1 : 0
        feedbackBorderColor: Qt.alpha(Theme.accent, 0.28)
        Icon { anchors.centerIn: parent; icon: "\ue5d2"; font.pixelSize: Theme.barSymbolSize; color: Theme.accent }
        MouseArea {
            id: verticalMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: if (SettingsStore.barPopupsOnHover) root.menuHovered(SettingsStore.modeIconVisible("showMenuView") ? "view" : SettingsStore.modeIconVisible("showMenuEdit") ? "edit" : SettingsStore.modeIconVisible("showMenuShare") ? "share" : SettingsStore.modeIconVisible("showMenuFile") ? "file" : SettingsStore.modeIconVisible("showMenuShell") ? "shell" : "tools",verticalTrigger)
            onClicked: root.menuRequested(SettingsStore.modeIconVisible("showMenuView") ? "view" : SettingsStore.modeIconVisible("showMenuEdit") ? "edit" : SettingsStore.modeIconVisible("showMenuShare") ? "share" : SettingsStore.modeIconVisible("showMenuFile") ? "file" : SettingsStore.modeIconVisible("showMenuShell") ? "shell" : "tools", verticalTrigger)
        }
    }
}
