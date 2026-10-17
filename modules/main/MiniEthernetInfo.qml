import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

Rectangle {
    id: root
    radius: Theme.sectionRadius
    color: Theme.background
    border.width: 0
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 19
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 11
                color: Qt.alpha(Theme.accent, 0.13)
                Icon { anchors.centerIn: parent; icon: "\ue1e2"; font.pixelSize: 21; color: Theme.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "Ethernet connected"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13); color: Theme.foreground }
                Text { text: WifiService.ethernetName || "Wired connection"; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); color: Theme.muted }
            }
            Icon { icon: "\ue5ca"; color: Theme.accent; font.pixelSize: 19 }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
        Text {
            Layout.fillWidth: true
            text: "A wired network connection is active. This bar shortcut shows Ethernet information instead of Wi-Fi settings."
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(11)
            color: Theme.foreground
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            text: "Wi-Fi can still be managed separately through Quick Control or NetworkManager."
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(10)
            color: Theme.muted
            wrapMode: Text.WordWrap
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 29
            radius: 9
            color: Theme.surface
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Icon { icon: "\ue1e2"; font.pixelSize: 16; color: Theme.accent }
                Text { text: WifiService.ethernetMbps > 0 ? "Link " + WifiService.ethernetMbps + " Mb/s" : "Wired link active"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10); color: Theme.foreground }
            }
        }
    }
}
