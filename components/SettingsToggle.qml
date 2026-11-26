import QtQuick
import QtQuick.Layouts
import "../config"

// Reusable setting row; one persistent key per visible module or menu section.
Rectangle {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    required property var modelData
    property bool perBarMode: false
    readonly property bool checked: perBarMode ? SettingsStore.modeIconVisible(modelData.key) : SettingsStore[modelData.key] === true
    Layout.fillWidth: true
    Layout.preferredHeight: root.settingsTheme===Theme?59:root.settingsTheme.rowHeight
    radius: root.settingsTheme.glassRadius("control", 12)
    color: root.settingsTheme!==Theme ? (mouse.containsMouse?root.settingsTheme.hover:"transparent") : root.settingsTheme.glassColor("control", mouse.containsMouse ? Qt.alpha(root.settingsTheme.accent, .075) : root.settingsTheme.surface)
    border.width: root.settingsTheme!==Theme ? 0 : root.settingsTheme.glassBorderWidth("control", 1)
    border.color: root.settingsTheme.glassBorder("control", mouse.containsMouse ? Qt.alpha(root.settingsTheme.accent, .3) : Qt.alpha(root.settingsTheme.foreground, .045))
    Behavior on color { enabled: root.settingsTheme.motionEnabled; ColorAnimation { duration: root.settingsTheme.motionFastDuration } }
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: modelData.label
    Accessible.checked: checked
    Accessible.onPressAction: toggle()
    Keys.onSpacePressed: toggle()
    Keys.onReturnPressed: toggle()
    function toggle() {
        if (perBarMode) SettingsStore.setModeIconVisible(modelData.key, !checked);
        else { SettingsStore[modelData.key] = !checked; SettingsStore.save(); }
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        Rectangle {
            Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: root.settingsTheme.glassRadius("control", 10)
            color: root.settingsTheme.glassColor("control", Qt.alpha(root.settingsTheme.accent, root.checked ? .17 : .075))
            Icon { anchors.centerIn: parent; icon: root.modelData.icon; font.pixelSize: Fonts.scale(19); color: root.checked ? root.settingsTheme.accent : root.settingsTheme.muted }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            GlassLabel { text: root.modelData.label; color: root.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); Layout.fillWidth: true; elide: Text.ElideRight }
            GlassLabel { text: root.modelData.desc; color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); Layout.fillWidth: true; elide: Text.ElideRight }
        }
        Rectangle {
            Layout.preferredWidth: 38; Layout.preferredHeight: 21; radius: 11
            color: root.checked ? root.settingsTheme.accent : root.settingsTheme.borderaccent
            Rectangle {
                width: 15; height: 15; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? parent.width - width - 3 : 3
                color: root.checked ? root.settingsTheme.background : root.settingsTheme.muted
                Behavior on x { enabled: root.settingsTheme.motionEnabled; NumberAnimation { duration: root.settingsTheme.motionFastDuration; easing.type: Easing.OutCubic } }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.toggle();
        }
    }
}
