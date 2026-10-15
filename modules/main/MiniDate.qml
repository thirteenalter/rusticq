import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"

Item {
    id: root
    SystemClock { id: dateClock; precision: SystemClock.Minutes }
    property date displayedMonth: new Date(dateClock.date.getFullYear(), dateClock.date.getMonth(), 1)
    readonly property var weekdays: ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
    function dayAt(index) {
        const first = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth(), 1);
        const padding = (first.getDay() + 6) % 7;
        return new Date(first.getFullYear(), first.getMonth(), index - padding + 1);
    }
    function moveMonth(delta) {
        displayedMonth = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + delta, 1);
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        RowLayout {
            Icon { icon: "\uebcc"; font.pixelSize: 20; color: Theme.accent }
            Text { text: "Calendar"; font.family: Fonts.poppinsSB.name; font.pixelSize: 16; color: Theme.foreground; Layout.fillWidth: true }
            Icon { icon: "\ue5cb"; font.pixelSize: 20; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.moveMonth(-1) } }
            Icon { icon: "\ue5cc"; font.pixelSize: 20; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.moveMonth(1) } }
        }
        Text {
            text: Qt.formatDate(root.displayedMonth, "MMMM yyyy")
            font.family: Fonts.poppinsSB.name; font.pixelSize: 14; color: Theme.foreground
            Layout.alignment: Qt.AlignHCenter
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 2
            rowSpacing: 4
            Repeater {
                model: root.weekdays
                Text {
                    Layout.fillWidth: true; Layout.preferredHeight: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.muted
                    font.family: Fonts.poppins.name; font.pixelSize: 10
                }
            }
            Repeater {
                model: 42
                Rectangle {
                    id: dateCell
                    readonly property date cellDate: root.dayAt(index)
                    readonly property bool currentMonth: cellDate.getMonth() === root.displayedMonth.getMonth()
                    readonly property bool isToday: cellDate.toDateString() === dateClock.date.toDateString()
                    Layout.fillWidth: true; Layout.preferredHeight: 30
                    radius: 9
                    color: isToday ? Theme.accent : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: dateCell.cellDate.getDate()
                        font.family: Fonts.poppins.name; font.pixelSize: 11
                        color: dateCell.isToday ? Theme.background : dateCell.currentMonth ? Theme.foreground : Theme.muted
                        opacity: dateCell.currentMonth ? 1 : 0.5
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
        RowLayout {
            Icon { icon: "\ue8df"; font.pixelSize: 16; color: Theme.accent }
            Text { text: Qt.formatDate(dateClock.date, "dddd, dd MMMM yyyy"); font.family: Fonts.poppins.name; font.pixelSize: 11; color: Theme.foreground; Layout.fillWidth: true }
        }
        Item { Layout.fillHeight: true }
    }
}
