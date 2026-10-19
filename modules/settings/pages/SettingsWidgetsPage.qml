import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: 14
    SettingsSection {
        heading: "Desktop widgets"
        description: "Cards live on Wayland's Bottom layer, behind normal windows."
        symbol: "\ue916"
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            radius: 12
            color: Theme.background
            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 9
                Repeater {
                    model: [
                        {label:"Calendar",icon:"\ue916",line:"16 17 18"},
                        {label:"System",icon:"\ue1db",line:"CPU · RAM"},
                        {label:"Clock",icon:"\ue8b5",line:"08:30"}
                    ]
                    delegate: Rectangle {
                        id: previewCard
                        required property var modelData
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: 11
                        color: Theme.surface
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 5
                            Icon { Layout.alignment: Qt.AlignHCenter; icon: previewCard.modelData.icon; font.pixelSize: Fonts.scale(19); color: Theme.accent }
                            Text { Layout.alignment: Qt.AlignHCenter; text: previewCard.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                            Text { Layout.alignment: Qt.AlignHCenter; text: previewCard.modelData.line; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9) }
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Drag any widget by its top header to move it. Positions stay anchored to the current monitor and are saved."
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(11)
            color: Theme.muted
            wrapMode: Text.WordWrap
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 10
            color: Theme.background
            Text { anchors.centerIn: parent; text: "Reset desktop widget positions"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11); color: Theme.foreground }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetWidgetPositions() }
        }
        Repeater {
            model: [
                {label:"Calendar widget",desc:"Monthly calendar behind application windows",key:"desktopCalendar",icon:"\ue916"},
                {label:"System widget",desc:"CPU, memory and disk usage",key:"desktopSystem",icon:"\ue1db"},
                {label:"Clock widget",desc:"Large time and date",key:"desktopClock",icon:"\ue8b5"},
                {label:"Now Playing widget",desc:"MPRIS media details and playback controls",key:"desktopMedia",icon:"\ue405"},
                {label:"Weather widget",desc:"Live forecast conditions from the weather service",key:"desktopWeather",icon:"\ue430"},
                {label:"Connectivity widget",desc:"Wi-Fi, Bluetooth and battery summary",key:"desktopConnectivity",icon:"\ue1d8"},
                {label:"Notes widget",desc:"Free-form writing, independent for each workspace",key:"desktopNotes",icon:"\ue873"},
                {label:"Kanban widget",desc:"Three-column task board with quick stage controls",key:"desktopKanban",icon:"\ue8f9"},
                {label:"Random image widget",desc:"Local image slideshow; no network access",key:"desktopRandomImage",icon:"\ue3f4"}
            ]
            delegate: SettingsToggle {}
        }
    }
    SettingsSection {
        heading: "Widget workspaces"
        description: "Select exactly which Hyprland workspaces show each interactive widget. A different note is saved for each workspace and monitor. All other widgets are unchanged."
        symbol: "\ue30b"
        Repeater {
            model: [
                {kind:"notes", title:"Free-form Notes"},
                {kind:"kanban", title:"Kanban Board"},
                {kind:"randomImage", title:"Random Image"}
            ]
            delegate: ColumnLayout {
                id: workspaceRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                Text { text: workspaceRow.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: 10
                        delegate: Rectangle {
                            id: workspaceToggle
                            required property int index
                            readonly property int workspaceNumber: index + 1
                            readonly property bool selected: SettingsStore.widgetAllowedOnWorkspace(workspaceRow.modelData.kind, workspaceNumber)
                            width: 46; height: 34; radius: 9
                            color: selected ? Qt.alpha(Theme.accent, .22) : Theme.background
                            border.width: selected ? 1 : 0
                            border.color: Theme.accent
                            Text { anchors.centerIn: parent; text: String(workspaceToggle.workspaceNumber); color: selected ? Theme.accent : Theme.foreground; font.pixelSize: Fonts.scale(11) }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsStore.setWidgetWorkspace(workspaceRow.modelData.kind, workspaceToggle.workspaceNumber, !workspaceToggle.selected)
                            }
                        }
                    }
                }
            }
        }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: Fonts.scale(10)
            text: "Notes supports multiline writing and autosaves. Drag by the small top-right handle; resize from the bottom-right corner. Switch workspace to write a different note."
        }
    }
    SettingsSection {
        heading: "Random image widget"
        description: "Select an image folder inside your home. It stays local, never follows symlinks, and can rotate manually or periodically."
        symbol: "\ue3f4"
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10; color: Theme.background
            TextInput {
                id: imageFolderInput
                anchors.fill: parent; anchors.margins: 11
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                text: SettingsStore.widgetImageFolder
                onEditingFinished: {
                    if (text !== SettingsStore.widgetImageFolder) {
                        SettingsStore.widgetImageFolder = text.trim();
                        SettingsStore.save();
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !parent.text.length
                    text: "Empty = ~/Pictures/Wallpapers, or enter ~/Pictures/..."
                    color: Theme.muted; font.pixelSize: Fonts.scale(10)
                }
            }
        }
        Text { Layout.fillWidth: true; color: Theme.muted; wrapMode: Text.WordWrap
            text: "Press Enter to save. The widget Next button selects another photo from this folder."
            font.pixelSize: Fonts.scale(10) }
        RowLayout {
            Layout.fillWidth: true; spacing: 7
            Repeater {
                model: [{seconds:0,label:"Manual"},{seconds:60,label:"1 min"},{seconds:300,label:"5 min"},{seconds:900,label:"15 min"}]
                delegate: Rectangle {
                    id: rotateChoice
                    required property var modelData
                    readonly property bool selected: SettingsStore.widgetImageRotateSeconds === modelData.seconds
                    Layout.fillWidth: true; Layout.preferredHeight: 35; radius: 9
                    color: selected ? Qt.alpha(Theme.accent,.17) : Theme.background
                    border.color: selected ? Theme.accent : "transparent"; border.width: selected ? 1 : 0
                    Text { anchors.centerIn: parent; text: rotateChoice.modelData.label
                        color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { SettingsStore.widgetImageRotateSeconds = rotateChoice.modelData.seconds; SettingsStore.save(); } }
                }
            }
        }
    }

}
