import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"

// Per-mode, per-side spacing editor. Spacing is applied by QtQuick.Layouts,
// not by absolute x/y offsets, so hit targets and popup anchors stay correct.
ColumnLayout {
    id: editor
    Layout.fillWidth: true
    spacing: 12
    property string side: "right"
    property string selectedIcon: "wifi"
    readonly property bool isVerticalBar: SettingsStore.barPosition === "left" || SettingsStore.barPosition === "right"
    readonly property var leftChoices: [
        {key:"arch", name:"Arch / AI", glyph:"\ueb8e"},
        {key:"launcher", name:"App search", glyph:"\ue8b6"},
        {key:"menu", name:"Menu", glyph:"\ue5d2"},
        {key:"workspaces", name:"Workspaces", glyph:"\ue30b"}
    ]
    readonly property var rightChoices: [
        {key:"weather", name:"Weather", glyph:"\ue430"},
        {key:"time", name:"Clock", glyph:"\ue8b5"},
        {key:"date", name:"Date", glyph:"\uebcc"},
        {key:"bluetooth", name:"Bluetooth", glyph:"\ue1a7"},
        {key:"wifi", name:"Wi-Fi", glyph:"\ue63e"},
        {key:"battery", name:"Battery", glyph:"\uf304"},
        {key:"audio", name:"Audio", glyph:"\ue050"},
        {key:"task", name:"Task View", glyph:"\uf190"},
        {key:"quickModes", name:"Quick Modes", glyph:"\ue429"},
        {key:"quickControl", name:"Quick Control", glyph:"\ue69b"}
    ]
    readonly property var choices: side === "left" ? leftChoices : rightChoices
    readonly property var activeChoice: choices.find(item => item.key === selectedIcon) || choices[0]
    readonly property int defaultGap: side === "left" ? (["compact", "clean-compact"].indexOf(SettingsStore.barMode) !== -1 ? 4 : 5) : (["compact", "clean-compact"].indexOf(SettingsStore.barMode) !== -1 ? 3 : 4)
    onSideChanged: selectedIcon = side === "left" ? "arch" : "wifi"

    RowLayout {
        Layout.fillWidth: true
        spacing: 9
        Repeater {
            model: [{key:"left",label:"Left group",glyph:"\ue5de"},{key:"right",label:"Right group",glyph:"\ue5df"}]
            delegate: Rectangle {
                id: sideButton
                required property var modelData
                readonly property bool selected: editor.side === modelData.key
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 11
                color: selected ? Qt.alpha(Theme.accent, 0.16) : Theme.background
                border.width: selected ? 1 : 0
                border.color: Theme.accent
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { icon: sideButton.modelData.glyph; font.pixelSize: 18; color: sideButton.selected ? Theme.accent : Theme.muted }
                    Text { text: sideButton.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: 12; color: Theme.foreground }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: editor.side = sideButton.modelData.key }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: baseControls.implicitHeight + 24
        radius: 11
        color: Theme.background
        ColumnLayout {
            id: baseControls
            x: 12; y: 12; width: parent.width - 24
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Base group gap"; Layout.fillWidth: true; font.family: Fonts.poppinsSB.name; font.pixelSize: 12; color: Theme.foreground }
                Text { text: SettingsStore.spacingGroup(editor.side, editor.defaultGap) + " px"; font.family: Fonts.poppinsSB.name; font.pixelSize: 12; color: Theme.accent }
            }
            MarginSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                maximum: 16
                value: SettingsStore.spacingGroup(editor.side, editor.defaultGap)
                onPreview: value => SettingsStore.setGroupSpacing(editor.side, value, false)
                onCommit: value => SettingsStore.setGroupSpacing(editor.side, value, true)
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Baseline between controls in the " + (editor.side === "left" ? "left" : "right") + " group. The extra Before / After values below are added to this gap."
                font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted
            }
        }
    }

    Text { text: "Choose an icon to adjust"; font.family: Fonts.poppinsSB.name; font.pixelSize: 12; color: Theme.foreground }
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 7
        rowSpacing: 7
        Repeater {
            model: editor.choices
            delegate: Rectangle {
                id: iconChoice
                required property var modelData
                readonly property bool selected: editor.selectedIcon === modelData.key
                Layout.fillWidth: true
                Layout.preferredHeight: 63
                radius: 10
                color: selected ? Qt.alpha(Theme.accent, 0.16) : Theme.background
                border.width: selected ? 1 : 0
                border.color: Theme.accent
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Icon { Layout.alignment: Qt.AlignHCenter; icon: iconChoice.modelData.glyph; font.pixelSize: 19; color: iconChoice.selected ? Theme.accent : Theme.foreground }
                    Text { Layout.alignment: Qt.AlignHCenter; text: iconChoice.modelData.name; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.foreground }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: editor.selectedIcon = iconChoice.modelData.key }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: adjustContents.implicitHeight + 24
        radius: 11
        color: Theme.background
        ColumnLayout {
            id: adjustContents
            x: 12; y: 12; width: parent.width - 24
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Icon { icon: editor.activeChoice.glyph; font.pixelSize: 20; color: Theme.accent }
                Text { text: editor.activeChoice.name + " spacing"; font.pixelSize: 12; font.family: Fonts.poppinsSB.name; color: Theme.foreground; Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 86; Layout.preferredHeight: 29; radius: 8
                    color: Theme.surface
                    Text { anchors.centerIn: parent; text: "Reset icon"; font.pixelSize: 10; font.family: Fonts.poppins.name; color: Theme.foreground }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetIconSpacing(editor.side, editor.selectedIcon) }
                }
            }
            Repeater {
                model: [{key:"before",label:"Before"},{key:"after",label:"After"}]
                delegate: ColumnLayout {
                    id: adjustRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: adjustRow.modelData.label; font.pixelSize: 11; font.family: Fonts.poppins.name; color: Theme.foreground; Layout.fillWidth: true }
                        Text { text: SettingsStore.spacingIcon(editor.side, editor.selectedIcon, adjustRow.modelData.key) + " px"; font.pixelSize: 11; font.family: Fonts.poppinsSB.name; color: Theme.accent }
                    }
                    MarginSlider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        maximum: 24
                        value: SettingsStore.spacingIcon(editor.side, editor.selectedIcon, adjustRow.modelData.key)
                        onPreview: value => SettingsStore.setIconSpacing(editor.side, editor.selectedIcon, adjustRow.modelData.key, value, false)
                        onCommit: value => SettingsStore.setIconSpacing(editor.side, editor.selectedIcon, adjustRow.modelData.key, value, true)
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: editor.isVerticalBar ? "On Left/Right bar positions, Before/After become top/bottom spacing." : "Spacing changes immediately on the bar. Settings are saved per layout mode."
            font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted
        }
        Rectangle {
            Layout.preferredWidth: 112; Layout.preferredHeight: 32
            radius: 9; color: Theme.background
            Text { anchors.centerIn: parent; text: "Reset this side"; font.pixelSize: 10; font.family: Fonts.poppinsSB.name; color: Theme.foreground }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetSideSpacing(editor.side) }
        }
    }
}
