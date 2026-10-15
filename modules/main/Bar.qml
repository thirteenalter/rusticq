import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../config"
import "../../services"

// All bar modes share ONE set of functional components. Switching modes
// never spawns a second bar, duplicates system watchers, or resets sidebar state.
PanelWindow {
    id: barWindow
    color: "transparent"

    readonly property bool cleanCompactMode: SettingsStore.barMode === "clean-compact"
    readonly property bool compactMode: SettingsStore.barMode === "compact" || cleanCompactMode
    readonly property int compactControlHeight: 24
    readonly property bool separatedMode: SettingsStore.barMode === "separated"
    readonly property bool professionalMode: SettingsStore.barMode === "professional"
    readonly property bool simpleMode: SettingsStore.barMode === "simple"
    readonly property int barHeight: professionalMode ? 44 : separatedMode ? 40 : compactMode ? 36 : 38
    readonly property int groupPadding: separatedMode ? 12 : compactMode ? 3 : professionalMode ? 14 : 9
    readonly property int groupSpacing: cleanCompactMode ? Theme.barInfoGap : compactMode ? 5 : 9

    implicitHeight: barHeight
    IdleInhibitor {
        window: barWindow
        enabled: QuickModesService.keepAwake
    }
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
                    backgroundEnabled: !barWindow.cleanCompactMode
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Store.toggleAi(barWindow.screen)
                    }
                }
                Workspaces {
                    backgroundEnabled: !barWindow.cleanCompactMode
                    buttonSize: barWindow.compactMode ? barWindow.compactControlHeight : 23
                    spacing: barWindow.compactMode ? barWindow.groupSpacing : 6
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
                Rectangle {
                    id: infoTray
                    visible: !barWindow.simpleMode
                    readonly property int trayPadding: barWindow.compactMode && !barWindow.cleanCompactMode ? 8 : 0
                    Layout.preferredWidth: infoItems.implicitWidth + trayPadding * 2
                    Layout.preferredHeight: barWindow.compactMode ? barWindow.compactControlHeight : infoItems.implicitHeight
                    radius: height / 2
                    color: barWindow.compactMode && !barWindow.cleanCompactMode ? Theme.borderaccent : "transparent"
                    RowLayout {
                        id: infoItems
                        anchors.centerIn: parent
                        spacing: barWindow.compactMode ? Theme.barInfoGap : barWindow.groupSpacing
                        Weather {
                            visible: SettingsStore.showWeather
                            showIcon: barWindow.compactMode
                            horizontalPadding: barWindow.compactMode ? 0 : 7
                            verticalPadding: barWindow.compactMode ? 0 : 6
                            Layout.preferredWidth: implicitWidth
                            Layout.preferredHeight: barWindow.compactMode ? barWindow.compactControlHeight : implicitHeight
                        }
                        Clock {
                            showIcon: barWindow.compactMode
                            showDate: barWindow.compactMode
                            horizontalPadding: barWindow.compactMode ? 0 : 6
                            verticalPadding: barWindow.compactMode ? 0 : 6
                            Layout.preferredWidth: implicitWidth
                            Layout.preferredHeight: barWindow.compactMode ? barWindow.compactControlHeight : implicitHeight
                        }
                    }
                }
                Indicators {
                    compact: barWindow.compactMode
                    backgroundEnabled: !barWindow.cleanCompactMode
                    visible: SettingsStore.showIndicators && !barWindow.simpleMode
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: barWindow.compactMode ? barWindow.compactControlHeight : implicitHeight
                }
                QuickModes {
                    visible: SettingsStore.showQuickModes && hasModules
                    backgroundEnabled: !barWindow.cleanCompactMode
                    controlHeight: barWindow.compactControlHeight
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                }
                Rectangle {
                    id: sidebarToggle
                    Layout.preferredWidth: barWindow.compactMode ? 32 : 40
                    Layout.preferredHeight: barWindow.compactControlHeight
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
