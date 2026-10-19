import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

// Network diagnostics and DNS. QR generation now belongs exclusively to
// WifiShareOverlay; Wi-Fi secrets never enter this component.
ColumnLayout {
    id: root
    spacing: Theme.sectionGap
    property var snapshot: ({})
    property bool busy: false
    property var targetScreen: null
    signal shareQrRequested(var screen, string ssid)
    property string message: ""
    property bool failed: false
    property string dnsInput: ""
    property string requestName: ""
    property real downRate: 0
    property real upRate: 0
    property real lastRx: -1
    property real lastTx: -1
    property double lastSample: 0
    readonly property string helper: Quickshell.shellPath("scripts/rusticq-wifi-advanced.py")
    function prettyRate(n) {
        if (n < 1024) return Math.round(n) + " B/s";
        if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB/s";
        return (n / (1024 * 1024)).toFixed(2) + " MB/s";
    }
    function refresh() {
        if (visible && !statusProcess.running)
            statusProcess.exec(["python3", helper, "status"]);
    }
    function perform(name, extra) {
        if (commandProcess.running) return;
        requestName = name;
        busy = true; message = ""; failed = false;
        const cmd = ["python3", helper, name];
        if (extra !== undefined) cmd.push(extra);
        commandProcess.exec(cmd);
    }
    onVisibleChanged: if (visible) refresh()
    Timer { id: statusTimer; interval: 2000; running: root.visible; repeat: true; onTriggered: root.refresh() }
    Process {
        id: statusProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const data = JSON.parse(this.text.trim());
                if (!data.ok) { root.failed = true; root.message = data.message || "Wi-Fi details unavailable"; return; }
                const now = Date.now();
                const secs = (now - root.lastSample) / 1000;
                if (root.lastSample > 0 && secs > .2 && secs < 15 && root.snapshot.interface === data.interface) {
                    root.downRate = Math.max(0, (data.rxBytes - root.lastRx) / secs);
                    root.upRate = Math.max(0, (data.txBytes - root.lastTx) / secs);
                } else { root.downRate = 0; root.upRate = 0; }
                root.lastSample = now; root.lastRx = data.rxBytes; root.lastTx = data.txBytes;
                root.snapshot = data;
            } catch(e) { root.failed = true; root.message = "Could not read NetworkManager status"; }
        } }
    }
    Process {
        id: commandProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const data = JSON.parse(this.text.trim());
                root.failed = !data.ok;
                root.message = data.message || (data.ok ? "Updated" : "Operation failed");
                if (data.ok && root.requestName.indexOf("dns-") === 0) Qt.callLater(root.refresh);
            } catch(e) { root.failed = true; root.message = "Wi-Fi request returned invalid data"; }
            root.busy = false;
        } }
        onExited: (code, status) => {
            root.busy = false;
            if (code !== 0 && !root.message) { root.failed = true; root.message = "Network request failed"; }
        }
    }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Icon { icon: "\ue8b8"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
        Text { Layout.fillWidth: true; text: "Advanced Wi-Fi"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
        Rectangle {
            Layout.preferredWidth: 64; Layout.preferredHeight: 27; radius: 8; color: Theme.surface
            Text { anchors.centerIn: parent; text: "Refresh"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
        }
    }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 62; radius: Theme.rowRadius; color: Theme.surface
        RowLayout { anchors.fill: parent; anchors.margins: 12; spacing: 12
            ColumnLayout { Layout.fillWidth: true; spacing: 3
                Text { text: "↓ Download"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                Text { text: root.prettyRate(root.downRate); color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            }
            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.borderaccent }
            ColumnLayout { Layout.fillWidth: true; spacing: 3
                Text { text: "↑ Upload"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                Text { text: root.prettyRate(root.upRate); color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            }
        }
    }
    Text { Layout.fillWidth: true; text: "Local interface traffic · not an internet speed test"; color: Theme.muted; font.pixelSize: Fonts.scale(9); wrapMode: Text.WordWrap }
    GridLayout {
        Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 5
        Repeater { model: [
                {label:"Network", value:root.snapshot.ssid || "—"},
                {label:"Interface", value:root.snapshot.interface || "—"},
                {label:"IPv4", value:root.snapshot.ip4 || "—"},
                {label:"Gateway", value:root.snapshot.gateway || "—"},
                {label:"DNS · IPv4", value:root.snapshot.dns || "—"},
                {label:"DNS · IPv6", value:root.snapshot.dns6 || "—"}
            ]
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true; spacing: 1
                Text { text: modelData.label; color: Theme.muted; font.pixelSize: Fonts.scale(9) }
                Text { Layout.fillWidth: true; text: modelData.value; elide: Text.ElideRight; color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
            }
        }
    }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
    RowLayout {
        Layout.fillWidth: true; spacing: 7
        Text { Layout.fillWidth: true; text: "Wi-Fi sharing"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
        Rectangle { Layout.preferredWidth: 105; Layout.preferredHeight: 31; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "Show QR"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const screen = root.targetScreen;
                    const ssid = root.snapshot.ssid || "";
                    root.shareQrRequested(screen, ssid);
                } }
        }
    }
    Text { Layout.fillWidth: true; text: "Opens a full-screen QR overlay on this monitor. Automatically hidden and erased after 45 seconds.";
        wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: Fonts.scale(9) }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
    Text { Layout.fillWidth: true; text: "DNS settings"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 9; color: Theme.surface
        TextInput { id: dnsField; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter; color: Theme.foreground; font.pixelSize: Fonts.scale(11)
            text: root.dnsInput; onTextEdited: root.dnsInput = text
            Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text.length
                text: "1.1.1.1, 1.0.0.1"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
        }
    }
    RowLayout { Layout.fillWidth: true; spacing: 8
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "Automatic DNS"; color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.perform("dns-auto") }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 9; color: Theme.accent
            Text { anchors.centerIn: parent; text: "Apply custom DNS"; color: Theme.background; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; enabled: !root.busy && root.dnsInput.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: root.perform("dns-manual", root.dnsInput) }
        }
    }
    Text { visible: root.message.length > 0; Layout.fillWidth: true; text: root.message; wrapMode: Text.WordWrap; color: root.failed ? Theme.error : Theme.muted; font.pixelSize: Fonts.scale(10) }
}
