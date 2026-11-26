import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../config"

Rectangle {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    property alias text: input.text
    property string placeholder: "Search by name"
    property bool autoFocus: false
    readonly property string query: text.trim().toLowerCase()
    readonly property bool focusWhenShown: autoFocus && visible && enabled
        && root.Window.window !== null && root.Window.window.visible
    property Item focusAtRequest: null
    function focusInput() {
        if (visible && enabled) input.forceActiveFocus(Qt.OtherFocusReason);
    }
    function focusOnOpen() {
        // Defer until the loader, layout and popup focus grab have settled.
        // Recheck eligibility so a fast close cannot focus a hidden field.
        const previous = focusAtRequest;
        focusAtRequest = null;
        if (!focusWhenShown) return;
        const window = root.Window.window;
        const current = window.activeFocusItem;
        // Respect a control the user focused after this request was queued.
        if (current && current !== previous && current !== input && current !== window.contentItem
            && (current.activeFocusOnTab || current.cursorPosition !== undefined)) return;
        focusInput();
    }
    function requestInputFocus() {
        focusDelay.stop();
        focusAtRequest = focusWhenShown ? root.Window.window.activeFocusItem : null;
        if (focusWhenShown) focusDelay.restart();
    }
    onFocusWhenShownChanged: root.requestInputFocus()
    Component.onCompleted: root.requestInputFocus()
    Timer {
        id: focusDelay
        // Let native keyboard acquisition finish before choosing the editor.
        interval: 100
        onTriggered: root.focusOnOpen()
    }
    implicitHeight: 38
    implicitWidth: 220
    radius: root.settingsTheme.glassRadius("control", root.settingsTheme.rowRadius)
    color: root.settingsTheme.glassColor("control", root.settingsTheme.background)
    border.width: root.settingsTheme.glassBorderWidth("control", 1)
    border.color: root.settingsTheme.glassBorder("control", input.activeFocus ? root.settingsTheme.accent : root.settingsTheme.borderaccent)
    opacity: enabled ? 1 : 0.45
    Behavior on border.color { enabled: root.settingsTheme.motionEnabled; ColorAnimation { duration: root.settingsTheme.motionFastDuration } }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: root.focusInput()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.settingsTheme.controlPadding
        anchors.rightMargin: root.settingsTheme.inlineGap
        spacing: root.settingsTheme.inlineGap
        Icon { icon: "\ue8b6"; color: root.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(16) }
        TextInput {
            id: input
            objectName: "nameSearchInput"
            // Invisible Qt Quick items can retain keyboard focus. Disable only
            // the editor while hidden, so collapsed cards release it as well.
            enabled: root.visible && root.enabled && root.Window.window !== null && root.Window.window.visible
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: TextInput.AlignVCenter
            color: root.settingsTheme.foreground
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(11)
            selectByMouse: true
            activeFocusOnTab: true
            clip: true
            Accessible.name: root.placeholder
            Keys.onEscapePressed: event => {
                if (text.length > 0) text = "";
                else event.accepted = false;
            }
            GlassLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                visible: input.text.length === 0
                text: root.placeholder
                elide: Text.ElideRight
                color: root.settingsTheme.contentMuted
                font: input.font
            }
        }
        ActionButton {
            objectName: "clearNameSearch"
            visible: root.text.length > 0
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            symbol: "\ue5cd"
            Accessible.name: "Clear search"
            onClicked: {
                root.text = "";
                root.focusInput();
            }
        }
    }
}
