import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

// A compact toplevel on Settings' workspace; no full-screen layer shell scrim.
// Hyprland places it by exact window address, never by the currently focused window.
FloatingWindow {
    id: root
    screen: Store.confirmationScreen
    visible: Store.confirmationVisible
    title: "RusticQ · Package Confirmation"
    implicitWidth: 510
    implicitHeight: (removing ? 378 : 330) + (Store.confirmationProvider === "yay" ? 36 : 0)
    minimumSize: Qt.size(430, 300)
    color: Theme.background
    Timer {
        id: arrangeTimer
        interval: 280
        repeat: false
        onTriggered: if (root.visible && !arrangeProcess.running) arrangeProcess.running = true
    }
    Process {
        id: arrangeProcess
        command: ["python3", Quickshell.shellPath("scripts/rustiq-confirmation-float.py")]
    }
    readonly property bool removing: Store.confirmationAction === "remove"
    property string typed: ""
    onVisibleChanged: {
        typed = "";
        if (visible) {
            arrangeTimer.restart();
            Qt.callLater(function() { if (root.removing) authorizeField.forceActiveFocus(); else cancelButton.forceActiveFocus(); });
        }
    }
    Keys.onEscapePressed: Store.cancelPackageConfirmation()

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        border.color: Theme.borderaccent
        border.width: 1
        radius: 15
        ColumnLayout {
            id: form
            anchors.fill: parent
            anchors.margins: 21
            spacing: 14
            RowLayout {
                Layout.fillWidth: true; spacing: 11
                Rectangle {
                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 12
                    color: Qt.alpha(Theme.error, .14)
                    Icon { anchors.centerIn: parent; icon: "\ue002"; color: Theme.error; font.pixelSize: 22 }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: root.removing ? "Uninstall this package?" : "Install this package?"; color: Theme.foreground; font.pixelSize: Fonts.scale(16); font.family: Fonts.poppinsSB.name }
                    Text { text: Store.confirmationProvider.toUpperCase() + " · explicit confirmation required"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10; color: Theme.surface
                Text { anchors.centerIn: parent; text: Store.confirmationPackage; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13); elide: Text.ElideMiddle; width: parent.width - 20; horizontalAlignment: Text.AlignHCenter }
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted
                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                text: Store.confirmationProvider === "yay" ?
                  "AUR packages run third-party PKGBUILD scripts. Review the package source before approving. Yay builds as your user and requests Polkit for privileged pacman steps." :
                  Store.confirmationProvider === "flatpak" ?
                  "Flatpak installs applications from your configured remote. System installation may prompt for Polkit; user installation needs no administrator password." :
                  root.removing ? "Pacman checks dependencies and blocks removals that would break installed packages. No force-remove flags are used." :
                  "Pacman uses graphical Polkit and follows existing Omarchy safety hooks."
            }
            Rectangle {
                visible: Store.confirmationProvider === "yay"
                Layout.fillWidth: true; Layout.preferredHeight: visible ? 31 : 0
                radius: 9; color: Theme.surface
                Text { anchors.centerIn: parent; text: "Review AUR PKGBUILD / source ↗"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://aur.archlinux.org/packages/" + encodeURIComponent(Store.confirmationPackage)) }
            }
            Text {
                visible: root.removing
                text: "Type the package name to authorize uninstall"
                color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10)
            }
            Rectangle {
                visible: root.removing
                Layout.fillWidth: true; Layout.preferredHeight: root.removing ? 41 : 0
                color: Theme.surface; radius: 10
                TextInput {
                    id: authorizeField
                    anchors.fill: parent; anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground; font.pixelSize: Fonts.scale(12)
                    text: root.typed
                    onTextEdited: root.typed = text
                    Keys.onReturnPressed: if (root.typed === Store.confirmationPackage) Store.acceptPackageConfirmation()
                    Text { visible: authorizeField.text.length === 0; text: Store.confirmationPackage; color: Theme.muted; font.pixelSize: Fonts.scale(11) }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 9
                Rectangle {
                    id: cancelButton
                    Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 10; color: Theme.surface
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Store.cancelPackageConfirmation() }
                }
                Rectangle {
                    readonly property bool authorized: !root.removing || root.typed === Store.confirmationPackage
                    Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 10
                    color: authorized ? Theme.accent : Theme.borderaccent
                    opacity: authorized ? 1 : .55
                    Text { anchors.centerIn: parent; text: root.removing ? "Continue to uninstall" : "Continue to install"; color: parent.authorized ? Theme.background : Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                    MouseArea { anchors.fill: parent; enabled: parent.authorized; cursorShape: Qt.PointingHandCursor; onClicked: Store.acceptPackageConfirmation() }
                }
            }
            Text { Layout.fillWidth: true; text: "Follow the operation result in Settings. Some actions may require a graphical Polkit agent."; color: Theme.muted; font.pixelSize: Fonts.scale(10); wrapMode: Text.WordWrap }
        }
    }
}
