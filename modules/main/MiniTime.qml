import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"

Item {
    id: root
    SystemClock { id: liveClock; precision: SystemClock.Seconds }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 11
        RowLayout {
            Icon { icon: "\ue8b5"; font.pixelSize: Fonts.scale(22); color: Theme.accent }
            Text { text: "Time"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(16); color: Theme.foreground }
            Item { Layout.fillWidth: true }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
        Text {
            text: Qt.formatDateTime(liveClock.date, "HH:mm:ss")
            font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(34); color: Theme.foreground
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            text: Qt.formatDateTime(liveClock.date, "dddd, dd MMMM yyyy")
            font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12); color: Theme.muted
            Layout.alignment: Qt.AlignHCenter
        }
        Item { Layout.fillHeight: true }
    }
}
