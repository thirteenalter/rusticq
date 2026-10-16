import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

Rectangle {
    id: root
    Layout.fillWidth: true
    property bool expanded: false
    Layout.preferredHeight: expanded ? Math.min(380, Math.max(195, 120 + NotificationCenter.history.length * 75)) : 62
    radius: Theme.sectionRadius
    color: Theme.surface
    border.color: Theme.borderaccent
    clip: true
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 13; spacing: 9
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 35; radius: 8; color: "transparent"
            RowLayout {
                anchors.fill: parent; spacing: 8
                Icon { icon: "\ue7f4"; color: Theme.accent; font.pixelSize: 19 }
                Text { text: "Notifications"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: 14; font.family: Fonts.poppinsSB.name }
                Text { text: String(NotificationCenter.history.length); color: Theme.muted; font.pixelSize: 11; font.family: Fonts.poppins.name }
                Icon { icon: root.expanded ? "\ue5ce" : "\ue5cf"; font.pixelSize: 18; color: Theme.foreground }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.expanded = !root.expanded;
                    if (root.expanded) NotificationCenter.markRead();
                }
            }
        }
        RowLayout {
            visible: root.expanded; Layout.fillWidth: true; spacing: 8
            Text { text: NotificationCenter.doNotDisturb ? "Do Not Disturb on" : "Do Not Disturb off"; Layout.fillWidth: true; color: Theme.muted; font.pixelSize: 10; font.family: Fonts.poppins.name }
            Rectangle {
                Layout.preferredWidth: 48; Layout.preferredHeight: 26; radius: 8; color: Theme.background
                Text { anchors.centerIn: parent; text: "DND"; color: NotificationCenter.doNotDisturb ? Theme.accent : Theme.foreground; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; onClicked: NotificationCenter.doNotDisturb = !NotificationCenter.doNotDisturb }
            }
            Rectangle {
                Layout.preferredWidth: 54; Layout.preferredHeight: 26; radius: 8; color: Theme.background
                Text { anchors.centerIn: parent; text: "Clear"; color: Theme.foreground; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; onClicked: NotificationCenter.clear() }
            }
        }
        ListView {
            visible: root.expanded; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            spacing: 6; model: NotificationCenter.history
            delegate: Rectangle {
                id: itemRow
                required property var modelData
                width: ListView.view.width; height: 66; radius: 9; color: Theme.background
                RowLayout {
                    anchors.fill: parent; anchors.margins: 9; spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: itemRow.modelData.app + " · " + itemRow.modelData.when; font.pixelSize: 9; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: itemRow.modelData.title; font.pixelSize: 11; font.family: Fonts.poppinsSB.name; color: Theme.foreground; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: itemRow.modelData.body.replace(/<[^>]*>/g, ""); font.pixelSize: 10; color: Theme.muted; maximumLineCount: 1; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Rectangle {
                        Layout.preferredWidth: 24; Layout.preferredHeight: 24; color: "transparent"
                        Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: Theme.muted; font.pixelSize: 16 }
                        MouseArea { anchors.fill: parent; onClicked: NotificationCenter.dismiss(itemRow.modelData.serial) }
                    }
                }
            }
            Text { visible: NotificationCenter.history.length === 0; anchors.centerIn: parent; text: "No notifications yet"; font.family: Fonts.poppins.name; font.pixelSize: 11; color: Theme.muted }
        }
    }
}
