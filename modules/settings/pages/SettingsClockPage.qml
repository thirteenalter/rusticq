import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import "../../../modules/main"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: Theme.sectionGap
    SettingsSection {
        heading: "Clock & calendar"
        description: "Format and language for the bar clock and calendar."
        symbol: "\ue8b5"
        ClockSettingsEditor { Layout.fillWidth: true }
    }
    SettingsSection {
        heading: "Alarm"
        description: "Set a local alarm once or every day. Stop and Snooze are also available in the clock popup."
        symbol: "\ue855"
        ClockAlarmControls { Layout.fillWidth: true }
    }
    ClockSoundSettings {}
}
