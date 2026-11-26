import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

Rectangle {
    id: root
    implicitHeight: ethernetContent.implicitHeight + Theme.panelPadding * 2
    radius: Theme.glassRadius("card", Theme.sectionRadius)
    color: Theme.glassEnabled ? "transparent" : Theme.background
    border.width: Theme.glassBorderWidth("card", 0)
    ColumnLayout {
        id: ethernetContent
        objectName: "surfaceContent"
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: Theme.contentGap
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Theme.glassRadius("card", 11)
                color: Theme.glassColor("card", Qt.alpha(Theme.accent, 0.13))
                Icon { anchors.centerIn: parent; icon: "\ue1e2"; font.pixelSize: 21; color: Theme.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                GlassLabel { text: "Ethernet connected"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13); color: Theme.foreground }
                GlassLabel { text: WifiService.ethernetName || "Wired connection"; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); color: Theme.contentMuted }
            }
            Icon { icon: "\ue5ca"; color: Theme.accent; font.pixelSize: 19 }
        }
        Item { Layout.fillWidth: true; Layout.preferredHeight: Theme.sectionGap }
        GlassLabel {
            Layout.fillWidth: true
            text: "A wired network connection is active. This bar shortcut shows Ethernet information instead of Wi-Fi settings."
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(11)
            color: Theme.foreground
            wrapMode: Text.WordWrap
        }
        GlassLabel {
            Layout.fillWidth: true
            text: "Wi-Fi can still be managed separately through Quick Control or NetworkManager."
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(10)
            color: Theme.contentMuted
            wrapMode: Text.WordWrap
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 29
            radius: Theme.glassRadius("card", 9)
            color: Theme.glassColor("card", Theme.surface)
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Icon { icon: "\ue1e2"; font.pixelSize: 16; color: Theme.accent }
                GlassLabel { text: WifiService.ethernetMbps > 0 ? "Link " + WifiService.ethernetMbps + " Mb/s" : "Wired link active"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10); color: Theme.foreground }
            }
        }
    }
}
