import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../config"
import "../../components"

// Full-screen, focused-monitor Wlr Overlay, matching the Power Menu's layer.
// Credentials never enter QML/JSON. The image is held in a private 0700
// runtime directory and is only requested on demand. Closing or expiry
// unlinks the QR from its private tmpfs directory.
PanelWindow {
    id: root
    screen: Store.wifiQrScreen
    visible: Store.wifiQrVisible
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    readonly property string helper: Quickshell.shellPath("scripts/rusticq-wifi-advanced.py")
    property string qrUrl: ""
    property string errorMessage: ""
    property bool qrReady: false
    property bool cleanupPending: false
    property bool retryPending: false
    property int secondsRemaining: 45
    readonly property bool busy: qrCreate.running
    Component.onCompleted: if (!root.visible) root.clearQr()

    function close() { Store.closeWifiQr(); }
    function clearQr() {
        if (qrClear.running) return;
        qrClear.exec(["python3", helper, "qr-clear"]);
    }
    function resetAndGenerate() {
        qrUrl = "";
        qrReady = false;
        errorMessage = "";
        secondsRemaining = 45;
        expiry.stop();
        if (qrCreate.running) {
            // Never display a QR generated for a previously selected network.
            cleanupPending = true;
            retryPending = true;
            return;
        }
        cleanupPending = false;
        retryPending = false;
        if (!qrClear.running) qrCreate.exec(["python3", helper, "qr"]);
        else retryPending = true;
    }
    onVisibleChanged: {
        if (visible) {
            resetAndGenerate();
            focusDelay.restart();
        } else {
            qrUrl = "";
            qrReady = false;
            expiry.stop();
            retryPending = false;
            if (qrCreate.running) cleanupPending = true;
            else clearQr();
        }
    }

    // Delay focus grab until the PopupWindow that launched this overlay has
    // actually disappeared. Do not grab during the popup's focus transition.
    Timer { id: focusDelay; interval: 180; onTriggered: if (root.visible) keyboard.forceActiveFocus() }
    HyprlandFocusGrab {
        active: root.visible && !focusDelay.running
        windows: [root]
        onCleared: if (root.visible && !focusDelay.running) root.close()
    }
    Timer {
        id: expiry
        interval: 1000
        repeat: true
        running: root.visible && root.qrReady
        onTriggered: {
            root.secondsRemaining -= 1;
            if (root.secondsRemaining <= 0) root.close();
        }
    }
    Process {
        id: qrCreate
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim());
                    if (!root.visible) return;
                    if (!data.ok || !data.path) throw Error(data.message || "Cannot generate QR code");
                    root.qrUrl = "file://" + data.path;
                    root.qrReady = true;
                    root.secondsRemaining = 45;
                } catch (e) {
                    if (root.visible) root.errorMessage = String(e);
                }
            }
        }
        onExited: (code, status) => {
            if (root.cleanupPending || !root.visible) {
                root.cleanupPending = false;
                Qt.callLater(function() { root.clearQr(); });
            } else if (code !== 0 && !root.errorMessage && !root.qrReady) {
                root.errorMessage = "Unable to generate Wi-Fi QR. Check NetworkManager permissions and qrencode.";
            }
        }
    }
    Process {
        id: qrClear
        command: ["python3", root.helper, "qr-clear"]
        onExited: (code, status) => {
            if (root.retryPending && root.visible && !qrCreate.running) {
                root.retryPending = false;
                qrCreate.exec(["python3", root.helper, "qr"]);
            }
        }
    }

    FocusScope {
        id: keyboard
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onReturnPressed: root.close()
        Keys.onEnterPressed: root.close()
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha("#07090b", 0.60)
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }
        Rectangle {
            id: card
            width: Math.min(448, Math.max(290, parent.width - 32))
            height: content.implicitHeight + 42
            anchors.centerIn: parent
            radius: Theme.sectionRadius
            color: Theme.background
            border.color: Theme.borderaccent
            border.width: 1
            // Consume clicks inside the card: only the dimmed background and
            // Done should dismiss, never a tap on the QR image itself.
            MouseArea { anchors.fill: parent; onClicked: mouse => { mouse.accepted = true; } }
            ColumnLayout {
                id: content
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 21
                spacing: 14
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                        radius: 12; color: Qt.alpha(Theme.accent, .16)
                        Icon { anchors.centerIn: parent; icon: "\uef6d"; color: Theme.accent; font.pixelSize: Fonts.scale(21) }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Share Wi-Fi"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(16) }
                        Text { text: "Scan to join this network"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                    }
                    Text { text: root.qrReady ? root.secondsRemaining + "s" : ""; color: Theme.accent; font.pixelSize: Fonts.scale(12) }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 5
                    Text { text: "CONNECTED NETWORK"; color: Theme.muted; font.pixelSize: Fonts.scale(9) }
                    Text { Layout.fillWidth: true; text: Store.wifiQrSsid || "Current Wi-Fi"; elide: Text.ElideRight;
                        color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(294, card.width - 48)
                    Layout.preferredHeight: Math.min(294, card.width - 48)
                    radius: 14
                    color: root.qrReady ? "white" : Theme.surface
                    Image {
                        anchors.fill: parent
                        anchors.margins: 11
                        source: root.qrUrl
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        visible: root.qrReady
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 32
                        spacing: 9
                        visible: !root.qrReady
                        Icon { Layout.alignment: Qt.AlignHCenter; icon: "\uef6d"; font.pixelSize: Fonts.scale(34); color: Theme.accent }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: root.errorMessage.length ? root.errorMessage : "Generating Wi-Fi QR…"
                            color: root.errorMessage.length ? Theme.error : Theme.muted
                            font.pixelSize: Fonts.scale(11)
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "The QR includes the Wi-Fi password. Only share it with people you trust."
                    wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                    color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 39
                    radius: Theme.rowRadius; color: Theme.surface
                    Text { anchors.centerIn: parent; text: "Done · Esc"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
                }
                Text {
                    Layout.fillWidth: true
                    text: "QR is cleared automatically after 45 seconds"
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.muted; font.pixelSize: Fonts.scale(9)
                }
            }
        }
    }
}
