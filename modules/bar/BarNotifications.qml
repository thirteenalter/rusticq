import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../services"
import "../../components"

Rectangle {
    id: root
    Layout.fillWidth: true
    property bool expanded: false
    Layout.preferredHeight: expanded ? Math.min(520, Math.max(320, 212 + NotificationCenter.history.length * 92 + (NotificationCenter.receivesSystemNotifications ? 0 : 130))) : 66
    radius: Theme.sectionRadius
    color: Qt.alpha(Theme.foreground, 0.02)
    border.color: Theme.borderaccent
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 13
        spacing: 10

        SectionHeader {
            Layout.fillWidth: true
            title: "Notifications"
            iconName: "\ue7f4"
            expanded: root.expanded
            onToggleRequested: {
                root.expanded = !root.expanded;
                if (root.expanded) NotificationCenter.markRead();
            }
        }

        RowLayout {
            visible: root.expanded
            Layout.fillWidth: true
            Text {
                text: NotificationCenter.unread > 0 ? NotificationCenter.unread + " unread" : "All caught up"
                Layout.fillWidth: true
                color: Theme.muted
                font.family: Fonts.poppins.name
                font.pixelSize: 10
            }
            Text {
                text: NotificationCenter.history.length + " saved"
                color: Theme.muted
                font.family: Fonts.poppins.name
                font.pixelSize: 10
            }
        }

        Rectangle {
            visible: root.expanded && !NotificationCenter.receivesSystemNotifications
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 130 : 0
            radius: 11
            color: Theme.background
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 5
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    Icon { icon: "\ue002"; color: Theme.accent; font.pixelSize: 16 }
                    Text {
                        Layout.fillWidth: true
                        text: NotificationCenter.serverState === "conflict" ? "Another notification service is active"
                            : NotificationCenter.serverState === "free" ? "Waiting for notification ownership"
                            : "Checking notification service"
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: 10
                        color: Theme.foreground
                        elide: Text.ElideRight
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Owner: " + NotificationCenter.serverOwner
                    font.family: Fonts.poppins.name
                    font.pixelSize: 10
                    color: Theme.muted
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: NotificationCenter.serverAdvice
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: 9
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 29
                        radius: 8
                        color: Theme.surface
                        Text { anchors.centerIn: parent; text: "Preview toast"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 10 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationCenter.previewNotification()
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 77
                        Layout.preferredHeight: 29
                        radius: 8
                        color: Theme.surface
                        Text { anchors.centerIn: parent; text: "Recheck"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 10 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationCenter.refreshServerStatus()
                        }
                    }
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

        Rectangle {
            visible: root.expanded && NotificationCenter.receivesSystemNotifications
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 32 : 0
            radius: 10
            color: Theme.background
            RowLayout {
                anchors.centerIn: parent
                spacing: 7
                Icon { icon: "\ue7f4"; font.pixelSize: 16; color: Theme.accent }
                Text { text: "Send test notification"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 10 }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["notify-send", "-a", "RusticQ", "RusticQ test", "The notification service is working."])
            }
        }

        ListView {
            visible: root.expanded
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: NotificationCenter.history
            delegate: Rectangle {
                id: itemRow
                required property var modelData
                readonly property bool hasPreview: String(modelData.image || "").length > 0
                readonly property bool isScreenshot: modelData.kind === "screenshot"
                width: ListView.view.width
                height: hasPreview ? 96 : 82
                radius: 14
                color: Theme.background
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 12
                        color: Qt.alpha(Theme.accent, 0.12)
                        Icon {
                            anchors.centerIn: parent
                            icon: itemRow.modelData.glyph
                            color: Theme.accent
                            font.pixelSize: 18
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: itemRow.modelData.app
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pixelSize: 10
                                color: Theme.foreground
                                font.family: Fonts.poppinsSB.name
                                textFormat: Text.PlainText
                            }
                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: typeLabel.implicitWidth + 18
                                radius: 8
                                color: Qt.alpha(Theme.accent, 0.10)
                                Text {
                                    id: typeLabel
                                    anchors.centerIn: parent
                                    text: itemRow.modelData.tag
                                    color: Theme.foreground
                                    font.pixelSize: 8
                                    font.family: Fonts.poppins.name
                                }
                            }
                            Text {
                                text: itemRow.modelData.when
                                font.pixelSize: 9
                                color: Theme.muted
                                font.family: Fonts.poppins.name
                                textFormat: Text.PlainText
                            }
                        }

                        Text {
                            text: itemRow.modelData.title
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            font.family: Fonts.poppinsSB.name
                            color: Theme.foreground
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            wrapMode: Text.WordWrap
                            textFormat: Text.PlainText
                        }

                        Text {
                            text: itemRow.modelData.body
                            Layout.fillWidth: true
                            font.pixelSize: 10
                            color: Theme.muted
                            maximumLineCount: hasPreview ? 2 : 2
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }

                    Rectangle {
                        visible: hasPreview
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 58
                        radius: 12
                        clip: true
                        color: Theme.surface
                        border.width: 1
                        border.color: Qt.alpha(Theme.accent, 0.18)

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            source: itemRow.hasPreview ? itemRow.modelData.image : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            visible: status === Image.Ready
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !previewImage.visible
                            icon: itemRow.isScreenshot ? "\ue3b0" : "\ue2c7"
                            color: Theme.accent
                            font.pixelSize: 18
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
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
