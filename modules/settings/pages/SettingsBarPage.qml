import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: 14

    SettingsSection {
        heading: "Bar position"
        description: "Choose an edge. Left and Right use a vertical rail."
        symbol: "\ue30b"
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 9; rowSpacing: 9
            Repeater {
                model: [
                    { key: "top", label: "Top", icon: "\ue5d8" },
                    { key: "bottom", label: "Bottom", icon: "\ue5db" },
                    { key: "left", label: "Left", icon: "\ue5de" },
                    { key: "right", label: "Right", icon: "\ue5df" }
                ]
                delegate: Rectangle {
                    id: positionCard
                    required property var modelData
                    readonly property bool selected: SettingsStore.barPosition === modelData.key
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    radius: 11
                    color: selected ? Qt.alpha(Theme.accent, 0.15) : Theme.background
                    border.width: selected ? 1 : 0
                    border.color: Theme.accent
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 5
                        Icon { Layout.alignment: Qt.AlignHCenter; icon: positionCard.modelData.icon; font.pixelSize: 21; color: positionCard.selected ? Theme.accent : Theme.foreground }
                        Text { Layout.alignment: Qt.AlignHCenter; text: positionCard.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.barPosition = positionCard.modelData.key; SettingsStore.save(); } }
                }
            }
        }
    }

    SettingsSection {
        heading: "Bar layout"
        description: "All five modes work on Top, Bottom, Left and Right."
        symbol: "\ue429"
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 9; rowSpacing: 9
            Repeater {
                model: [
                    { key: "compact", label: "Compact", info: "Dense status bar", icon: "\ue5d1" },
                    { key: "clean-compact", label: "Clean Compact", info: "Bare icon controls", icon: "\ue5d1" },
                    { key: "separated", label: "Separated", info: "Floating islands", icon: "\ue86c" },
                    { key: "professional", label: "Professional", info: "Full-width header", icon: "\ue30b" },
                    { key: "simple", label: "Simple", info: "Essential controls", icon: "\ue5d4" }
                ]
                delegate: Rectangle {
                    id: modeCard
                    required property var modelData
                    readonly property bool selected: SettingsStore.barMode === modelData.key
                    Layout.fillWidth: true; Layout.preferredHeight: 92
                    radius: 11
                    color: selected ? Qt.alpha(Theme.accent, 0.13) : Theme.background
                    border.width: selected ? 1 : 0
                    border.color: Theme.accent
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Icon { icon: modeCard.modelData.icon; font.pixelSize: 18; color: Theme.accent }
                            Text { text: modeCard.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: 12; color: Theme.foreground; Layout.fillWidth: true }
                            Icon { visible: modeCard.selected; icon: "\ue5ca"; color: Theme.accent; font.pixelSize: 18 }
                        }
                        Text { text: modeCard.modelData.info; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 12; radius: 6; color: Theme.surface
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 3
                                Rectangle { Layout.preferredWidth: 33; Layout.fillHeight: true; radius: 3; color: Qt.alpha(Theme.accent, 0.47) }
                                Item { Layout.fillWidth: true }
                                Rectangle { Layout.preferredWidth: 15; Layout.fillHeight: true; radius: 3; color: Theme.muted }
                                Item { Layout.fillWidth: true }
                                Rectangle { Layout.preferredWidth: 40; Layout.fillHeight: true; radius: 3; color: Qt.alpha(Theme.accent, 0.47) }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.barMode = modeCard.modelData.key; SettingsStore.save(); } }
                }
            }
        }
    }

    SettingsSection {
        visible: SettingsStore.barMode === "clean-compact"
        heading: "Clean Compact labels"
        description: "Battery and volume percentages remain visible in all modes."
        symbol: "\ue8f4"
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: [
                    {label: "Icons only", key: "icons"},
                    {label: "With details", key: "details"},
                    {label: "On hover", key: "hover"}
                ]
                delegate: Rectangle {
                    id: detailOption
                    required property var modelData
                    readonly property bool chosen: SettingsStore.cleanRightMode === modelData.key
                    Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 10
                    color: chosen ? Qt.alpha(Theme.accent, .16) : Theme.background
                    border.width: chosen ? 1 : 0; border.color: Theme.accent
                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Icon { icon: detailOption.chosen ? "\ue5ca" : "\ue8f4"; font.pixelSize: 16; color: Theme.accent }
                        Text { text: detailOption.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.cleanRightMode = detailOption.modelData.key; SettingsStore.save(); } }
                }
            }
        }
    }

    SettingsSection {
        heading: "Realtime margin editor"
        description: "Independent margins per mode · 0–32px · changes apply instantly."
        symbol: "\ue8b8"
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Editing: " + SettingsStore.barMode; Layout.fillWidth: true; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 11 }
            Rectangle {
                Layout.preferredWidth: 108; Layout.preferredHeight: 32; radius: 9; color: Theme.background
                Text { anchors.centerIn: parent; text: "Reset mode"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetBarMargins() }
            }
        }
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 9; rowSpacing: 9
            Repeater {
                model: [{edge:"top",name:"Top"},{edge:"bottom",name:"Bottom"},{edge:"left",name:"Left"},{edge:"right",name:"Right"}]
                delegate: Rectangle {
                    id: marginCard
                    required property var modelData
                    readonly property int fallback: SettingsStore.barMode === "professional" ? 0 :
                        (SettingsStore.barPosition === "left" || SettingsStore.barPosition === "right") ? 4 :
                        (modelData.edge === "left" || modelData.edge === "right") ? 6 :
                        (SettingsStore.barMode === "compact" || SettingsStore.barMode === "clean-compact") ? 4 : 6
                    readonly property int amount: SettingsStore.marginFor(modelData.edge, fallback)
                    Layout.fillWidth: true; Layout.preferredHeight: 88; radius: 10; color: Theme.background
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: marginCard.modelData.name; Layout.fillWidth: true; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
                            Text { text: marginCard.amount + " px"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
                        }
                        MarginSlider {
                            Layout.fillWidth: true; Layout.preferredHeight: 24
                            value: marginCard.amount
                            onPreview: next => SettingsStore.setBarMargin(marginCard.modelData.edge, next, false)
                            onCommit: next => SettingsStore.setBarMargin(marginCard.modelData.edge, next, true)
                        }
                    }
                }
            }
        }
    }
}
