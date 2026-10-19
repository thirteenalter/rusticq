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
    visible: SettingsStore.barVisible && autoHide.shown
    exclusionMode: SettingsStore.barAutoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
    onVisibleChanged: if (!visible) closeMini()
    HoverHandler { id: barHover }
    BarAutoHide {
        id: autoHide
        enabled: SettingsStore.barVisible && SettingsStore.barAutoHide
        position: barWindow.barPosition
        screen: barWindow.screen
        hovered: barHover.hovered
        heldOpen: barWindow.miniKind !== ""
                  || (Store.sidebarVisible && Store.sidebarScreen === barWindow.screen)
                  || (Store.launcherVisible && Store.launcherScreen === barWindow.screen)
                  || (Store.aiVisible && Store.aiScreen === barWindow.screen)
    }
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
    // Menu/popup shortcuts are handled by the bar belonging to the focused monitor.
    // This works even when an icon is hidden or assigned to another bar zone.
    Connections {
        target: Store
        function onShortcutBarRequested(kind, screenName) {
            if (!barWindow.screen || barWindow.screen.name !== screenName) return;
            const current = barWindow.miniKind;
            if (kind === "quick-modes") return; // QuickModes.qml owns its reveal state.
            if (kind === "menu-default") {
                const sections = [
                    ["edit", SettingsStore.modeIconVisible("showMenuEdit")], ["view", SettingsStore.modeIconVisible("showMenuView")],
                    ["share", SettingsStore.modeIconVisible("showMenuShare")], ["file", SettingsStore.modeIconVisible("showMenuFile")],
                    ["shell", SettingsStore.modeIconVisible("showMenuShell")], ["tools", SettingsStore.modeIconVisible("showMenuTools")]
                ];
                const enabled = sections.find(pair => pair[1]);
                if (!enabled) return;
                kind = "menu-" + enabled[0];
            }
            if (kind.indexOf("menu-") === 0) {
                const section = kind.substring(5);
                if (current === "menu" && barWindow.menuSection === section) {
                    barWindow.closeMini();
                } else {
                    barWindow.menuSection = section;
                    barWindow.miniAnchorX = 14;
                    barWindow.miniAnchorY = barWindow.barHeight / 2;
                    barWindow.miniKind = "menu";
                }
                return;
            }
            barWindow.openMini(kind, barWindow.width / 2, barWindow.height / 2);
        }
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
    readonly property int groupSpacing: compactMode ? 4 : 5
    readonly property int leftGroupSpacing: SettingsStore.spacingGroup("left", compactMode ? 4 : 5)
    readonly property int rightGroupSpacing: SettingsStore.spacingGroup("right", compactMode ? 3 : 4)
    readonly property bool cleanDetailsVisible: !cleanCompactMode || SettingsStore.cleanRightMode === "details" || SettingsStore.cleanRightMode === "hover"

    implicitWidth: verticalMode ? (simpleMode ? 48 : cleanCompactMode ? 44 : compactMode ? 52 : Theme.verticalBarWidth) : 0
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
        anchors.leftMargin: barWindow.professionalMode ? 14 : 4
        anchors.rightMargin: barWindow.professionalMode ? 14 : 4
        spacing: barWindow.professionalMode ? 12 : barWindow.compactMode ? 5 : 10

        BarZone {
            id: leftZone
            hostWindow: barWindow
            zone: "left"
            compact: barWindow.compactMode
            clean: barWindow.cleanCompactMode
            separated: barWindow.separatedMode
            professional: barWindow.professionalMode
            simple: barWindow.simpleMode
            controlHeight: barWindow.compactControlHeight
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
        }
        Item { Layout.fillWidth: true }
        Loader {
            id: flowCenter
            active: !barWindow.verticalMode && !SettingsStore.absoluteCenter
            sourceComponent: sharedCenterZone
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0
        }
        Item { Layout.fillWidth: true; visible: !SettingsStore.absoluteCenter }
        BarZone {
            id: rightZone
            hostWindow: barWindow
            zone: "right"
            compact: barWindow.compactMode
            clean: barWindow.cleanCompactMode
            separated: barWindow.separatedMode
            professional: barWindow.professionalMode
            simple: barWindow.simpleMode
            controlHeight: barWindow.compactControlHeight
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
        }
    }
    Component {
        id: sharedCenterZone
        BarZone {
            hostWindow: barWindow
            zone: "center"
            compact: barWindow.compactMode
            clean: barWindow.cleanCompactMode
            separated: barWindow.separatedMode
            professional: barWindow.professionalMode
            simple: barWindow.simpleMode
            controlHeight: barWindow.compactControlHeight
        }
    }
    // The centered zone is independent of the left/right row widths.
    Item {
        id: absoluteCenterAnchor
        visible: !barWindow.verticalMode && SettingsStore.absoluteCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: SettingsStore.centerOffsetX
        anchors.verticalCenter: parent.verticalCenter
        width: fixedCenter.item ? fixedCenter.item.implicitWidth : 0
        height: barWindow.barHeight
        Loader {
            id: fixedCenter
            active: !barWindow.verticalMode && SettingsStore.absoluteCenter
            sourceComponent: sharedCenterZone
            anchors.centerIn: parent
        }
        Text {
            visible: barWindow.professionalMode && fixedCenter.item && fixedCenter.item.implicitWidth === 0
            anchors.centerIn: parent
            text: Theme.useAether ? "RUSTICQ / AETHER" : "RUSTICQ / GRUVBOX"
            font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10); color: Theme.muted
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
        onMenuSectionNavigated: function(sectionKey) { barWindow.menuSection = sectionKey; }
        onDismissed: barWindow.miniKind = ""
    }
}
