import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../services"

FocusScope {
    id: root
    property var targetScreen: null
    property bool backgroundEnabled: true
    property int controlHeight: 24
    property bool revealed: false
    property var hoveredButton: null
    readonly property bool expanded: !SettingsStore.quickModesAutoHide || revealed || activeFocus
    readonly property var modes: [
        { key: "awake", title: "Keep Awake", icon: "\ue541", show: SettingsStore.modeIconVisible("showKeepAwake") },
        { key: "silent", title: "Silent", icon: "\ue7f6", show: SettingsStore.modeIconVisible("showSilent") },
        { key: "gaming", title: "Gaming Mode", icon: "\ue30f", show: SettingsStore.modeIconVisible("showGamingMode") },
        { key: "night", title: "Night Mode", icon: "\ue51c", show: SettingsStore.modeIconVisible("showNightMode") },
        { key: "mic", title: "Mute Microphone", icon: "\ue02b", show: SettingsStore.modeIconVisible("showMicMute") }
    ].filter(mode => mode.show)
    readonly property bool hasModules: modes.length > 0
    implicitWidth: 28 + (expanded && hasModules ? modeButtons.implicitWidth + 8 : 0)
    implicitHeight: controlHeight

    Connections {
        target: Store
        function onShortcutBarRequested(kind, screenName) {
            if (kind !== "quick-modes" || !root.targetScreen || root.targetScreen.name !== screenName)
                return;
            root.revealed = !root.revealed;
            if (root.revealed) QuickModesService.refresh();
        }
    }
    function reveal() {
        closeDelay.stop();
        revealed = true;
    }
    function scheduleClose() {
        if (SettingsStore.quickModesAutoHide) closeDelay.restart();
    }
    onExpandedChanged: {
        if (expanded) QuickModesService.refresh();
        else hoveredButton = null;
    }
    onVisibleChanged: if (!visible) { revealed = false; hoveredButton = null; closeDelay.stop(); }
    onActiveFocusChanged: if (!activeFocus) scheduleClose();

    HoverHandler {
        id: groupHover
        margin: 6
        onHoveredChanged: if (hovered) root.reveal(); else root.scheduleClose();
    }
    Timer {
        id: closeDelay
        interval: 450
        onTriggered: if (!groupHover.hovered && !root.activeFocus) root.revealed = false;
    }
    Timer {
        interval: 5000
        running: root.visible && root.expanded
        repeat: true
        onTriggered: QuickModesService.refresh()
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.backgroundEnabled ? Theme.borderaccent : "transparent"
    }
    RowLayout {
        id: modeButtons
        anchors.right: trigger.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        visible: root.expanded
        Repeater {
            model: root.modes
            delegate: Rectangle {
                id: modeButton
                required property var modelData
                readonly property bool on: QuickModesService.active(modelData.key)
                readonly property bool available: QuickModesService.available(modelData.key)
                readonly property bool pending: QuickModesService.busy && (modelData.key === "silent" || modelData.key === "night")
                readonly property string hint: modelData.title + " · " + (available ? (on ? "On" : "Off") : "Unavailable")
                    + "\n" + QuickModesService.detail(modelData.key)
                Layout.preferredWidth: 28
                Layout.preferredHeight: root.controlHeight
                activeFocusOnTab: true
                radius: height / 2
                color: root.backgroundEnabled && (on || buttonMouse.containsMouse || activeFocus)
                    ? Qt.alpha(Theme.accent, 0.18) : "transparent"
                Accessible.role: Accessible.CheckBox
                Accessible.name: modelData.title
                Accessible.checked: on
                Accessible.checkable: true
                Accessible.onPressAction: if (available && !pending) QuickModesService.toggle(modelData.key)
                Keys.onSpacePressed: if (available && !pending) QuickModesService.toggle(modelData.key)
                Keys.onReturnPressed: if (available && !pending) QuickModesService.toggle(modelData.key)
                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    color: modeButton.on ? Qt.alpha(Theme.accent, 0.16) : "transparent"
                    Icon {
                        anchors.centerIn: parent
                        icon: modeButton.modelData.icon
                        font.pixelSize: Fonts.scale(16)
                        color: modeButton.on || modeButton.activeFocus ? Theme.accent : Theme.foreground
                        opacity: modeButton.available && !modeButton.pending ? 1 : 0.4
                    }
                }
                MouseArea {
                    id: buttonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: modeButton.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: root.hoveredButton = modeButton
                    onExited: if (root.hoveredButton === modeButton) root.hoveredButton = null
                    onClicked: if (modeButton.available && !modeButton.pending) QuickModesService.toggle(modeButton.modelData.key)
                }
            }
        }
    }
    Rectangle {
        id: trigger
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: root.controlHeight
        color: "transparent"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Quick modes"
        Accessible.onPressAction: root.reveal()
        Keys.onSpacePressed: root.reveal()
        Keys.onReturnPressed: root.reveal()
        Icon {
            anchors.centerIn: parent
            icon: "\ue429"
            font.pixelSize: Fonts.scale(18)
            color: QuickModesService.anyActive || root.expanded ? Theme.accent : Theme.foreground
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.reveal()
            onClicked: root.reveal()
        }
    }
    PopupWindow {
        anchor.item: root.hoveredButton || trigger
        anchor.rect.y: root.controlHeight + 8
        visible: root.visible && root.expanded && root.hoveredButton !== null
        implicitWidth: 260
        implicitHeight: tooltipText.implicitHeight + 20
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.background
            border.color: Theme.borderaccent
            Text {
                id: tooltipText
                x: 10; y: 10
                width: 240
                text: (root.hoveredButton ? root.hoveredButton.hint : "")
                    + (QuickModesService.error ? "\n" + QuickModesService.error : "")
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(11)
                color: Theme.foreground
            }
        }
    }
}
