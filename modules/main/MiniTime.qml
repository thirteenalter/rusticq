import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../config"
import "../../components"

Item {
    id: root
    objectName: "clock-popup-widget"
    implicitHeight: content.implicitHeight + Theme.sectionPadding * 2
    property bool advancedTimer: false
    property bool alarmView: false
    readonly property bool editingDuration: Store.clockTimerState === "idle" || Store.clockTimerState === "finished"
    readonly property int draftSeconds: {
        if (durationFields.count !== 3) return Store.clockTimerDurationSeconds;
        let seconds = 0;
        for (let i = 0; i < durationFields.count; i++) {
            const field = durationFields.itemAt(i);
            if (!field || !field.valid) return 0;
            seconds += Number(field.inputText) * field.modelData.multiplier;
        }
        return seconds;
    }

    function syncDurationFields() {
        for (let i = 0; i < durationFields.count; i++) {
            const field = durationFields.itemAt(i);
            if (field) field.inputText = String(Math.floor(Store.clockTimerDurationSeconds / field.modelData.multiplier)
                % (field.modelData.maximum + 1)).padStart(2, "0");
        }
    }
    function activateTimer() {
        if (Store.clockTimerState === "running") Store.pauseClockTimer();
        else {
            if (root.editingDuration && !Store.setClockTimerDuration(root.draftSeconds)) return;
            Store.startClockTimer();
        }
    }
    Connections {
        target: Store
        function onClockTimerDurationSecondsChanged() { root.syncDurationFields(); }
    }
    onAdvancedTimerChanged: viewport.contentY = 0
    onAlarmViewChanged: viewport.contentY = 0
    SystemClock { id: liveClock; precision: SystemClock.Seconds }

    Flickable {
        id: viewport
        objectName: "clock-timer-viewport"
        anchors.fill: parent
        contentHeight: content.implicitHeight + Theme.sectionPadding * 2
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollIndicator.vertical: ScrollIndicator {}
        ColumnLayout {
            id: content
            x: Theme.sectionPadding
            y: Theme.sectionPadding
            width: Math.max(0, viewport.width - Theme.sectionPadding * 2)
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Icon { icon: root.alarmView ? "\ue855" : root.advancedTimer ? "\ue425" : "\ue8b5"; font.pixelSize: Fonts.scale(22); color: Theme.accent }
                Text {
                    text: root.alarmView ? "Alarm" : root.advancedTimer ? "Timer" : "Time"
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(16)
                    color: Theme.foreground
                    Layout.fillWidth: true
                }
                ActionButton {
                    objectName: "clock-timer-back"
                    visible: root.advancedTimer || root.alarmView
                    label: "Back"
                    symbol: "\ue5c4"
                    onClicked: { root.advancedTimer = false; root.alarmView = false; }
                }
            }
            ColumnLayout {
                visible: Store.clockAlertKind !== ""
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: Store.clockAlertKind === "alarm" ? "Alarm · " + Store.clockAlarmTime : "Time’s up!"
                    color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(14)
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ActionButton { objectName: "clock-alert-stop"; Layout.fillWidth: true; label: "Stop"; symbol: "\ue047"; onClicked: Store.dismissClockAlert() }
                    ActionButton {
                        objectName: "clock-alert-snooze"
                        visible: Store.clockAlertKind === "alarm"
                        Layout.fillWidth: true
                        label: "Snooze 5 min"
                        onClicked: Store.snoozeClockAlarm()
                    }
                }
            }
            Text {
                objectName: "clock-live-time"
                visible: !root.advancedTimer && !root.alarmView
                text: Qt.formatDateTime(liveClock.date, "HH:mm:ss")
                font.family: Fonts.poppinsSB.name
                font.pixelSize: Fonts.scale(34)
                color: Theme.foreground
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                visible: !root.advancedTimer && !root.alarmView
                text: Qt.formatDateTime(liveClock.date, "dddd, dd MMMM yyyy")
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(12)
                color: Theme.muted
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            RowLayout {
                visible: !root.advancedTimer && !root.alarmView
                Layout.fillWidth: true
                spacing: 8
                ActionButton {
                    objectName: "clock-timer-advanced"
                    Layout.fillWidth: true
                    label: "Advanced"
                    symbol: "\ue425"
                    onClicked: root.advancedTimer = true
                }
                ActionButton {
                    objectName: "clock-alarm-open"
                    Layout.fillWidth: true
                    label: "Alarm"
                    symbol: "\ue855"
                    selected: SettingsStore.clockAlarmEnabled || Store.clockAlarmSnoozeUntil > 0
                    onClicked: root.alarmView = true
                }
            }
            ClockAlarmControls { visible: root.alarmView; Layout.fillWidth: true }
            ColumnLayout {
                visible: root.advancedTimer && !root.alarmView
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: Store.clockTimerState === "running" ? "Running"
                        : Store.clockTimerState === "paused" ? "Paused"
                        : Store.clockTimerState === "finished" ? "Time’s up!" : "Set a duration"
                    color: Store.clockTimerState === "finished" ? Theme.accent : Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(11)
                }
                RowLayout {
                    visible: root.editingDuration
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        id: durationFields
                        model: [
                            {label: "Hours", key: "hours", multiplier: 3600, maximum: 23},
                            {label: "Minutes", key: "minutes", multiplier: 60, maximum: 59},
                            {label: "Seconds", key: "seconds", multiplier: 1, maximum: 59}
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            property alias inputText: durationInput.text
                            readonly property bool valid: durationInput.acceptableInput
                            Layout.fillWidth: true
                            implicitHeight: 78
                            radius: Theme.rowRadius
                            color: Theme.surface
                            border.width: durationInput.activeFocus ? 1 : 0
                            border.color: Theme.accent
                            Text {
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(10)
                            }
                            TextInput {
                                id: durationInput
                                objectName: "clock-timer-" + modelData.key
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 28
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: String(Math.floor(Store.clockTimerDurationSeconds / modelData.multiplier)
                                    % (modelData.maximum + 1)).padStart(2, "0")
                                color: acceptableInput ? Theme.foreground : Theme.error
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(26)
                                horizontalAlignment: TextInput.AlignHCenter
                                verticalAlignment: TextInput.AlignVCenter
                                maximumLength: 2
                                selectByMouse: true
                                activeFocusOnTab: true
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator: IntValidator { bottom: 0; top: modelData.maximum }
                                Accessible.name: "Timer " + modelData.label.toLowerCase()
                                onActiveFocusChanged: if (activeFocus) selectAll()
                                Keys.onReturnPressed: if (root.advancedTimer && root.draftSeconds > 0) root.activateTimer()
                            }
                        }
                    }
                }
                Text {
                    objectName: "clock-timer-remaining"
                    visible: !root.editingDuration || Store.clockTimerState === "finished"
                    Layout.fillWidth: true
                    text: Store.formatClockTimer(Store.clockTimerRemainingSeconds)
                    horizontalAlignment: Text.AlignHCenter
                    color: Store.clockTimerState === "finished" ? Theme.accent : Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(34)
                }
                RowLayout {
                    visible: root.editingDuration
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [60, 300, 900, 1500]
                        delegate: ActionButton {
                            required property int modelData
                            objectName: "clock-timer-preset-" + modelData
                            Layout.fillWidth: true
                            label: (modelData / 60) + " min"
                            selected: root.draftSeconds === modelData
                            onClicked: {
                                Store.setClockTimerDuration(modelData);
                                root.syncDurationFields();
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.editingDuration && root.draftSeconds < 1 ? "Choose at least 1 second."
                        : Store.clockTimerState === "finished" ? "Ready for another timer."
                        : Store.clockTimerState === "paused" ? "Resume when you’re ready."
                        : "Keeps running when this popup is closed."
                    color: root.editingDuration && root.draftSeconds < 1 ? Theme.error : Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(10)
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ActionButton {
                        objectName: "clock-timer-start"
                        Layout.fillWidth: true
                        label: Store.clockTimerState === "running" ? "Pause"
                            : Store.clockTimerState === "paused" ? "Resume"
                            : Store.clockTimerState === "finished" ? "Start again" : "Start"
                        symbol: Store.clockTimerState === "running" ? "\ue034" : "\ue037"
                        selected: true
                        enabled: !root.editingDuration || root.draftSeconds > 0
                        onClicked: root.activateTimer()
                    }
                    ActionButton {
                        objectName: "clock-timer-reset"
                        Layout.fillWidth: true
                        label: "Reset"
                        symbol: "\ue042"
                        onClicked: {
                            Store.resetClockTimer();
                            root.syncDurationFields();
                        }
                    }
                }
            }
            Text {
                visible: Store.clockSoundError.length > 0
                Layout.fillWidth: true
                text: Store.clockSoundError
                color: Theme.error
                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                wrapMode: Text.WordWrap
            }
        }
    }
}
