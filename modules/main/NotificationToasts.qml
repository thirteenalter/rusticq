import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../services"
import "../../components"

PanelWindow {
    id: toastWindow
    property var currentToast: NotificationCenter.toast
    readonly property bool hasPreview: currentToast && String(currentToast.image || "").length > 0
    readonly property bool isScreenshot: currentToast && currentToast.kind === "screenshot"

    visible: SettingsStore.showNotifications && currentToast !== null
    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    margins { top: 55; right: 18 }
    implicitWidth: hasPreview ? 432 : 404
    implicitHeight: hasPreview ? 168 : 140
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.background
        border.color: Theme.borderaccent
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 14
            width: 4
            radius: 2
            color: isScreenshot ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            anchors.leftMargin: 26
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 14
                        color: Qt.alpha(Theme.accent, 0.14)
                        Icon {
                            anchors.centerIn: parent
                            icon: currentToast ? currentToast.glyph : "\ue7f4"
                            color: Theme.accent
                            font.pixelSize: 20
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: currentToast ? currentToast.app : ""
                            elide: Text.ElideRight
                            color: Theme.foreground
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: 11
                            textFormat: Text.PlainText
                        }
                        Text {
                            Layout.fillWidth: true
                            text: currentToast ? currentToast.tag : ""
                            elide: Text.ElideRight
                            color: Theme.muted
                            font.family: Fonts.poppins.name
                            font.pixelSize: 9
                            textFormat: Text.PlainText
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: 58
                        radius: 9
                        color: Qt.alpha(Theme.accent, 0.10)
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Icon { icon: "\ue7f4"; font.pixelSize: 14; color: Theme.accent }
                            Text {
                                text: currentToast ? currentToast.when : ""
                                color: Theme.foreground
                                font.family: Fonts.poppins.name
                                font.pixelSize: 9
                                textFormat: Text.PlainText
                            }
                        }
                    }

                    Rectangle {
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

                Text {
                    Layout.fillWidth: true
                    text: currentToast ? currentToast.title : ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: hasPreview ? 2 : 2
                    elide: Text.ElideRight
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: 14
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    text: currentToast ? currentToast.body : ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: hasPreview ? 2 : 3
                    elide: Text.ElideRight
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: 11
                    textFormat: Text.PlainText
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        visible: currentToast !== null
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: badgeText.implicitWidth + 24
                        radius: 9
                        color: Qt.alpha(Theme.foreground, 0.05)
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Icon { icon: isScreenshot ? "\ue3b0" : "\ue7f4"; color: Theme.accent; font.pixelSize: 14 }
                            Text {
                                id: badgeText
                                text: isScreenshot ? "Saved capture" : "Desktop notification"
                                color: Theme.foreground
                                font.family: Fonts.poppins.name
                                font.pixelSize: 9
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            Rectangle {
                visible: hasPreview
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 102
                Layout.preferredHeight: 102
                radius: 16
                clip: true
                color: Theme.surface
                border.color: Qt.alpha(Theme.accent, 0.20)
                border.width: 1

                Image {
                    id: previewImage
                    anchors.fill: parent
                    source: hasPreview ? currentToast.image : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: !previewImage.visible
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: "\ue3b0"; color: Theme.accent; font.pixelSize: 20 }
                    Text {
                        text: "Preview"
                        color: Theme.muted
                        font.family: Fonts.poppins.name
                        font.pixelSize: 9
                    }
                }
            }
        }
    }
}
