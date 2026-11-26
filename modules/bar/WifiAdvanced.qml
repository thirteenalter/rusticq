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
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    spacing: root.settingsTheme.sectionGap
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
    function sectionOffset(section) {
        const item = section === "dns" ? dnsHeading : sharingHeading;
        return item.mapToItem(root, 0, 0).y;
    }
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
    Item { Layout.fillWidth: true; Layout.preferredHeight: root.settingsTheme.sectionGap }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Icon { icon: "\ue8b8"; color: root.settingsTheme.accent; font.pixelSize: Fonts.scale(18) }
        GlassLabel { Layout.fillWidth: true; text: "Advanced Wi-Fi"; color: root.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
        Rectangle {
            Layout.preferredWidth: 64; Layout.preferredHeight: 27; radius: root.settingsTheme.glassRadius("card", 8); color: root.settingsTheme.glassColor("card", root.settingsTheme.surface)
            GlassLabel { anchors.centerIn: parent; text: "Refresh"; color: root.settingsTheme.accent; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
        }
    }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 62; radius: root.settingsTheme.glassRadius("card", root.settingsTheme.rowRadius); color: root.settingsTheme.glassColor("card", root.settingsTheme.surface)
        RowLayout { anchors.fill: parent; anchors.margins: 12; spacing: 12
            ColumnLayout { Layout.fillWidth: true; spacing: 3
                GlassLabel { text: "↓ Download"; color: root.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(10) }
                GlassLabel { text: root.prettyRate(root.downRate); color: root.settingsTheme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            }
            ColumnLayout { Layout.fillWidth: true; spacing: 3
                GlassLabel { text: "↑ Upload"; color: root.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(10) }
                GlassLabel { text: root.prettyRate(root.upRate); color: root.settingsTheme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            }
        }
    }
    GlassLabel { Layout.fillWidth: true; text: "Local interface traffic · not an internet speed test"; color: root.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(9); wrapMode: Text.WordWrap }
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
                GlassLabel { text: modelData.label; color: root.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(9) }
                GlassLabel { Layout.fillWidth: true; text: modelData.value; elide: Text.ElideRight; color: root.settingsTheme.foreground; font.pixelSize: Fonts.scale(10) }
            }
        }
    }
    Item { Layout.fillWidth: true; Layout.preferredHeight: root.settingsTheme.sectionGap }
    RowLayout {
        id: sharingHeading
        Layout.fillWidth: true; spacing: 7
        GlassLabel { Layout.fillWidth: true; text: "Wi-Fi sharing"; color: root.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
        Rectangle { Layout.preferredWidth: 105; Layout.preferredHeight: 31; radius: root.settingsTheme.glassRadius("card", 9); color: root.settingsTheme.glassColor("card", root.settingsTheme.surface)
            GlassLabel { anchors.centerIn: parent; text: "Show QR"; color: root.settingsTheme.accent; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const screen = root.targetScreen;
                    const ssid = root.snapshot.ssid || "";
                    root.shareQrRequested(screen, ssid);
                } }
        }
    }
    GlassLabel { Layout.fillWidth: true; text: "Opens a full-screen QR overlay on this monitor. Automatically hidden and erased after 45 seconds.";
        wrapMode: Text.WordWrap; color: root.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(9) }
    Item { Layout.fillWidth: true; Layout.preferredHeight: root.settingsTheme.sectionGap }
    GlassLabel { id: dnsHeading; Layout.fillWidth: true; text: "DNS settings"; color: root.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 34; radius: root.settingsTheme.glassRadius("card", 9); color: root.settingsTheme.glassColor("card", root.settingsTheme.surface)
        TextInput { id: dnsField; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter; color: root.settingsTheme.foreground; font.pixelSize: Fonts.scale(11)
            text: root.dnsInput; onTextEdited: root.dnsInput = text
            GlassLabel { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text.length
                text: "1.1.1.1, 1.0.0.1"; color: root.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(10) }
        }
    }
    RowLayout { Layout.fillWidth: true; spacing: 8
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 32; radius: root.settingsTheme.glassRadius("card", 9); color: root.settingsTheme.glassColor("card", root.settingsTheme.surface)
            GlassLabel { anchors.centerIn: parent; text: "Automatic DNS"; color: root.settingsTheme.foreground; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.perform("dns-auto") }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 9; color: root.settingsTheme.accent
            GlassLabel { anchors.centerIn: parent; text: "Apply custom DNS"; color: root.settingsTheme.background; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; enabled: !root.busy && root.dnsInput.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: root.perform("dns-manual", root.dnsInput) }
        }
    }
    GlassLabel { visible: root.message.length > 0; Layout.fillWidth: true; text: root.message; wrapMode: Text.WordWrap; color: root.failed ? root.settingsTheme.error : root.settingsTheme.muted; font.pixelSize: Fonts.scale(10) }
}
