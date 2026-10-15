import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../../config"

// All four bar modes share ONE set of functional components. Switching modes
// never spawns a second bar, duplicates system watchers, or resets sidebar state.
PanelWindow {
    id: barWindow
    color: "transparent"

    readonly property bool compactMode: SettingsStore.barMode === "compact"
    readonly property bool separatedMode: SettingsStore.barMode === "separated"
    readonly property bool professionalMode: SettingsStore.barMode === "professional"
    readonly property bool simpleMode: SettingsStore.barMode === "simple"
    readonly property int barHeight: professionalMode ? 44 : separatedMode ? 40 : compactMode ? 36 : 38
    readonly property int groupPadding: separatedMode ? 12 : compactMode ? 3 : professionalMode ? 14 : 9
    readonly property int groupSpacing: compactMode ? 5 : 9

    implicitHeight: barHeight
    anchors { top: true; left: true; right: true }
    margins {
        top: professionalMode ? 0 : compactMode ? 5 : 10
        left: professionalMode ? 0 : 14
        right: professionalMode ? 0 : 14
    }

    Rectangle {
        anchors.fill: parent
        color: barWindow.professionalMode ? Theme.background : "transparent"
        border.width: barWindow.professionalMode ? 1 : 0
        border.color: Theme.borderaccent
        radius: 0
    }
    Rectangle {
        visible: barWindow.professionalMode
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(Theme.accent, 0.35)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: barWindow.professionalMode ? 17 : 0
        anchors.rightMargin: barWindow.professionalMode ? 17 : 0
        spacing: barWindow.compactMode ? 5 : 10

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: barWindow.professionalMode ? 36 : barWindow.barHeight
            Layout.preferredWidth: leftItems.implicitWidth + 2 * barWindow.groupPadding
            color: barWindow.separatedMode ? Theme.surface : "transparent"
            border.width: barWindow.separatedMode ? 1 : 0
            border.color: Theme.borderaccent
            radius: 12
            RowLayout {
                id: leftItems
                anchors.centerIn: parent
                spacing: barWindow.groupSpacing
                Arch {
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Store.toggleAi(barWindow.screen)
                    }
                }
                Workspaces {
                    visible: SettingsStore.showWorkspaces && !barWindow.simpleMode
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                }
            }
        }

        Item { Layout.fillWidth: true }
        Text {
            visible: barWindow.professionalMode && barWindow.width > 900
            text: "QUICKSHELL  /  GRUVBOX"
            font.family: Fonts.poppinsSB.name
            font.pixelSize: 10
            color: Theme.muted
            Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.fillWidth: true }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: barWindow.professionalMode ? 36 : barWindow.barHeight
            Layout.preferredWidth: rightItems.implicitWidth + 2 * barWindow.groupPadding
            color: barWindow.separatedMode ? Theme.surface : "transparent"
            border.width: barWindow.separatedMode ? 1 : 0
            border.color: Theme.borderaccent
            radius: 12
            RowLayout {
                id: rightItems
                anchors.centerIn: parent
                spacing: barWindow.groupSpacing
                Weather {
                    visible: SettingsStore.showWeather && !barWindow.simpleMode
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                }
                Clock {
                    visible: !barWindow.simpleMode
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                }
                Indicators {
                    visible: SettingsStore.showIndicators && !barWindow.simpleMode
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                }
                Rectangle {
                    id: sidebarToggle
                    Layout.preferredWidth: barWindow.compactMode ? 32 : 40
                    Layout.preferredHeight: 24
                    radius: height / 2
                    color: Store.sidebarVisible && Store.sidebarScreen === barWindow.screen
                           ? Qt.alpha(Theme.accent, 0.25) : Theme.borderaccent
                    Rectangle {
                        anchors.centerIn: parent
                        width: 20; height: 2; radius: 1
                        color: Theme.foreground
                        opacity: 0.75
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Store.toggleQuick(barWindow.screen)
                    }
                }
            }
        }
    }
    // The minimal mode uses a truly centered clock, instead of shifting it
    // based on unequal left/right control widths.
    Clock {
        visible: barWindow.simpleMode
        anchors.centerIn: parent
    }
}
