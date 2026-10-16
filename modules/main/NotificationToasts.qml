import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../services"
import "../../components"

PanelWindow {
    id: toastWindow
    // An independent, non-exclusive layer, visible only while there is a toast.
    visible: SettingsStore.showNotifications && NotificationCenter.toast !== null
    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    margins { top: 55; right: 18 }
    implicitWidth: 350
    implicitHeight: 108
    color: "transparent"
    Rectangle {
        anchors.fill: parent; radius: 15; color: Theme.background
        border.color: Theme.borderaccent; border.width: 1
        RowLayout {
            anchors.fill: parent; anchors.margins: 15; spacing: 10
            Icon { icon: "\ue7f4"; font.pixelSize: 21; color: Theme.accent }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 3
                Text { text: NotificationCenter.toast ? NotificationCenter.toast.app : ""; font.pixelSize: 10; color: Theme.muted; font.family: Fonts.poppins.name }
                Text { text: NotificationCenter.toast ? NotificationCenter.toast.title : ""; font.pixelSize: 13; color: Theme.foreground; font.family: Fonts.poppinsSB.name; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { text: NotificationCenter.toast ? NotificationCenter.toast.body.replace(/<[^>]*>/g, "") : ""; font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight }
            }
            Rectangle {
                Layout.preferredWidth: 25; Layout.preferredHeight: 25; color: "transparent"
                Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: Theme.foreground; font.pixelSize: 18 }
                MouseArea { anchors.fill: parent; onClicked: NotificationCenter.toast = null }
            }
        }
    }
}
