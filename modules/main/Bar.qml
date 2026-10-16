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
    property string miniKind: ""
    property real miniAnchorX: 0
    property real miniAnchorY: 0
    property string menuSection: "view"
    function openMenu(section, item) {
        const same = miniKind === "menu" && menuSection === section && indicatorPopup.visible;
        if (same) { closeMini(); return; }
        const point = barWindow.mapFromItem(item, item.width / 2, item.height / 2);
        menuSection = section;
        miniAnchorX = point.x; miniAnchorY = point.y;
        miniKind = "menu";
    }
    function closeMini() { miniKind = ""; }
    function openMini(kind, xPosition, yPosition) {
        Store.sidebarVisible = false;
        if (miniKind === kind) { miniKind = ""; return; }
        // Position before changing kind so the new popup opens at the clicked icon.
        miniAnchorX = xPosition;
        miniAnchorY = yPosition === undefined ? barHeight / 2 : yPosition;
        miniKind = kind;
    }
    color: "transparent"

    readonly property string barPosition: SettingsStore.barPosition
    readonly property bool verticalMode: barPosition === "left" || barPosition === "right"
    onBarPositionChanged: closeMini()
    readonly property string activeLayout: SettingsStore.barMode
    onActiveLayoutChanged: closeMini()
    readonly property bool cleanCompactMode: SettingsStore.barMode === "clean-compact"
    readonly property bool compactMode: SettingsStore.barMode === "compact" || cleanCompactMode
    readonly property int compactControlHeight: 24
    readonly property bool separatedMode: SettingsStore.barMode === "separated"
    readonly property bool professionalMode: SettingsStore.barMode === "professional"
    readonly property bool simpleMode: SettingsStore.barMode === "simple"
    readonly property int barHeight: professionalMode ? 44 : separatedMode ? 40 : compactMode ? 36 : 38
    readonly property int groupPadding: separatedMode ? 12 : compactMode ? 3 : professionalMode ? 14 : 9
    readonly property int groupSpacing: cleanCompactMode ? Theme.barInfoGap : compactMode ? 5 : 9

    implicitWidth: verticalMode ? (simpleMode ? 48 : cleanCompactMode ? 44 : compactMode ? 52 : professionalMode ? 74 : Theme.verticalBarWidth) : 0
    implicitHeight: verticalMode ? 0 : barHeight
    IdleInhibitor {
        window: barWindow
        enabled: QuickModesService.keepAwake
    }
    anchors {
        top: barWindow.barPosition !== "bottom"
        bottom: barWindow.barPosition !== "top"
        left: barWindow.barPosition !== "right"
        right: barWindow.barPosition !== "left"
    }
    margins {
        top: SettingsStore.marginFor("top", verticalMode ? Theme.barEdgeGap : professionalMode ? 0 : compactMode ? 4 : 6)
        bottom: SettingsStore.marginFor("bottom", verticalMode ? Theme.barEdgeGap : barPosition === "bottom" && !professionalMode ? (compactMode ? 4 : 6) : 0)
        left: SettingsStore.marginFor("left", verticalMode ? (barPosition === "left" ? Theme.barEdgeGap : 0) : professionalMode ? 0 : 6)
        right: SettingsStore.marginFor("right", verticalMode ? (barPosition === "right" ? Theme.barEdgeGap : 0) : professionalMode ? 0 : 6)
    }

    Rectangle {
        anchors.fill: parent
        color: barWindow.verticalMode ? (barWindow.separatedMode || barWindow.cleanCompactMode ? "transparent" : Theme.background) : barWindow.professionalMode ? Theme.background : "transparent"
        border.width: (barWindow.verticalMode && !barWindow.separatedMode && !barWindow.cleanCompactMode) || (!barWindow.verticalMode && barWindow.professionalMode) ? 1 : 0
        border.color: Theme.borderaccent
        radius: barWindow.verticalMode && !barWindow.professionalMode ? 12 : 0
    }
    Rectangle {
        visible: barWindow.professionalMode && !barWindow.verticalMode
        anchors.bottom: barWindow.barPosition === "bottom" ? undefined : parent.bottom
        anchors.top: barWindow.barPosition === "bottom" ? parent.top : undefined
        width: parent.width
        height: 1
        color: Qt.alpha(Theme.accent, 0.35)
    }

    RowLayout {
        visible: !barWindow.verticalMode
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
                    visible: SettingsStore.showArch
                    backgroundEnabled: !barWindow.cleanCompactMode
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            barWindow.miniKind = "";
                            Store.toggleAi(barWindow.screen);
                        }
                    }
                }
                ContextMenuBar {
                    id: contextMenuBar
                    visible: SettingsStore.showMenuBar && barWindow.width > 980
                    vertical: false
                    onMenuRequested: (section, item) => barWindow.openMenu(section, item)
                    Layout.preferredWidth: visible ? implicitWidth : 0
                    Layout.preferredHeight: visible ? implicitHeight : 0
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
            visible: barWindow.professionalMode && barWindow.width > leftItems.implicitWidth + rightItems.implicitWidth + 340
            text: Theme.useAether ? "RUSTICQ  /  AETHER" : "RUSTICQ  /  GRUVBOX"
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
                HoverHandler { id: rightGroupHover }
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
                        spacing: Theme.barInfoGap
                        Weather {
                            id: trayWeather
                            onActivated: localX => {
                                const point = barWindow.mapFromItem(trayWeather, localX, 0);
                                barWindow.openMini("weather", point.x);
                            }
                            visible: SettingsStore.showWeather
                            showDetails: !barWindow.cleanCompactMode || SettingsStore.cleanRightMode === "details" || (SettingsStore.cleanRightMode === "hover" && rightGroupHover.hovered)
                            showIcon: barWindow.compactMode
                            horizontalPadding: barWindow.compactMode ? 0 : 7
                            verticalPadding: barWindow.compactMode ? 0 : 6
                            Layout.preferredWidth: implicitWidth
                            Layout.preferredHeight: barWindow.compactMode ? barWindow.compactControlHeight : implicitHeight
                        }
                        Clock {
                            id: trayClock
                            onTimeActivated: localX => {
                                const point = barWindow.mapFromItem(trayClock, localX, 0);
                                barWindow.openMini("time", point.x);
                            }
                            onDateActivated: localX => {
                                const point = barWindow.mapFromItem(trayClock, localX, 0);
                                barWindow.openMini("date", point.x);
                            }
                            showIcon: true
                            showDate: SettingsStore.showDate
                            showTime: SettingsStore.showTime
                            showDetails: !barWindow.cleanCompactMode || SettingsStore.cleanRightMode === "details" || (SettingsStore.cleanRightMode === "hover" && rightGroupHover.hovered)
                            visible: SettingsStore.showTime || SettingsStore.showDate
                            horizontalPadding: barWindow.compactMode ? 0 : 6
                            verticalPadding: barWindow.compactMode ? 0 : 6
                            Layout.preferredWidth: implicitWidth
                            Layout.preferredHeight: barWindow.compactMode ? barWindow.compactControlHeight : implicitHeight
                        }
                    }
                }
                Indicators {
                    id: indicators
                    onIconClicked: (kind, localX) => {
                        // QsWindow is not a QQuickItem. Let Quickshell map from
                        // the actual indicators Item into this window's coordinates.
                        const pos = barWindow.mapFromItem(indicators, localX, 0);
                        barWindow.openMini(kind, pos.x);
                    }
                    compact: barWindow.compactMode
                    showDetails: !barWindow.cleanCompactMode || SettingsStore.cleanRightMode === "details" || (SettingsStore.cleanRightMode === "hover" && rightGroupHover.hovered)
                    backgroundEnabled: !barWindow.cleanCompactMode
                    visible: SettingsStore.showIndicators && !barWindow.simpleMode && (SettingsStore.showWifi || SettingsStore.showBluetooth || SettingsStore.showBattery || SettingsStore.showAudio)
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
                    visible: SettingsStore.showQuickControl
                    Layout.preferredWidth: barWindow.compactMode ? 32 : 40
                    Layout.preferredHeight: barWindow.compactControlHeight
                    radius: height / 2
                    color: Store.sidebarVisible && Store.sidebarScreen === barWindow.screen
                           ? Qt.alpha(Theme.accent, 0.25) : Theme.borderaccent
                    Icon {
                        anchors.centerIn: parent
                        icon: "\ue69b" // stat_minus_1 — Google Material Symbols Rounded
                        font.pixelSize: Theme.barSymbolSize
                        color: Theme.foreground
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            barWindow.miniKind = "";
                            Store.toggleQuick(barWindow.screen);
                        }
                    }
                }
            }
        }
    }
    VerticalBarContent {
        anchors.fill: parent
        hostWindow: barWindow
        visible: barWindow.verticalMode
        onRequestPopup: (kind, x, y) => barWindow.openMini(kind, x, y)
        onRequestMenu: (section, item) => barWindow.openMenu(section, item)
    }
    IndicatorPopup {
        id: indicatorPopup
        hostWindow: barWindow
        kind: barWindow.miniKind
        targetX: barWindow.miniAnchorX
        targetY: barWindow.miniAnchorY
        barPosition: barWindow.barPosition
        menuSection: barWindow.menuSection
        onDismissed: barWindow.miniKind = ""
    }
    // The minimal mode uses a truly centered clock, instead of shifting it
    // based on unequal left/right control widths.
    Clock {
        id: simpleClock
        showDate: SettingsStore.showDate
        showTime: SettingsStore.showTime
        visible: barWindow.simpleMode && !barWindow.verticalMode && (SettingsStore.showDate || SettingsStore.showTime)
        anchors.centerIn: parent
        onTimeActivated: localX => {
            const point = barWindow.mapFromItem(simpleClock, localX, 0);
            barWindow.openMini("time", point.x);
        }
        onDateActivated: localX => {
            const point = barWindow.mapFromItem(simpleClock, localX, 0);
            barWindow.openMini("date", point.x);
        }
    }
}
