import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../services"
import "../../components"

PanelWindow {
    id: toastWindow
    visible: SettingsStore.showNotifications && NotificationCenter.toast !== null
    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    margins { top: 55; right: 18 }
    implicitWidth: 368
    implicitHeight: 122
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Theme.background
        border.color: Theme.borderaccent
        border.width: 1

        Rectangle {
            width: 4
            radius: 2
            color: Theme.accent
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 16
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            anchors.leftMargin: 24
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 14
                color: Qt.alpha(Theme.accent, 0.14)
                Text {
                    anchors.centerIn: parent
                    text: NotificationCenter.toast ? NotificationCenter.toast.appInitials : "N"
                    color: Theme.accent
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: 13
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: NotificationCenter.toast ? NotificationCenter.toast.app : ""
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: Theme.foreground
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: 11
                    }
                    Rectangle {
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 22
                        radius: 8
                        color: Qt.alpha(Theme.accent, 0.10)
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { icon: "\ue7f4"; font.pixelSize: 14; color: Theme.accent }
                            Text { text: NotificationCenter.toast ? NotificationCenter.toast.when : ""; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 9 }
                        }
                    }
                }

                Text {
                    text: NotificationCenter.toast ? NotificationCenter.toast.title : ""
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: 13
                }
                Text {
                    text: NotificationCenter.toast ? NotificationCenter.toast.body : ""
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 9
                color: closeMouse.containsMouse ? Qt.alpha(Theme.accent, 0.12) : "transparent"
                Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: Theme.foreground; font.pixelSize: 18 }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationCenter.toast = null
                }
            }
        }
    }
}
