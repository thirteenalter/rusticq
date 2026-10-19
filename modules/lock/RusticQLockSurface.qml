import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"

// RusticQ's actual secure Wayland session-lock surface. This is a presentation
// only: the separate lockscreen.qml controller owns PAM and unlock permission.
// Match the desktop MiniLauncher and PowerMenu: shared Theme/Fonts, one-pixel
// borderaccent frame, sectionRadius, rowRadius and consistent column alignment.
WlSessionLockSurface {
    id: surface
    required property var controller
    color: Theme.background
    property date now: new Date()
    readonly property bool wallpaperEnabled: SettingsStore.lockscreenBackground === "wallpaper"
        && String(SettingsStore.wallpaperPath).startsWith("/")
    readonly property bool compact: height < 690
    readonly property bool shortScreen: height < 580
    readonly property int contentWidth: Math.min(460, Math.max(270, width - 36))
    readonly property int insideMargin: compact ? 16 : 20
    readonly property int fieldHeight: compact ? 46 : 50

    onVisibleChanged: if (visible) Qt.callLater(function() { passwordInput.forceActiveFocus(); })

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: surface.now = new Date()
    }

    Item {
        anchors.fill: parent
        focus: true

        Rectangle { anchors.fill: parent; color: Theme.background }
        Image {
            anchors.fill: parent
            visible: surface.wallpaperEnabled && status === Image.Ready
            source: surface.wallpaperEnabled ? "file://" + SettingsStore.wallpaperPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
        // Dim the background using the exact palette of the running desktop.
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Theme.background, surface.wallpaperEnabled ? 0.86 : 1.0)
        }
        // Quiet ambient accent. Rectangular UI uses the established card tokens;
        // the glow is decorative and never participates in focus/authentication.
        Rectangle {
            width: Math.min(parent.width * .66, 680)
            height: width
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Theme.accent, .035)
        }

        // Same header grid used by RusticQ's launcher and power menu.
        Item {
            id: topBar
            visible: !surface.shortScreen
            anchors.top: parent.top
            anchors.topMargin: surface.compact ? 17 : 35
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(680, parent.width - 38)
            height: 40
            Rectangle {
                id: brandSymbol
                width: 38; height: 38; radius: Theme.rowRadius
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Theme.accent, .14)
                Icon {
                    anchors.centerIn: parent
                    icon: "\ue899"
                    color: Theme.accent
                    font.pixelSize: Fonts.scale(20)
                }
            }
            Column {
                anchors.left: brandSymbol.right
                anchors.leftMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: "RusticQ"
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(14)
                }
                Text {
                    text: "Secure session"
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(10)
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: statusText.implicitWidth + 22
                height: 29; radius: 9
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderaccent
                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: "LOCKED"
                    color: Theme.accent
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(9)
                    font.letterSpacing: 1
                }
            }
        }

        Column {
            id: mainColumn
            width: surface.contentWidth
            anchors.centerIn: parent
            anchors.verticalCenterOffset: surface.compact ? 9 : 0
            spacing: surface.compact ? 13 : 20

            Item {
                id: clockArea
                width: parent.width
                height: surface.compact ? 97 : 132
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: Qt.formatTime(surface.now, "hh:mm")
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(surface.compact ? 52 : 72)
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: Qt.formatDate(surface.now, "dddd, d MMMM yyyy")
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(surface.compact ? 11 : 13)
                }
            }

            Rectangle {
                id: loginCard
                width: parent.width
                height: cardContent.implicitHeight + 2 * surface.insideMargin
                color: Theme.background
                radius: Theme.sectionRadius
                border.width: 1
                border.color: Theme.borderaccent

                Column {
                    id: cardContent
                    x: surface.insideMargin
                    y: surface.insideMargin
                    width: parent.width - 2 * surface.insideMargin
                    spacing: surface.compact ? 12 : 15

                    Item {
                        id: cardHeader
                        width: parent.width
                        height: 44
                        Rectangle {
                            id: avatarBox
                            width: 42; height: 42; radius: Theme.rowRadius
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.alpha(Theme.accent, .14)
                            Icon {
                                anchors.centerIn: parent
                                icon: "\ue853"
                                color: Theme.accent
                                font.pixelSize: Fonts.scale(22)
                            }
                        }
                        Column {
                            anchors.left: avatarBox.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: "Welcome back"
                                color: Theme.foreground
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(15)
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: Quickshell.env("USER") || "Linux account"
                                color: Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(10)
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.borderaccent
                    }

                    Column {
                        width: parent.width
                        spacing: 7
                        Text {
                            text: surface.controller.awaitingResponse ? "AUTHENTICATION CHALLENGE" : "ACCOUNT PASSWORD"
                            color: Theme.muted
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: Fonts.scale(10)
                            font.letterSpacing: .75
                        }
                        Rectangle {
                            width: parent.width
                            height: surface.fieldHeight
                            radius: Theme.rowRadius
                            color: Theme.surface
                            border.width: passwordInput.activeFocus ? 2 : 1
                            border.color: passwordInput.activeFocus ? Theme.accent : Theme.borderaccent
                            Icon {
                                id: passwordIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 13
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "\ue897"
                                font.pixelSize: Fonts.scale(17)
                                color: passwordInput.activeFocus ? Theme.accent : Theme.muted
                            }
                            TextInput {
                                id: passwordInput
                                anchors.left: passwordIcon.right
                                anchors.leftMargin: 11
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.foreground
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(13)
                                echoMode: surface.controller.responseVisible ? TextInput.Normal : TextInput.Password
                                passwordMaskDelay: 0
                                passwordCharacter: "•"
                                selectByMouse: false
                                enabled: !surface.controller.authenticated &&
                                    (!surface.controller.authenticating || surface.controller.awaitingResponse)
                                Keys.onReturnPressed: submit()
                                Keys.onEnterPressed: submit()
                                function submit() {
                                    if (!enabled || text.length === 0) return;
                                    const response = text;
                                    clear(); // Wipe the visual input before passing to PAM.
                                    surface.controller.submit(response);
                                }
                                Component.onCompleted: Qt.callLater(function() { passwordInput.forceActiveFocus(); })
                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: passwordInput.text.length === 0
                                    text: surface.controller.awaitingResponse ? "Enter response…" : "Enter your Linux password…"
                                    color: Theme.muted
                                    opacity: .75
                                    font.family: Fonts.poppins.name
                                    font.pixelSize: Fonts.scale(11)
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: surface.compact ? 43 : 47
                        radius: Theme.rowRadius
                        color: Theme.accent
                        opacity: passwordInput.enabled ? 1 : .55
                        Text {
                            anchors.centerIn: parent
                            text: surface.controller.authenticating ? "Authenticating…" : "Unlock session  →"
                            color: Theme.background
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: Fonts.scale(12)
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: passwordInput.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: passwordInput.submit()
                        }
                    }
                    Item {
                        width: parent.width
                        height: Math.max(34, feedbackLabel.implicitHeight + 8)
                        Text {
                            id: feedbackLabel
                            width: parent.width
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            text: surface.controller.feedback
                            color: surface.controller.feedbackIsError ? Theme.error : Theme.muted
                            font.family: Fonts.poppins.name
                            font.pixelSize: Fonts.scale(10)
                        }
                    }
                }
            }
        }

        Item {
            visible: !surface.shortScreen
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: surface.compact ? 15 : 32
            width: Math.min(550, parent.width - 36)
            height: 20
            Text {
                anchors.centerIn: parent
                text: "Wayland session lock  ·  Linux PAM"
                color: Theme.muted
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(10)
            }
        }
    }
}
