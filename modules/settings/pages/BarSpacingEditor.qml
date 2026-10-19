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
    readonly property var allChoices: [
        {key:"rusticq", name:"RusticQ", glyph:"\ue8b8"},
        {key:"arch", name:"Arch / AI", glyph:"\uf371"},
        {key:"launcher", name:"App search", glyph:"\ue8b6"},
        {key:"menu", name:"Menu", glyph:"\ue5d2"},
        {key:"workspaces", name:"Workspaces", glyph:"\ue30b"},
        {key:"weather", name:"Weather", glyph:"\ue430"},
        {key:"time", name:"Clock", glyph:"\ue8b5"},
        {key:"date", name:"Date", glyph:"\uebcc"},
        {key:"bluetooth", name:"Bluetooth", glyph:"\ue1a7"},
        {key:"wifi", name:"Wi-Fi", glyph:"\ue63e"},
        {key:"battery", name:"Battery", glyph:"\uf304"},
        {key:"audio", name:"Audio", glyph:"\ue050"},
        {key:"notifications", name:"Notifications", glyph:"\ue7f4"},
        {key:"task", name:"Task View", glyph:"\ue322"},
        {key:"quickModes", name:"Quick Modes", glyph:"\ue429"},
        {key:"quickControl", name:"Quick Control", glyph:"\ue69b"},
        {key:"mic", name:"Microphone", glyph:"\ue029"},
        {key:"down", name:"Download", glyph:"\ue5db"},
        {key:"up", name:"Upload", glyph:"\ue5d8"}
    ]
    readonly property var choices: allChoices.filter(item => SettingsStore.placementFor(item.key) === side)
    readonly property var activeChoice: choices.find(item => item.key === selectedIcon) || (choices.length ? choices[0] : null)
    readonly property int defaultGap: side === "right" && ["compact", "clean-compact"].indexOf(SettingsStore.barMode) !== -1 ? 3 : ["compact", "clean-compact"].indexOf(SettingsStore.barMode) !== -1 ? 4 : side === "right" ? 4 : 5
    // If an icon was moved by the alignment editor, select the first icon now in this zone.
    onChoicesChanged: {
        if (!choices.some(item => item.key === selectedIcon))
            selectedIcon = choices.length ? choices[0].key : "";
    }
    onSideChanged: selectedIcon = choices.length ? choices[0].key : ""
    Connections {
        target: SettingsStore
        function onBarIconMoved(key, zone) {
            editor.side = zone;
            editor.selectedIcon = key;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 9
        Repeater {
            model: [{key:"left",label:"Left",glyph:"\ue5de"},{key:"center",label:"Center",glyph:"\ue86c"},{key:"right",label:"Right",glyph:"\ue5df"}]
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
                    Icon { icon: sideButton.modelData.glyph; font.pixelSize: Fonts.scale(18); color: sideButton.selected ? Theme.accent : Theme.muted }
                    Text { text: sideButton.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); color: Theme.foreground }
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
                Text { text: "Base group gap"; Layout.fillWidth: true; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); color: Theme.foreground }
                Text { text: SettingsStore.spacingGroup(editor.side, editor.defaultGap) + " px"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); color: Theme.accent }
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
                text: "Base gap for the " + editor.side + " group. Each icon adds its own Before / After spacing on top."
                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); color: Theme.muted
            }
        }
    }

    Text { text: "Icons assigned to " + editor.side; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); color: Theme.foreground }
    Text {
        visible: editor.choices.length === 0
        Layout.fillWidth: true
        text: "This zone is empty. Move an icon here in Bar icon alignment above."
        wrapMode: Text.WordWrap
        color: Theme.muted
        font.family: Fonts.poppins.name
        font.pixelSize: Fonts.scale(11)
    }
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
                    Icon { Layout.alignment: Qt.AlignHCenter; icon: iconChoice.modelData.glyph; font.pixelSize: Fonts.scale(19); color: iconChoice.selected ? Theme.accent : Theme.foreground }
                    Text { Layout.alignment: Qt.AlignHCenter; text: iconChoice.modelData.name; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); color: Theme.foreground }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: editor.selectedIcon = iconChoice.modelData.key }
            }
        }
    }

    Rectangle {
        visible: editor.activeChoice !== null
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
                Icon { icon: editor.activeChoice ? editor.activeChoice.glyph : "\ue429"; font.pixelSize: Fonts.scale(20); color: Theme.accent }
                Text { text: (editor.activeChoice ? editor.activeChoice.name : "Icon") + " spacing"; font.pixelSize: Fonts.scale(12); font.family: Fonts.poppinsSB.name; color: Theme.foreground; Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 86; Layout.preferredHeight: 29; radius: 8
                    color: Theme.surface
                    Text { anchors.centerIn: parent; text: "Reset icon"; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppins.name; color: Theme.foreground }
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
                        Text { text: adjustRow.modelData.label; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppins.name; color: Theme.foreground; Layout.fillWidth: true }
                        Text { text: SettingsStore.spacingIcon(editor.side, editor.selectedIcon, adjustRow.modelData.key) + " px"; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppinsSB.name; color: Theme.accent }
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
            text: editor.isVerticalBar ? "On vertical bars, Left / Center / Right become Top / Middle / Bottom; Before / After become upper/lower spacing." : "Spacing applies immediately, with separate saved values for each bar layout mode."
            font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); color: Theme.muted
        }
        Rectangle {
            Layout.preferredWidth: 112; Layout.preferredHeight: 32
            radius: 9; color: Theme.background
            Text { anchors.centerIn: parent; text: "Reset zone"; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppinsSB.name; color: Theme.foreground }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetSideSpacing(editor.side) }
        }
    }
}
