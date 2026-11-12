import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"

ColumnLayout {
    id: root
    spacing: Theme.sectionGap

    Flow {
        Layout.fillWidth: true
        spacing: 7
        Repeater {
            model: [{key: "system", label: "System language"}, {key: "id_ID", label: "Indonesia"}, {key: "en_US", label: "English"}]
            delegate: Rectangle {
                id: languageChoice
                required property var modelData
                readonly property bool selected: SettingsStore.clockLocale === modelData.key
                width: languageLabel.implicitWidth + 22; height: 32; radius: 9
                color: selected ? Qt.alpha(Theme.accent, .16) : Theme.background
                border.width: selected ? 1 : 0; border.color: Theme.accent
                Text {
                    id: languageLabel
                    anchors.centerIn: parent; text: languageChoice.modelData.label
                    color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { SettingsStore.clockLocale = languageChoice.modelData.key; SettingsStore.save(); }
                }
            }
        }
    }
    SettingsToggle {
        modelData: ({label: "Lowercase day & month", desc: "Example: jumat, 13 november 2026", key: "clockLowercase", icon: "\ue264"})
    }
    Repeater {
        model: [
            {label: "Clock", calendar: false, modeKey: "clockDisplayMode", formatKey: "clockFormat", presets: [
                {label: "24 hour", format: "HH:mm"},
                {label: "With seconds", format: "HH:mm:ss"},
                {label: "12 hour", format: "h:mm AP"},
                {label: "Time + day", format: "HH:mm dddd"},
                {label: "Time + full date", format: "HH:mm dddd, d MMMM yyyy"},
                {label: "Date only", format: "dddd, d MMMM yyyy"}
            ]},
            {label: "Calendar", calendar: true, modeKey: "calendarDisplayMode", formatKey: "calendarFormat", presets: [
                {label: "Short date", format: "ddd, dd MMM"},
                {label: "Full date", format: "dddd, d MMMM yyyy"},
                {label: "Day + month", format: "d MMMM yyyy"},
                {label: "Numeric", format: "dd/MM/yyyy"},
                {label: "Day only", format: "dddd"}
            ]}
        ]
        delegate: ColumnLayout {
            id: clockRow
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: clockRow.modelData.label
                color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12)
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 46
                radius: 10; color: Theme.background; clip: true
                HoverHandler { id: previewHover }
                Clock {
                    anchors.centerIn: parent
                    showTime: !clockRow.modelData.calendar
                    showDate: clockRow.modelData.calendar
                    showDetails: SettingsStore.barMode !== "clean-compact" || SettingsStore.cleanRightMode === "details" ||
                        (SettingsStore.cleanRightMode === "hover" && previewHover.hovered)
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width < 440 ? 2 : 4
                columnSpacing: 7; rowSpacing: 7
                Repeater {
                    model: [{key: "auto", label: "Follow layout"}, {key: "icon", label: "Icon only"},
                            {key: "text", label: "Text only"}, {key: "both", label: "Icon + text"}]
                    delegate: Rectangle {
                        id: styleChoice
                        required property var modelData
                        readonly property bool selected: SettingsStore[clockRow.modelData.modeKey] === modelData.key
                        objectName: clockRow.modelData.modeKey + "-" + modelData.key
                        Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 9
                        color: selected ? Qt.alpha(Theme.accent, .16) : Theme.background
                        border.width: selected ? 1 : 0; border.color: Theme.accent
                        Text {
                            anchors.centerIn: parent; text: styleChoice.modelData.label
                            color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { SettingsStore[clockRow.modelData.modeKey] = styleChoice.modelData.key; SettingsStore.save(); }
                        }
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: clockRow.modelData.presets
                    delegate: Rectangle {
                        id: presetChoice
                        required property var modelData
                        readonly property bool selected: SettingsStore[clockRow.modelData.formatKey] === modelData.format
                        objectName: clockRow.modelData.formatKey + "-" + modelData.label
                        width: presetLabel.implicitWidth + 20; height: 30; radius: 8
                        color: selected ? Qt.alpha(Theme.accent, .16) : Theme.background
                        border.width: selected ? 1 : 0; border.color: Theme.accent
                        Text {
                            id: presetLabel
                            anchors.centerIn: parent; text: presetChoice.modelData.label
                            color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsStore.setClockFormat(clockRow.modelData.formatKey, presetChoice.modelData.format)
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40
                radius: 9; color: Theme.background
                border.width: 1
                border.color: formatInput.acceptableFormat ? (formatInput.activeFocus ? Theme.accent : Theme.borderaccent) : Theme.error
                TextInput {
                    id: formatInput
                    objectName: clockRow.modelData.formatKey + "-input"
                    readonly property bool acceptableFormat: SettingsStore.validClockFormat(text)
                    anchors.fill: parent; anchors.margins: 10
                    text: SettingsStore[clockRow.modelData.formatKey]
                    color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true; selectByMouse: true; maximumLength: 120
                    onEditingFinished: {
                        if (SettingsStore.setClockFormat(clockRow.modelData.formatKey, text))
                            text = Qt.binding(() => SettingsStore[clockRow.modelData.formatKey]);
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: formatInput.acceptableFormat ? "Custom format · press Enter or leave the field to save." : "Enter 1–120 characters on a single line."
                color: formatInput.acceptableFormat ? Theme.muted : Theme.error
                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); wrapMode: Text.WordWrap
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: "HH:mm = 20:30 · ss = seconds · dddd = Friday · d = 13 · MMMM = November · yyyy = 2026. Put literal words in single quotes.\nExample: HH:mm dddd, d MMMM yyyy. Formats are case-sensitive. Long labels wrap on vertical bars. Show or hide Clock and Calendar in Modules."
        color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        wrapMode: Text.WordWrap
    }
}
