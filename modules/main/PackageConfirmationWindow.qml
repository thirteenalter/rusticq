import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"

// Dedicated Wayland overlay surface: destructive confirmation never shifts Settings content.
PanelWindow {
    id: root
    screen: Store.confirmationScreen
    visible: Store.confirmationVisible
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: true
    color: "transparent"
    readonly property bool removing: Store.confirmationAction === "remove"
    property string typed: ""
    onVisibleChanged: {
        typed = "";
        if (visible) Qt.callLater(function() { if (root.removing) authorizeField.forceActiveFocus(); else cancelButton.forceActiveFocus(); });
    }
    Keys.onEscapePressed: Store.cancelPackageConfirmation()

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("#050508", 0.75)
        MouseArea { anchors.fill: parent; onClicked: Store.cancelPackageConfirmation() }
    }
    Rectangle {
        width: Math.min(490, parent.width - 48)
        implicitHeight: form.implicitHeight + 42
        anchors.centerIn: parent
        color: Theme.background
        border.color: Theme.borderaccent
        border.width: 1
        radius: 18
        ColumnLayout {
            id: form
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
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
                    Text { text: "System package operation · confirmation required"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10; color: Theme.surface
                Text { anchors.centerIn: parent; text: Store.confirmationPackage; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13); elide: Text.ElideMiddle; width: parent.width - 20; horizontalAlignment: Text.AlignHCenter }
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted
                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                text: root.removing ?
                  "Pacman will check dependencies in a terminal. Removing system packages may break applications or the desktop. No force-remove is used." :
                  "Pacman will ask for authorization in a terminal. On Arch it may update repositories; on Omarchy its update flow may run first."
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
            Text { Layout.fillWidth: true; text: "The terminal still asks for your sudo/pacman confirmation."; color: Theme.muted; font.pixelSize: Fonts.scale(10); wrapMode: Text.WordWrap }
        }
    }
}
