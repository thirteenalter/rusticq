import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    id: root
    width: parent ? parent.width : 700
    spacing: 14
    property string category: "os"
    property string heading: "System information"
    property string description: "Details gathered locally from Linux"
    property string symbol: "\ue88e"
    property bool loading: false
    property string error: ""
    property var details: ({ facts: [], rows: [], notes: [] })
    readonly property var facts: details.facts || []
    readonly property var rows: details.rows || []
    readonly property bool hasRows: category === "apps" || category === "storage"
    property var desktopApps: []
    function loadDesktopApps() {
        if (category !== "apps") return;
        const nativeEntries = DesktopEntries.applications.values;
        const result = [];
        for (let i = 0; i < nativeEntries.length; i++) if (nativeEntries[i]) result.push(nativeEntries[i]);
        desktopApps = result;
    }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.loadDesktopApps(); }
    }
    readonly property var filteredDesktopApps: desktopApps.filter(function(entry) {
        const q = searchInput.text.toLowerCase().trim();
        return !q.length || (String(entry.name || "") + " " + String(entry.genericName || "") + " " + String(entry.comment || "")).toLowerCase().indexOf(q) !== -1;
    })
    readonly property var filteredRows: rows.filter(function(entry) {
        const q = searchInput.text.toLowerCase().trim();
        if (!q.length) return true;
        return JSON.stringify(entry).toLowerCase().indexOf(q) !== -1;
    })

    function refresh() {
        if (inspect.running) return;
        loading = true;
        error = "";
        inspect.exec(["python3", Quickshell.shellPath("scripts/rustiq-inspect.py"), category]);
    }
    Component.onCompleted: {
        Qt.callLater(refresh);
        Qt.callLater(loadDesktopApps);
    }

    Process {
        id: inspect
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(this.text);
                    if (!value.ok) throw Error(value.error || "Unable to retrieve system data");
                    root.details = value;
                    root.error = "";
                } catch (e) {
                    root.error = String(e);
                }
                root.loading = false;
            }
        }
        stderr: StdioCollector {}
        onExited: function(code, status) {
            root.loading = false;
            if (code !== 0 && !root.error) root.error = "System inspection returned exit code " + code;
        }
    }

    SettingsSection {
        heading: root.heading
        description: root.description
        symbol: root.symbol
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: root.loading ? "Reading system information…" : root.error.length ? root.error : (root.details.subtitle || "Current local system")
                color: root.error.length ? Theme.error : Theme.muted
                font.family: Fonts.poppins.name
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.preferredWidth: 98
                Layout.preferredHeight: 32
                radius: 10
                color: Theme.background
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { icon: "\ue5d5"; color: Theme.accent; font.pixelSize: 16 }
                    Text { text: root.loading ? "Loading" : "Refresh"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 10 }
                }
                MouseArea { anchors.fill: parent; enabled: !root.loading; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: root.details.headline !== undefined && !root.loading
            text: root.details.headline || ""
            color: Theme.foreground
            font.family: Fonts.poppinsSB.name
            font.pixelSize: 17
            wrapMode: Text.WordWrap
        }
    }

    SettingsSection {
        heading: root.category === "hardware" ? "Device specifications" : root.category === "os" ? "OS & session" : root.category === "apps" ? "Package inventory" : "Capacity & usage"
        description: "Read-only information from the computer"
        symbol: root.symbol
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 9
            rowSpacing: 9
            Repeater {
                model: root.facts
                delegate: Rectangle {
                    id: fact
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    radius: 11
                    color: Theme.background
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 3
                        Text { text: fact.modelData[0]; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: fact.modelData[1]; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }
            }
        }
        Text {
            visible: root.loading && root.facts.length === 0
            text: "Collecting hardware, operating system and package information…"
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 11
        }
    }

    SettingsSection {
        visible: root.category === "apps"
        heading: "Graphical applications"
        description: "Installed desktop entries recognized by Quickshell; these applications have launchable interfaces."
        symbol: "\ue5c3"
        Text {
            Layout.fillWidth: true
            text: root.filteredDesktopApps.length + " graphical applications" + (searchInput.text.length ? " matching the package search" : "")
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10
        }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            clip: true
            model: root.filteredDesktopApps
            boundsBehavior: Flickable.StopAtBounds
            spacing: 5
            delegate: Rectangle {
                id: desktopAppRow
                required property var modelData
                width: ListView.view.width; height: 44; radius: 10
                color: Theme.background
                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                        color: Theme.surface
                        Image { id: appIcon; anchors.fill: parent; anchors.margins: 4; fillMode: Image.PreserveAspectFit; source: String(desktopAppRow.modelData.icon || "").charAt(0) === "/" ? "file://" + desktopAppRow.modelData.icon : Quickshell.iconPath(desktopAppRow.modelData.icon || "", true); visible: status === Image.Ready }
                        Text { anchors.centerIn: parent; visible: !appIcon.visible; text: String(desktopAppRow.modelData.name || "?").charAt(0).toUpperCase(); color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                    }
                    Text { text: desktopAppRow.modelData.name || "Unknown app"; Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
                    Text { text: desktopAppRow.modelData.genericName || "Desktop app"; Layout.preferredWidth: 150; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                }
            }
        }
    }

    SettingsSection {
        visible: root.hasRows
        heading: root.category === "apps" ? "Installed packages" : "Storage devices"
        description: root.category === "apps" ? "All pacman packages, including libraries. Use the search field below to filter packages and graphical apps." : "Disks, partitions and filesystems detected by lsblk"
        symbol: root.category === "apps" ? "\ue5c3" : "\ue1db"
        Rectangle {
            visible: root.category === "apps"
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 38 : 0
            radius: 10
            color: Theme.background
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 11; spacing: 8
                Icon { icon: "\ue8b6"; color: Theme.accent; font.pixelSize: 18 }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true; Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 12
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: searchInput.text.length === 0; text: "Search installed packages…"; color: Theme.muted; font.pixelSize: 10; font.family: Fonts.poppins.name }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.filteredRows.length + " matching entries" + (root.category === "apps" ? " · sorted alphabetically" : "")
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10
        }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(370, Math.max(56, root.filteredRows.length * 48 + 8))
            clip: true
            spacing: 5
            boundsBehavior: Flickable.StopAtBounds
            model: root.filteredRows
            delegate: Rectangle {
                id: packageRow
                required property var modelData
                width: ListView.view.width
                height: 43
                radius: 10
                color: Theme.background
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 11; spacing: 9
                    Rectangle { Layout.preferredWidth: 27; Layout.preferredHeight: 27; radius: 8; color: Qt.alpha(Theme.accent, 0.12); Icon { anchors.centerIn: parent; icon: root.category === "apps" ? "\ue5c3" : "\ue1db"; color: Theme.accent; font.pixelSize: 16 } }
                    Text { text: root.category === "apps" ? packageRow.modelData.name : packageRow.modelData.name + (packageRow.modelData.mount ? " · " + packageRow.modelData.mount : ""); Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 11 }
                    Text { text: root.category === "apps" ? packageRow.modelData.version : packageRow.modelData.size; Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                }
            }
        }
    }
    SettingsSection {
        heading: "Notes"
        description: "Availability depends on tools installed on your system"
        symbol: "\ue88e"
        Repeater {
            model: root.details.notes || []
            delegate: RowLayout {
                required property string modelData
                Layout.fillWidth: true
                spacing: 9
                Icon { icon: "\ue88e"; font.pixelSize: 15; color: Theme.accent }
                Text { text: modelData; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 11 }
            }
        }
    }
}
