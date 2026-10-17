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
                        Icon { Layout.alignment: Qt.AlignHCenter; icon: positionCard.modelData.icon; font.pixelSize: Fonts.scale(21); color: positionCard.selected ? Theme.accent : Theme.foreground }
                        Text { Layout.alignment: Qt.AlignHCenter; text: positionCard.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11); color: Theme.foreground }
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
                            Icon { icon: modeCard.modelData.icon; font.pixelSize: Fonts.scale(18); color: Theme.accent }
                            Text { text: modeCard.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); color: Theme.foreground; Layout.fillWidth: true }
                            Icon { visible: modeCard.selected; icon: "\ue5ca"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                        }
                        Text { text: modeCard.modelData.info; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
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
        heading: "Icon preferences · " + SettingsStore.barMode
        description: "Each layout remembers its own visible icons, menu buttons and Left / Center / Right arrangement. Toggle here, or use Modules for individual menu and Quick Modes buttons."
        symbol: "\ue429"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    {label:"Minimal", action:"minimal"},
                    {label:"Reset mode", action:"reset"}
                ]
                delegate: Rectangle {
                    id: profileAction
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 10
                    color: profileMouse.containsMouse ? Qt.alpha(Theme.accent, .15) : Theme.background
                    border.width: 1
                    border.color: Theme.borderaccent
                    Text { anchors.centerIn: parent; text: profileAction.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    MouseArea {
                        id: profileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (profileAction.modelData.action === "minimal") SettingsStore.useMinimalModePreset();
                            else SettingsStore.resetModeVisibility();
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { text: "Copy from"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
            Repeater {
                model: SettingsStore.spacingModes.filter(mode => mode !== SettingsStore.barMode)
                delegate: Rectangle {
                    id: copyModeButton
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: copyMouse.containsMouse ? Qt.alpha(Theme.accent, .13) : Theme.background
                    Text {
                        anchors.centerIn: parent
                        text: copyModeButton.modelData === "clean-compact" ? "Clean Compact" :
                            copyModeButton.modelData[0].toUpperCase() + copyModeButton.modelData.substring(1)
                        color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                    }
                    MouseArea { id: copyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.copyVisibilityFromMode(copyModeButton.modelData) }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "The Minimal preset changes this mode only. Reset mode restores default visibility without modifying the other four layouts."
            wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: [
                    {key:"showRusticQIcon", label:"RusticQ"},
                    {key:"showLauncher", label:"Launcher"},
                    {key:"showArch", label:"AI"},
                    {key:"showWorkspaces", label:"Workspaces"},
                    {key:"showWeather", label:"Weather"},
                    {key:"showTime", label:"Clock"},
                    {key:"showDate", label:"Calendar"},
                    {key:"showIndicators", label:"Status group"},
                    {key:"showWifi", label:"Wi-Fi"},
                    {key:"showBluetooth", label:"Bluetooth"},
                    {key:"showBattery", label:"Battery"},
                    {key:"showAudio", label:"Audio"},
                    {key:"showTaskView", label:"Task view"},
                    {key:"showMenuBar", label:"Menu bar"},
                    {key:"showQuickModes", label:"Quick Modes"},
                    {key:"showQuickControl", label:"Quick Control"},
                    {key:"showMicrophoneStatus", label:"Microphone"},
                    {key:"showDownloadSpeed", label:"Download rate"},
                    {key:"showUploadSpeed", label:"Upload rate"}
                ]
                delegate: Rectangle {
                    id: iconSwitch
                    required property var modelData
                    readonly property bool enabledForMode: SettingsStore.modeIconVisible(modelData.key)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 10
                    color: switchMouse.containsMouse ? Qt.alpha(Theme.accent, .10) : Theme.background
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                        Text { text: iconSwitch.modelData.label; Layout.fillWidth: true; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); color: Theme.foreground; elide: Text.ElideRight }
                        Rectangle {
                            Layout.preferredWidth: 29; Layout.preferredHeight: 18
                            radius: 9; color: iconSwitch.enabledForMode ? Theme.accent : Theme.borderaccent
                            Rectangle { width: 12; height: 12; radius: 6; anchors.verticalCenter: parent.verticalCenter; x: iconSwitch.enabledForMode ? parent.width - 15 : 3; color: iconSwitch.enabledForMode ? Theme.background : Theme.muted }
                        }
                    }
                    MouseArea { id: switchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.setModeIconVisible(iconSwitch.modelData.key, !iconSwitch.enabledForMode) }
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
                        Icon { icon: detailOption.chosen ? "\ue5ca" : "\ue8f4"; font.pixelSize: Fonts.scale(16); color: Theme.accent }
                        Text { text: detailOption.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11); color: Theme.foreground }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.cleanRightMode = detailOption.modelData.key; SettingsStore.save(); } }
                }
            }
        }
    }


    SettingsSection {
        heading: "Quick Control bar icon"
        description: "Choose whether the bar trigger uses only the icon or a filled background with the icon."
        symbol: "\ue69b"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    { key: "plain", label: "No bg with icon", description: "Transparent button with icon only" },
                    { key: "filled", label: "Bg with icon", description: "Rounded filled background behind the icon" }
                ]
                delegate: Rectangle {
                    id: qcMode
                    required property var modelData
                    readonly property bool chosen: SettingsStore.quickControlButtonStyle === modelData.key
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 11
                    color: chosen ? Qt.alpha(Theme.accent, 0.14) : Theme.background
                    border.width: chosen ? 1 : 0
                    border.color: Theme.accent
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: qcMode.modelData.key === "filled" ? Theme.borderaccent : "transparent"
                            border.width: qcMode.modelData.key === "plain" ? 1 : 0
                            border.color: qcMode.modelData.key === "plain" ? Theme.borderaccent : "transparent"
                            Icon { anchors.centerIn: parent; icon: "\ue69b"; font.pixelSize: Fonts.scale(16); color: qcMode.modelData.key === "filled" ? Theme.accent : Theme.foreground }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qcMode.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11); Layout.fillWidth: true }
                            Text { text: qcMode.modelData.description; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.quickControlButtonStyle = qcMode.modelData.key; SettingsStore.save(); } }
                }
            }
        }
    }

    SettingsSection {
        heading: "Absolute center positioning"
        description: "Center icons are anchored to the actual center of the display, so groups on the left and right do not push them away. Configure a fine offset in pixels."
        symbol: "\ue86c"
        SettingsToggle {
            modelData: ({label:"Lock to absolute screen center", desc:"Keep center icons centered independently of side group widths", key:"absoluteCenter", icon:"\ue86c"})
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 9
            Text { text:"Center offset"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11); Layout.fillWidth: true }
            Text { text: SettingsStore.centerOffsetX + " px"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
            Rectangle {
                Layout.preferredWidth: 68; Layout.preferredHeight: 27; radius: 8; color: Theme.background
                Text { anchors.centerIn: parent; text:"Reset"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.centerOffsetX = 0; SettingsStore.save(); } }
            }
        }
        SettingRangeSlider {
            Layout.fillWidth: true
            minimum: -280; maximum: 280; step: 5
            value: SettingsStore.centerOffsetX
            onPreview: next => SettingsStore.centerOffsetX = next
            onCommit: next => { SettingsStore.centerOffsetX = next; SettingsStore.save(); }
        }
        Text {
            Layout.fillWidth: true
            text: "Left and Right bar positions continue using Top / Middle / Bottom; this control affects horizontal bars only."
            wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
    }

    SettingsSection {
        heading: "Bar icon alignment · Left / Center / Right"
        description: "Positions apply only to the currently selected layout mode. Left / Center / Right settings won't change other layouts."
        symbol: "\ue429"
        BarAlignmentEditor { Layout.fillWidth: true }
    }

    SettingsSection {
        heading: "Icon spacing · Left / Center / Right"
        description: "Choose a zone and adjust the icons currently assigned to it. Spacing follows icons when they move, with independent values for each bar mode."
        symbol: "\ue8b8"
        BarSpacingEditor { Layout.fillWidth: true }
    }

    SettingsSection {
        heading: "Realtime margin editor"
        description: "Independent margins per mode · 0–32px · changes apply instantly."
        symbol: "\ue8b8"
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Editing: " + SettingsStore.barMode; Layout.fillWidth: true; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
            Rectangle {
                Layout.preferredWidth: 108; Layout.preferredHeight: 32; radius: 9; color: Theme.background
                Text { anchors.centerIn: parent; text: "Reset mode"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
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
                            Text { text: marginCard.modelData.name; Layout.fillWidth: true; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                            Text { text: marginCard.amount + " px"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
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
