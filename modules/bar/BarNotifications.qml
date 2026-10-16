import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../../components"

Rectangle {
    id: root
    Layout.fillWidth: true
    property bool expanded: false
    Layout.preferredHeight: expanded ? Math.min(420, Math.max(220, 162 + NotificationCenter.history.length * 78)) : 66
    radius: Theme.sectionRadius
    color: Theme.surface
    border.color: Theme.borderaccent
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 13
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 11
            color: expanded ? Qt.alpha(Theme.accent, 0.08) : "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 10
                    color: Qt.alpha(Theme.accent, 0.14)
                    Icon { anchors.centerIn: parent; icon: "\ue7f4"; color: Theme.accent; font.pixelSize: 18 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { text: "Notifications"; color: Theme.foreground; font.pixelSize: 14; font.family: Fonts.poppinsSB.name }
                    Text { text: NotificationCenter.unread > 0 ? NotificationCenter.unread + " unread" : "Everything caught up"; color: Theme.muted; font.pixelSize: 10; font.family: Fonts.poppins.name }
                }
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 9
                    color: NotificationCenter.unread > 0 ? Qt.alpha(Theme.accent, 0.18) : Theme.background
                    Text { anchors.centerIn: parent; text: String(NotificationCenter.history.length); color: NotificationCenter.unread > 0 ? Theme.accent : Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
                }
                Icon { icon: root.expanded ? "\ue5ce" : "\ue5cf"; font.pixelSize: 18; color: Theme.foreground }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.expanded = !root.expanded;
                    if (root.expanded) NotificationCenter.markRead();
                }
            }
        }

        RowLayout {
            visible: root.expanded
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 10
                color: Theme.background
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 7
                    Icon { icon: NotificationCenter.doNotDisturb ? "\ue7f6" : "\ue7f4"; color: Theme.accent; font.pixelSize: 16 }
                    Text { text: NotificationCenter.doNotDisturb ? "Do Not Disturb enabled" : "Notifications active"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: 10; font.family: Fonts.poppins.name }
                }
            }
            Repeater {
                model: [
                    { label: NotificationCenter.doNotDisturb ? "DND On" : "DND Off", accent: NotificationCenter.doNotDisturb, action: "dnd" },
                    { label: "Clear", accent: false, action: "clear" }
                ]
                delegate: Rectangle {
                    id: actionPill
                    required property var modelData
                    Layout.preferredWidth: modelData.action === "clear" ? 60 : 74
                    Layout.preferredHeight: 32
                    radius: 10
                    color: modelData.accent ? Qt.alpha(Theme.accent, 0.18) : Theme.background
                    border.width: modelData.accent ? 1 : 0
                    border.color: Theme.accent
                    Text { anchors.centerIn: parent; text: actionPill.modelData.label; color: Theme.foreground; font.pixelSize: 10; font.family: Fonts.poppinsSB.name }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (actionPill.modelData.action === "dnd") NotificationCenter.doNotDisturb = !NotificationCenter.doNotDisturb;
                            else NotificationCenter.clear();
                        }
                    }
                }
            }
        }

        ListView {
            visible: root.expanded
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 7
            model: NotificationCenter.history
            delegate: Rectangle {
                id: itemRow
                required property var modelData
                width: ListView.view.width
                height: 72
                radius: 12
                color: Theme.background
                border.width: 1
                border.color: Qt.alpha(Theme.foreground, 0.04)
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 11
                        color: Qt.alpha(Theme.accent, 0.12)
                        Text { anchors.centerIn: parent; text: itemRow.modelData.appInitials; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: itemRow.modelData.app; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 10; color: Theme.foreground; font.family: Fonts.poppinsSB.name }
                            Text { text: itemRow.modelData.when; font.pixelSize: 9; color: Theme.muted; font.family: Fonts.poppins.name }
                        }
                        Text { text: itemRow.modelData.title; Layout.fillWidth: true; font.pixelSize: 11; font.family: Fonts.poppinsSB.name; color: Theme.foreground; elide: Text.ElideRight }
                        Text { text: itemRow.modelData.body; Layout.fillWidth: true; font.pixelSize: 10; color: Theme.muted; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight }
                    }
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 8
                        color: dismissMouse.containsMouse ? Qt.alpha(Theme.accent, 0.10) : "transparent"
                        Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: Theme.muted; font.pixelSize: 16 }
                        MouseArea {
                            id: dismissMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationCenter.dismiss(itemRow.modelData.serial)
                        }
                    }
                }
            }
            Text {
                visible: NotificationCenter.history.length === 0
                anchors.centerIn: parent
                text: "No notifications yet"
                font.family: Fonts.poppins.name
                font.pixelSize: 11
                color: Theme.muted
            }
        }
    }
}
