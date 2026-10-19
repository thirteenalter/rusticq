import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../config"
import "../../components"

// Non-privileged authorization handoff, designed like the Power Menu.
// Do not accept passwords here: system Polkit/PAM owns every credential.
// The layer is removed BEFORE pkexec is launched so the real agent can focus.
PanelWindow {
    id: root
    visible: Store.packageAuthVisible
    screen: Store.packageAuthScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    function cancel() { Store.cancelPackageAuthorization(); }
    function approve() { Store.approvePackageAuthorization(); }
    // The Settings confirmation FloatingWindow is destroyed first; then the
    // second stage is shown on the SAME monitor/workspace.
    Timer {
        id: stageDelay
        interval: 380
        running: Store.packageAuthPending
        repeat: false
        onTriggered: Store.activatePendingPackageAuthorization()
    }
    onVisibleChanged: if (visible) focusDelay.restart()
    Timer { id: focusDelay; interval: 260; repeat: false
        onTriggered: if (root.visible) keyboard.forceActiveFocus() }
    HyprlandFocusGrab {
        active: root.visible && !focusDelay.running
        windows: [root]
        // Hyprland may send 'cleared' when dismissing the first popup or
        // transferring keyboard focus. Do not silently cancel stage two.
        // Explicit Escape, Cancel, and scrim clicks remain supported.
    }
    FocusScope {
        id: keyboard
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.approve(); event.accepted = true;
            }
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha("#07090b", 0.67)
            MouseArea { anchors.fill: parent; onClicked: root.cancel() }
        }
        Rectangle {
            id: authCard
            width: Math.min(450, Math.max(310, parent.width - 48))
            height: authContent.implicitHeight + 38
            anchors.centerIn: parent
            radius: Theme.sectionRadius
            color: Theme.background
            border.color: Theme.borderaccent
            border.width: 1
            ColumnLayout {
                id: authContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 19
                spacing: 13
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 11
                        color: Qt.alpha(Theme.accent, .14)
                        Icon { anchors.centerIn: parent; icon: "\ue899"; color: Theme.accent; font.pixelSize: Fonts.scale(22) }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "System Authorization"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(16) }
                        Text { text: "Approve a package operation using Polkit / PAM"; color: Theme.muted; font.pixelSize: Fonts.scale(10); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 10
                    color: Theme.surface
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        Text { text: (Store.packageAuthAction === "remove" ? "Remove" : "Install") + " · " + Store.packageAuthProvider.toUpperCase(); color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                        Text { text: Store.packageAuthPackage; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13); Layout.fillWidth: true; elide: Text.ElideMiddle }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 65
                        color: Theme.surface
                        radius: 9
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Icon { icon: "\ue8a9"; color: Theme.accent; font.pixelSize: Fonts.scale(22); Layout.alignment: Qt.AlignHCenter }
                            Text { text: Store.packageAuthFingerprintConfigured ? "Fingerprint (PAM)" : "Fingerprint (if configured)"; color: Theme.foreground; font.pixelSize: Fonts.scale(10); Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 65
                        color: Theme.surface
                        radius: 9
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Icon { icon: "\ue899"; color: Theme.accent; font.pixelSize: Fonts.scale(22); Layout.alignment: Qt.AlignHCenter }
                            Text { text: "Password"; color: Theme.foreground; font.pixelSize: Fonts.scale(10); Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(11)
                    text: "The system will request your password or fingerprint in its own secure authentication dialog, according to PAM settings. RusticQ never reads or stores your credentials."
                }
                Text {
                    visible: !Store.packageAuthAgentDetected
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Store.packageAuthNativeBundled
                        ? "RusticQ includes the native Quickshell Polkit agent. It will handle the real password/fingerprint prompt when pkexec requests authorization. If registration fails, check the shell log."
                        : Store.packageAuthCanStartAgent
                        ? "No agent process detected. RusticQ will try the installed system agent, then check real pkexec authorization."
                        : "No graphical agent detected. The operation will not proceed unless a real Polkit/PAM agent authorizes it."
                    color: Theme.warning
                    font.pixelSize: Fonts.scale(10)
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.accent
                    font.pixelSize: Fonts.scale(10)
                    text: "Step 2 of 2 · Next: open the native Polkit password/fingerprint prompt before starting the package transaction."
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 9
                        color: Theme.surface
                        Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.foreground; font.pixelSize: Fonts.scale(11) }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cancel() }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 9
                        color: Theme.accent
                        Text { anchors.centerIn: parent; text: "Open system authentication"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.approve() }
                    }
                }
            }
        }
    }
}
