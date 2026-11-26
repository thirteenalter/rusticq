import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

SettingsSection {
    id: settingsPageRoot
    readonly property var settingsTheme: SettingsMaterial.forItem(settingsPageRoot)
    objectName: "surfaceSpacingSettings"
    heading: "Surface Spacing"
    description: "Adjust panel and popup content in pixels. Auto follows UI density. Bar and launcher padding keep their own controls."
    symbol: "\ue9a2"
    Repeater {
        model: [
            {key:"surfacePanelPadding", token:"panelPadding", label:"Panel and popup padding"},
            {key:"surfaceCardPadding", token:"cardPadding", label:"Nested card padding"},
            {key:"surfaceControlPadding", token:"controlPadding", label:"Control and search field padding"},
            {key:"surfaceContentGap", token:"contentGap", label:"Space between content"},
            {key:"surfaceInlineGap", token:"inlineGap", label:"Space between inline controls"}
        ]
        delegate: ColumnLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: settingsPageRoot.settingsTheme.compactGap
            readonly property int preference: SettingsStore[modelData.key]
            readonly property int effectiveValue: Theme[modelData.token]
            function adjust(delta) {
                SettingsStore.setSurfaceSpacing(modelData.key,Math.max(0,Math.min(SettingsStore.surfaceSpacingMaximums[modelData.key],effectiveValue+delta)),true);
            }
            RowLayout {
                Layout.fillWidth: true
                GlassLabel {
                    Layout.fillWidth: true
                    text: row.modelData.label
                    color: settingsPageRoot.settingsTheme.foreground
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(12)
                    wrapMode: Text.WordWrap
                }
                GlassLabel {
                    text: (row.preference < 0 ? "Auto · " : "") + row.effectiveValue + " px"
                    color: settingsPageRoot.settingsTheme.contentMuted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(12)
                }
                ActionButton {
                    objectName: row.modelData.key + "Auto"
                    label: "Auto"
                    implicitHeight: 28
                    enabled: row.preference >= 0
                    onClicked: SettingsStore.setSurfaceSpacing(row.modelData.key,-1,true)
                }
            }
            SettingRangeSlider {
                objectName: row.modelData.key + "Slider"
                Layout.fillWidth: true
                minimum: 0
                maximum: SettingsStore.surfaceSpacingMaximums[row.modelData.key]
                value: row.effectiveValue
                activeFocusOnTab: true
                Accessible.name: row.modelData.label
                Keys.onLeftPressed: row.adjust(-1)
                Keys.onRightPressed: row.adjust(1)
                onPreview: next => SettingsStore.setSurfaceSpacing(row.modelData.key,next,false)
                onCommit: next => SettingsStore.setSurfaceSpacing(row.modelData.key,next,true)
            }
        }
    }
    ActionButton {
        objectName: "resetSurfaceSpacing"
        label: "Reset Surface Spacing"
        symbol: "\ue5d5"
        onClicked: SettingsStore.resetSurfaceSpacing()
    }
}
