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
                            Icon { Layout.alignment: Qt.AlignHCenter; icon: previewCard.modelData.icon; font.pixelSize: 19; color: Theme.accent }
                            Text { Layout.alignment: Qt.AlignHCenter; text: previewCard.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
                            Text { Layout.alignment: Qt.AlignHCenter; text: previewCard.modelData.line; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 9 }
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Drag any widget by its top header to move it. Positions stay anchored to the current monitor and are saved."
            font.family: Fonts.poppins.name
            font.pixelSize: 11
            color: Theme.muted
            wrapMode: Text.WordWrap
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 10
            color: Theme.background
            Text { anchors.centerIn: parent; text: "Reset desktop widget positions"; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetWidgetPositions() }
        }
        Repeater {
            model: [
                {label:"Calendar widget",desc:"Monthly calendar behind application windows",key:"desktopCalendar",icon:"\ue916"},
                {label:"System widget",desc:"CPU, memory and disk usage",key:"desktopSystem",icon:"\ue1db"},
                {label:"Clock widget",desc:"Large time and date",key:"desktopClock",icon:"\ue8b5"},
                {label:"Now Playing widget",desc:"MPRIS media details and playback controls",key:"desktopMedia",icon:"\ue405"},
                {label:"Weather widget",desc:"Live forecast conditions from the weather service",key:"desktopWeather",icon:"\ue430"},
                {label:"Connectivity widget",desc:"Wi-Fi, Bluetooth and battery summary",key:"desktopConnectivity",icon:"\ue1d8"}
            ]
            delegate: SettingsToggle {}
        }
    }
}
