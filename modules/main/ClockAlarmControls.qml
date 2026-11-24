import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

ColumnLayout {
    id: root
    spacing: 12
    property bool daily: SettingsStore.clockAlarmDaily
    readonly property bool valid: hourInput.acceptableInput && minuteInput.acceptableInput
    function sync() {
        hourInput.text = String(SettingsStore.clockAlarmHour).padStart(2, "0");
        minuteInput.text = String(SettingsStore.clockAlarmMinute).padStart(2, "0");
        daily = SettingsStore.clockAlarmDaily;
    }
    Connections {
        target: SettingsStore
        function onClockAlarmHourChanged() { root.sync(); }
        function onClockAlarmMinuteChanged() { root.sync(); }
        function onClockAlarmDailyChanged() { root.sync(); }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 78
            radius: Theme.rowRadius
            color: Theme.surface
            border.width: hourInput.activeFocus ? 1 : 0
            border.color: Theme.accent
            Text {
                anchors.top: parent.top; anchors.topMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
                text: "Hours · 24h"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
            }
            TextInput {
                id: hourInput
                objectName: "clock-alarm-hours"
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 28; bottomMargin: 6 }
                text: String(SettingsStore.clockAlarmHour).padStart(2, "0")
                color: acceptableInput ? Theme.foreground : Theme.error
                font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(26)
                horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter
                maximumLength: 2; selectByMouse: true; activeFocusOnTab: true
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 23 }
                Accessible.name: "Alarm hours"
                onActiveFocusChanged: if (activeFocus) selectAll()
            }
        }
        Text { text: ":"; color: Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(26) }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 78
            radius: Theme.rowRadius
            color: Theme.surface
            border.width: minuteInput.activeFocus ? 1 : 0
            border.color: Theme.accent
            Text {
                anchors.top: parent.top; anchors.topMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
                text: "Minutes"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
            }
            TextInput {
                id: minuteInput
                objectName: "clock-alarm-minutes"
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 28; bottomMargin: 6 }
                text: String(SettingsStore.clockAlarmMinute).padStart(2, "0")
                color: acceptableInput ? Theme.foreground : Theme.error
                font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(26)
                horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter
                maximumLength: 2; selectByMouse: true; activeFocusOnTab: true
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 59 }
                Accessible.name: "Alarm minutes"
                onActiveFocusChanged: if (activeFocus) selectAll()
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ActionButton { objectName: "clock-alarm-once"; Layout.fillWidth: true; label: "Once"; selected: !root.daily; onClicked: root.daily = false }
        ActionButton { objectName: "clock-alarm-daily"; Layout.fillWidth: true; label: "Every day"; selected: root.daily; onClicked: root.daily = true }
    }
    Text {
        objectName: "clock-alarm-status"
        Layout.fillWidth: true
        text: Store.clockAlarmSnoozeUntil > 0
            ? "Snoozed until " + Qt.formatTime(new Date(Store.clockAlarmSnoozeUntil), "HH:mm")
            : SettingsStore.clockAlarmEnabled
                ? "Next: " + Qt.formatDateTime(new Date(SettingsStore.clockAlarmNextAt), "ddd, dd MMM · HH:mm")
                    + (SettingsStore.clockAlarmDaily ? " · every day" : " · once")
                : "Alarm is off."
        color: SettingsStore.clockAlarmEnabled || Store.clockAlarmSnoozeUntil > 0 ? Theme.accent : Theme.muted
        font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        wrapMode: Text.WordWrap
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ActionButton {
            objectName: "clock-alarm-save"
            Layout.fillWidth: true
            label: SettingsStore.clockAlarmEnabled ? "Update alarm" : "Set alarm"
            symbol: "\ue855"
            selected: true
            enabled: root.valid
            onClicked: {
                // Capture drafts before SettingsStore change signals resync the inputs.
                const hour = Number(hourInput.text), minute = Number(minuteInput.text), repeat = root.daily;
                Store.clockAlarmSnoozeUntil = 0;
                if (Store.clockAlertKind === "alarm") Store.dismissClockAlert();
                SettingsStore.setClockAlarm(hour, minute, repeat);
            }
        }
        ActionButton {
            objectName: "clock-alarm-disable"
            Layout.fillWidth: true
            label: "Turn off"
            enabled: SettingsStore.clockAlarmEnabled || Store.clockAlarmSnoozeUntil > 0
            onClicked: Store.cancelClockAlarm()
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Uses local time. RusticQ must be running; alarms do not wake a sleeping computer."
        color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        wrapMode: Text.WordWrap
    }
}
