import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../services"
import "../../components"

Rectangle {
    id: root
    Layout.fillWidth: true
    property bool standalone: false
    property bool expanded: false
    Layout.preferredHeight: standalone ? 600 : expanded
        ? Math.min(700, Math.max(440, 320 + NotificationCenter.history.length * 116
            + (NotificationCenter.receivesSystemNotifications ? 0 : 130))) : 68
    radius: Theme.sectionRadius
    color: Qt.alpha(Theme.foreground, 0.02)
    border.color: Theme.borderaccent
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        SectionHeader {
            Layout.fillWidth: true
            title: "Notifications"
            iconName: "\ue7f4"
            expanded: root.expanded
            collapsible: !root.standalone
            onToggleRequested: {
                if (root.standalone) return;
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
                font.pixelSize: Fonts.scale(10)
            }
            Text {
                text: NotificationCenter.history.length + " saved"
                color: Theme.muted
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(10)
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
                    Icon { icon: "\ue002"; color: Theme.accent; font.pixelSize: Fonts.scale(16) }
                    Text {
                        Layout.fillWidth: true
                        text: NotificationCenter.serverState === "conflict" ? "Another notification service is active"
                            : NotificationCenter.serverState === "free" ? "Waiting for notification ownership"
                            : "Checking notification service"
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: Fonts.scale(10)
                        color: Theme.foreground
                        elide: Text.ElideRight
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Owner: " + NotificationCenter.serverOwner
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(10)
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
                    font.pixelSize: Fonts.scale(9)
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 29
                        radius: 8
                        color: Theme.surface
                        Text { anchors.centerIn: parent; text: "Preview toast"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
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
                        Text { anchors.centerIn: parent; text: "Recheck"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
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
            spacing: 10
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 10
                color: Theme.background
                RowLayout {
                    id: dndStatusRow
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 7
                    Icon { icon: NotificationCenter.doNotDisturb ? "\ue7f6" : "\ue7f4"; color: Theme.accent; font.pixelSize: Fonts.scale(16) }
                    Text { text: NotificationCenter.doNotDisturb ? "Do Not Disturb enabled" : "Notifications active"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppins.name }
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
                    Layout.preferredHeight: 34
                    radius: 10
                    color: modelData.accent ? Qt.alpha(Theme.accent, 0.18) : Theme.background
                    border.width: modelData.accent ? 1 : 0
                    border.color: Theme.accent
                    Text { anchors.centerIn: parent; text: actionPill.modelData.label; color: Theme.foreground; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppinsSB.name }
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
            visible: root.expanded
            Layout.fillWidth: true; Layout.preferredHeight: 31; radius: 9
            color: NotificationCenter.groupByApp ? Qt.alpha(Theme.accent, .16) : Theme.background
            RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                Icon { icon: "\ue8ef"; color: Theme.accent; font.pixelSize: Fonts.scale(16) }
                Text { Layout.fillWidth: true; text: NotificationCenter.groupByApp ? "Grouped by application" : "Individual notifications";
                    color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
                Text { text: "Toggle"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: NotificationCenter.groupByApp = !NotificationCenter.groupByApp }
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
                Icon { icon: "\ue7f4"; font.pixelSize: Fonts.scale(16); color: Theme.accent }
                Text { text: "Send test notification"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
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
            spacing: 10
            model: NotificationCenter.displayHistory
            delegate: Rectangle {
                id: itemRow
                required property var modelData
                readonly property bool hasPreview: String(modelData.image || "").length > 0
                readonly property bool isScreenshot: modelData.kind === "screenshot"
                width: ListView.view.width
                height: Math.max(hasPreview ? 110 : 94, contentLayout.implicitHeight + 24)
                radius: 14
                color: Theme.background
                border.width: 0

                RowLayout {
                    id: contentLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 12
                        color: Qt.alpha(Theme.accent, 0.12)
                        Icon {
                            anchors.centerIn: parent
                            icon: itemRow.modelData.glyph
                            color: Theme.accent
                            font.pixelSize: Fonts.scale(18)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: itemRow.modelData.app
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pixelSize: Fonts.scale(10)
                                color: Theme.foreground
                                font.family: Fonts.poppinsSB.name
                                textFormat: Text.PlainText
                            }
                            Rectangle {
                                visible: NotificationCenter.groupByApp && itemRow.modelData.groupCount > 1
                                Layout.preferredHeight: visible ? 22 : 0
                                Layout.preferredWidth: 62
                                radius: 8
                                color: Qt.alpha(Theme.accent, .17)
                                Text {
                                    anchors.centerIn: parent
                                    text: (itemRow.modelData.groupCount || 1) + " · " +
                                        (NotificationCenter.expandedApps[itemRow.modelData.app] ? "Hide" : "Show")
                                    color: Theme.accent; font.pixelSize: Fonts.scale(9)
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationCenter.toggleGroup(itemRow.modelData.app) }
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
                                    font.pixelSize: Fonts.scale(8)
                                    font.family: Fonts.poppins.name
                                }
                            }
                            Text {
                                text: itemRow.modelData.when
                                font.pixelSize: Fonts.scale(9)
                                color: Theme.muted
                                font.family: Fonts.poppins.name
                                textFormat: Text.PlainText
                            }
                        }

                        Text {
                            text: itemRow.modelData.title
                            Layout.fillWidth: true
                            font.pixelSize: Fonts.scale(11)
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
                            font.pixelSize: Fonts.scale(10)
                            color: Theme.muted
                            maximumLineCount: hasPreview ? 2 : 3
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        RowLayout {
                            visible: itemRow.modelData.actions && itemRow.modelData.actions.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? 30 : 0
                            spacing: 6
                            Repeater {
                                model: itemRow.modelData.actions ? itemRow.modelData.actions.length : 0
                                delegate: Rectangle {
                                    id: historyAction
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 9
                                    color: index === 0 ? Qt.alpha(Theme.accent, 0.16) : Theme.surface
                                    Text {
                                        anchors.centerIn: parent
                                        text: itemRow.modelData.actions[historyAction.index].text
                                        color: index === 0 ? Theme.accent : Theme.foreground
                                        font.family: Fonts.poppinsSB.name
                                        font.pixelSize: Fonts.scale(10)
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotificationCenter.invokeAction(itemRow.modelData.serial, itemRow.modelData.actions[historyAction.index].sourceIndex)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: hasPreview
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
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
                            font.pixelSize: Fonts.scale(18)
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 8
                        color: dismissMouse.containsMouse ? Qt.alpha(Theme.accent, 0.10) : "transparent"
                        Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: Theme.muted; font.pixelSize: Fonts.scale(16) }
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
                font.pixelSize: Fonts.scale(11)
                color: Theme.muted
            }
        }
    }
}
