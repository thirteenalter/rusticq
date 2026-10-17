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
    // Package management is explicit. Never perform a mutation in refresh().
    property string pendingAction: ""
    property string pendingPackage: ""
    property string confirmationText: ""
    property string packageStatus: ""
    property string newPackageName: ""
    function requestOperation(action, pkg) {
        pendingAction = action;
        pendingPackage = String(pkg || "").trim();
        confirmationText = "";
        packageStatus = "";
    }
    function resolveGraphicalApp(entryId) {
        if (packageResolve.running) return;
        packageStatus = "Locating the owning pacman package…";
        packageResolve.exec(["python3", Quickshell.shellPath("scripts/rustiq-package-manager.py"), "resolve-desktop", String(entryId || "")]);
    }
    Process {
        id: packageResolve
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text.trim());
                    if (!response.ok) throw Error(response.message || "Unknown owner");
                    root.requestOperation("remove", response.package);
                } catch (e) { root.packageStatus = "Cannot manage this desktop entry automatically: " + e; }
            }
        }
    }
    Process {
        id: packageLauncher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text.trim());
                    root.packageStatus = response.message || "Terminal requested";
                    if (!response.ok) throw Error(root.packageStatus);
                    root.pendingAction = "";
                    root.pendingPackage = "";
                } catch (e) { root.packageStatus = "Could not start package transaction: " + e; }
            }
        }
    }
    function confirmPackage() {
        if (pendingAction === "remove" && confirmationText !== pendingPackage) return;
        if (!pendingPackage || packageLauncher.running) return;
        packageLauncher.exec(["python3", Quickshell.shellPath("scripts/rustiq-package-manager.py"), "launch", pendingAction, pendingPackage]);
    }
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
                    Text { text: desktopAppRow.modelData.genericName || "Desktop app"; Layout.preferredWidth: 95; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                    Rectangle {
                        Layout.preferredWidth: 64; Layout.preferredHeight: 28
                        radius: 8; color: Theme.surface
                        Text { anchors.centerIn: parent; text: "Manage"; color: Theme.accent; font.pixelSize: 10; font.family: Fonts.poppinsSB.name }
                        MouseArea { anchors.fill: parent; enabled: !packageResolve.running; cursorShape: Qt.PointingHandCursor; onClicked: root.resolveGraphicalApp(desktopAppRow.modelData.id) }
                    }
                }
            }
        }
    }

    SettingsSection {
        visible: root.category === "apps"
        heading: "Install repository package"
        description: "Enter the exact pacman repository package name. AUR, Flatpak and AppImage are not supported."
        symbol: "\ue5c3"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10; color: Theme.background
                TextInput {
                    id: packageNameInput
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Fonts.poppins.name; font.pixelSize: 12; color: Theme.foreground
                    onTextChanged: root.newPackageName = text
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: packageNameInput.text.length === 0; text: "Package name, e.g. gimp"; color: Theme.muted; font.pixelSize: 10 }
                }
            }
            Rectangle {
                Layout.preferredWidth: 88; Layout.preferredHeight: 38; radius: 10; color: Theme.accent
                Text { anchors.centerIn: parent; text: "Install…"; color: Theme.background; font.pixelSize: 11; font.family: Fonts.poppinsSB.name }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.requestOperation("install", root.newPackageName) }
            }
        }
    }

    SettingsSection {
        visible: root.category === "apps" && root.pendingAction.length > 0
        heading: root.pendingAction === "remove" ? "Confirm uninstall" : "Confirm installation"
        description: "Potentially destructive system change. Read the warning before proceeding."
        symbol: "\ue002"
        Text {
            Layout.fillWidth: true
            text: "Action: " + root.pendingAction.toUpperCase() + " · Package: " + root.pendingPackage
            font.family: Fonts.poppinsSB.name; font.pixelSize: 13; color: Theme.foreground; wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            text: root.pendingAction === "remove" ?
                "WARNING: Removing packages can break applications, dependencies, your desktop or system configuration. Pacman may refuse a removal if required elsewhere. Risks are your responsibility. Existing config files are preserved when possible." :
                "WARNING: Installation may download packages, change dependencies or upgrade your system. On Arch, pacman performs a full upgrade with installation. On Omarchy, its official update runs first. Risks are your responsibility."
            color: Theme.error; wrapMode: Text.WordWrap; font.family: Fonts.poppins.name; font.pixelSize: 11
        }
        Rectangle {
            visible: root.pendingAction === "remove"
            Layout.fillWidth: true; Layout.preferredHeight: visible ? 38 : 0
            color: Theme.background; radius: 9
            TextInput {
                id: confirmField
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 12
                onTextChanged: root.confirmationText = text
                Text { visible: confirmField.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "Type the exact package name to authorize removal"; color: Theme.muted; font.pixelSize: 10 }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10; color: Theme.background
                Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.foreground; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pendingAction = "" }
            }
            Rectangle {
                readonly property bool allowed: root.pendingAction === "install" || root.confirmationText === root.pendingPackage
                Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10
                color: allowed ? Theme.accent : Theme.borderaccent
                opacity: allowed ? 1 : .65
                Text { anchors.centerIn: parent; text: "Open interactive terminal"; color: parent.allowed ? Theme.background : Theme.muted; font.pixelSize: 10; font.family: Fonts.poppinsSB.name }
                MouseArea { anchors.fill: parent; enabled: parent.allowed && !packageLauncher.running; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmPackage() }
            }
        }
    }
    SettingsSection {
        visible: root.category === "apps" && root.packageStatus.length > 0
        heading: "Package operation status"
        symbol: "\ue88e"
        Text { Layout.fillWidth: true; text: root.packageStatus; color: Theme.foreground; font.pixelSize: 11; wrapMode: Text.WordWrap }
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
                    Text { text: root.category === "apps" ? packageRow.modelData.version : packageRow.modelData.size; Layout.preferredWidth: root.category === "apps" ? 90 : 160; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                    Rectangle {
                        visible: root.category === "apps"
                        Layout.preferredWidth: visible ? 76 : 0; Layout.preferredHeight: 28
                        radius: 8; color: Qt.alpha(Theme.error, 0.12)
                        Text { anchors.centerIn: parent; text: "Uninstall"; color: Theme.error; font.pixelSize: 10; font.family: Fonts.poppinsSB.name }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.requestOperation("remove", packageRow.modelData.name) }
                    }
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
