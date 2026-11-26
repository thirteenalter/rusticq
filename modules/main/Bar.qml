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
    WlrLayershell.namespace: "rusticq-bar"
    id: barWindow
    // The popup owns keyboard focus; the bar itself never captures typing.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    readonly property bool requested: SettingsStore.barVisible && autoHide.shown
    visible: motion.presented
    SurfaceMotion { id: motion; shown: barWindow.requested; target: barWindow.contentItem; edge: barWindow.barPosition; style: SettingsStore.barAnimationStyle; closedScale: 1 }
    onRequestedChanged: if (!requested) closeMini()
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
    onMiniKindChanged: if (miniKind !== "") Store.barPopupOpened(barWindow)
    property real miniAnchorX: 0
    property real miniAnchorY: 0
    property string menuSection: "view"
    function openMenu(section, item) {
        const same = miniKind === "menu" && menuSection === section && indicatorPopup.visible;
        if (same) { if (!SettingsStore.barPopupsOnHover) closeMini(); return; }
        const point = barWindow.mapFromItem(item, item.width / 2, item.height / 2);
        menuSection = section;
        miniAnchorX = point.x; miniAnchorY = point.y;
        miniKind = "menu";
    }
    function closeMini() { miniKind = ""; }
    function toggleLauncherFrom(item) {
        closeMini();
        const point=barWindow.mapFromItem(item,0,0);
        const sx=barPosition==="right" ? screen.width-margins.right-width : margins.left;
        const sy=barPosition==="bottom" ? screen.height-margins.bottom-height : margins.top;
        Store.toggleLauncher(screen,{x:sx+point.x,y:sy+point.y,width:item.width,height:item.height,position:barPosition,screenName:screen.name});
    }
    function hoverMini(kind, xPosition, yPosition) {
        if (!SettingsStore.barPopupsOnHover || miniKind === kind) return;
        openMini(kind, xPosition, yPosition);
    }
    function hoverMenu(section, item) {
        if (!SettingsStore.barPopupsOnHover || (miniKind === "menu" && menuSection === section)) return;
        openMenu(section, item);
    }
    function openMini(kind, xPosition, yPosition) {
        Store.sidebarVisible = false;
        if (miniKind === kind) { if (!SettingsStore.barPopupsOnHover) miniKind = ""; return; }
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
    contentItem.transform: Translate { x: motion.offsetX; y: motion.offsetY }

    readonly property string barPosition: SettingsStore.barPosition
    readonly property bool verticalMode: barPosition === "left" || barPosition === "right"
    onBarPositionChanged: closeMini()
    readonly property string activeLayout: SettingsStore.barMode
    onActiveLayoutChanged: closeMini()
    readonly property bool cleanCompactMode: SettingsStore.barMode === "clean-compact"
    readonly property bool compactMode: SettingsStore.barMode === "compact" || cleanCompactMode
    readonly property int compactControlHeight: Math.max(24, Theme.barSymbolSize + 8)
    readonly property bool separatedMode: SettingsStore.barMode === "separated"
    readonly property bool professionalMode: SettingsStore.barMode === "professional"
    readonly property bool simpleMode: SettingsStore.barMode === "simple"
    readonly property int paddingTop: SettingsStore.paddingFor("top")
    readonly property int paddingBottom: SettingsStore.paddingFor("bottom")
    readonly property int paddingLeft: SettingsStore.paddingFor("left")
    readonly property int paddingRight: SettingsStore.paddingFor("right")
    readonly property int railContentWidth: Theme.barRailItemSize + (separatedMode ? Theme.barRailGroupPadding * 2 : 0)
    readonly property real horizontalContentHeight: Math.max(separatedMode ? 40 : 32,
        horizontalLayout.implicitHeight, fixedCenter.item ? fixedCenter.item.implicitHeight : 0)
    readonly property real barHeight: horizontalContentHeight + paddingTop + paddingBottom
    readonly property int groupPadding: separatedMode ? 12 : compactMode ? 3 : professionalMode ? 14 : 9
    readonly property int groupSpacing: compactMode ? 4 : 5
    readonly property int leftGroupSpacing: SettingsStore.spacingGroup("left", compactMode ? 4 : 5)
    readonly property int rightGroupSpacing: SettingsStore.spacingGroup("right", compactMode ? 3 : 4)
    readonly property bool cleanDetailsVisible: !cleanCompactMode || SettingsStore.cleanRightMode === "details" || SettingsStore.cleanRightMode === "hover"

    implicitWidth: verticalMode ? railContentWidth + paddingLeft + paddingRight : 0
    implicitHeight: verticalMode ? 0 : barHeight
    anchors {
        top: barWindow.barPosition !== "bottom"
        bottom: barWindow.barPosition !== "top"
        left: barWindow.barPosition !== "right"
        right: barWindow.barPosition !== "left"
    }
    margins {
        top: SettingsStore.marginFor("top", professionalMode ? 0 : verticalMode ? Theme.barEdgeGap : compactMode ? 4 : 6)
        bottom: SettingsStore.marginFor("bottom", professionalMode ? 0 : verticalMode ? Theme.barEdgeGap : barPosition === "bottom" ? (compactMode ? 4 : 6) : 0)
        left: SettingsStore.marginFor("left", professionalMode ? 0 : verticalMode ? (barPosition === "left" ? Theme.barEdgeGap : 0) : 6)
        right: SettingsStore.marginFor("right", professionalMode ? 0 : verticalMode ? (barPosition === "right" ? Theme.barEdgeGap : 0) : 6)
    }

    BarSurface {
        objectName: "barOuterSurface"
        Behavior on color { enabled: Theme.motionEnabled && SettingsStore.barBackgroundEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
        barLayer: "outer"
        anchors.fill: parent
        baseColor: Theme.barBaseBackground
        baseBorderWidth: Theme.barBaseBorderWidth
        baseBorderColor: Theme.borderaccent
        baseRadius: Theme.barBaseCornerRadius
        MouseArea { anchors.fill: parent; enabled: barWindow.miniKind !== ""; onClicked: barWindow.closeMini() }
    }
    Rectangle {
        visible: barWindow.professionalMode && SettingsStore.barOutlineEnabled
        anchors.bottom: barWindow.barPosition === "top" ? parent.bottom : undefined
        anchors.top: barWindow.barPosition === "bottom" ? parent.top : undefined
        anchors.left: barWindow.barPosition === "right" ? parent.left : undefined
        anchors.right: barWindow.barPosition === "left" ? parent.right : undefined
        width: barWindow.verticalMode ? 1 : parent.width
        height: barWindow.verticalMode ? parent.height : 1
        color: Theme.glassColor("card", Qt.alpha(Theme.accent, 0.35))
    }

    RowLayout {
        id: horizontalLayout
        visible: !barWindow.verticalMode
        anchors.fill: parent
        anchors.leftMargin: barWindow.paddingLeft
        anchors.rightMargin: barWindow.paddingRight
        anchors.topMargin: barWindow.paddingTop
        anchors.bottomMargin: barWindow.paddingBottom
        spacing: barWindow.professionalMode ? 12 : barWindow.compactMode ? 5 : 10

        BarZone {
            id: leftZone
            hostWindow: barWindow
            zone: "left"
            active: !barWindow.verticalMode
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
            active: !barWindow.verticalMode
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
        anchors.verticalCenterOffset: (barWindow.paddingTop - barWindow.paddingBottom) / 2
        width: fixedCenter.item ? fixedCenter.item.implicitWidth : 0
        height: barWindow.horizontalContentHeight
        Loader {
            id: fixedCenter
            active: !barWindow.verticalMode && SettingsStore.absoluteCenter
            sourceComponent: sharedCenterZone
            anchors.centerIn: parent
        }
        GlassLabel {
            visible: barWindow.professionalMode && fixedCenter.item && fixedCenter.item.implicitWidth === 0
            anchors.centerIn: parent
            text: Theme.useAether ? "RUSTICQ / AETHER" : "RUSTICQ / GRUVBOX"
            font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10); color: Theme.contentMuted
        }
    }
    Loader {
        id: verticalContent
        active: barWindow.verticalMode
        anchors.fill: parent
        anchors.leftMargin: barWindow.paddingLeft
        anchors.rightMargin: barWindow.paddingRight
        anchors.topMargin: barWindow.paddingTop
        anchors.bottomMargin: barWindow.paddingBottom
        sourceComponent: VerticalBarContent {
            hostWindow: barWindow
            onRequestPopup: (kind, x, y) => barWindow.openMini(kind, x, y)
            onRequestMenu: (section, item) => barWindow.openMenu(section, item)
        }
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
