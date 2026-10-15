import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"

Pill {
    id: root
    property bool showIcon: false
    property bool showDate: false
    color: "transparent"
    horizontalPadding: 6
    verticalPadding: 6

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        spacing: Theme.barInfoGap
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.barIconTextGap
            Icon {
                visible: root.showIcon
                icon: "\ue8b5"
                font.pixelSize: 14
                Layout.minimumWidth: Theme.barIconSlotSize
                Layout.preferredWidth: Theme.barIconSlotSize
                Layout.maximumWidth: Theme.barIconSlotSize
                Layout.preferredHeight: Theme.barIconSlotSize
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: root.showIcon ? Theme.controlTextSize : 13
                font.family: Fonts.poppins.name
                color: Theme.foreground
            }
        }
        RowLayout {
            visible: root.showDate
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.barIconTextGap
            Icon {
                icon: "\ue916"
                font.pixelSize: 14
                Layout.minimumWidth: Theme.barIconSlotSize
                Layout.preferredWidth: Theme.barIconSlotSize
                Layout.maximumWidth: Theme.barIconSlotSize
                Layout.preferredHeight: Theme.barIconSlotSize
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: Qt.formatDateTime(clock.date, "dd MMM")
                font.pixelSize: Theme.controlTextSize
                font.family: Fonts.poppins.name
                color: Theme.foreground
            }
        }
    }
}
