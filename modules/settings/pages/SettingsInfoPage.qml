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
    property bool packageAwaitingSystemAuth: false
    property var authorizedCommand: []
    property bool authorizationPassed: false
    Process {
        id: systemAuthorization
        stdout: StdioCollector { onStreamFinished: {
            try {
                const response = JSON.parse(this.text.trim());
                if (response.ok && response.authorized) {
                    root.authorizationPassed = true;
                    root.packageStatus = "Polkit authorization approved. Starting package operation…";
                    authorizedLaunchDelay.restart();
                } else {
                    root.authorizationPassed = false;
                    root.authorizedCommand = [];
                    root.packageAwaitingSystemAuth = false;
                    root.packageStatus = response.message || "Polkit authorization was rejected.";
                }
            } catch(e) {
                root.authorizationPassed = false;
                root.authorizedCommand = [];
                root.packageAwaitingSystemAuth = false;
                root.packageStatus = "System authorization produced no valid response: " + String(e);
            }
        } }
        onExited: (code, status) => {
            if (code !== 0 && !root.authorizationPassed) {
                root.packageAwaitingSystemAuth = false;
                root.authorizedCommand = [];
            }
        }
    }
    Timer {
        id: authorizedLaunchDelay
        interval: 320
        repeat: false
        onTriggered: {
            if (authorizationPassed && authorizedCommand.length && !packageLauncher.running) {
                const cmd = authorizedCommand.slice();
                authorizedCommand = [];
                packageLauncher.exec(cmd);
            }
        }
    }
    property var authCapabilities: ({pkexec:false, known_agent_detected:false, fingerprint_configured:false})
    function checkSystemAuth() {
        if (category === "apps" && !authProbe.running)
            authProbe.exec(["python3", Quickshell.shellPath("scripts/rustiq-package-manager.py"), "auth-capabilities"]);
    }
    Process { id: authProbe
        stdout: StdioCollector { onStreamFinished: {
            try { const data = JSON.parse(this.text.trim()); if (data.ok) {
                root.authCapabilities = data;
                Store.packageAuthAgentDetected = !!data.known_agent_detected;
                Store.packageAuthNativeBundled = !!data.native_agent_bundled;
                Store.packageAuthCanStartAgent = !!data.agent_service_available;
                Store.packageAuthFingerprintConfigured = !!data.fingerprint_configured;
            } }
            catch (e) { root.packageStatus = "Polkit capability check failed: " + String(e); }
        } }
    }
    property string newPackageName: ""
    property string pendingProvider: "pacman"
    property string catalogQuery: ""
    property string searchedQuery: ""
    property string pacmanActiveQuery: ""
    property string yayActiveQuery: ""
    property string flatpakActiveQuery: ""
    property string catalogProvider: "all"
    property bool catalogBusy: false
    property string catalogError: ""
    property var catalogProviderState: ({pacman:{busy:false, results:[], error:"", available:false}, yay:{busy:false, results:[], error:"", available:false}, flatpak:{busy:false, results:[], error:"", available:false}})
    property var catalogData: ({results:[], available:{pacman:false,yay:false,flatpak:false}, errors:[]})
    readonly property var catalogResults: (catalogData.results || []).filter(item => catalogProvider === "all" || item.source === catalogProvider)
    function refreshSourceAvailability() {
        if (category === "apps" && !catalogAvailability.running)
            catalogAvailability.exec(["python3", Quickshell.shellPath("scripts/rustiq-package-manager.py"), "sources"]);
    }
    Process {
        id: catalogAvailability
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text.trim());
                if (result.ok) {
                    const next = Object.assign({}, root.catalogProviderState);
                    ["pacman","yay","flatpak"].forEach(function(name) {
                        next[name] = Object.assign({}, root.providerState(name), {available: !!(result.available && result.available[name])});
                    });
                    root.catalogProviderState = next;
                    root.recomputeCatalog();
                }
            } catch(e) { root.catalogError = String(e); }
        } }
    }
    function providerState(name) { return catalogProviderState[name] || {busy:false, results:[], error:"", available:false}; }
    function recomputeCatalog() {
        const merged = [];
        const errors = [];
        const available = {pacman:false, yay:false, flatpak:false};
        let busy = false;
        ["pacman","yay","flatpak"].forEach(function(name) {
            const part = providerState(name);
            available[name] = !!part.available;
            busy = busy || !!part.busy;
            if (part.results) for (let i = 0; i < part.results.length; ++i) merged.push(part.results[i]);
            if (part.error) errors.push(part.error);
        });
        catalogData = {results: merged, available: available, errors: errors};
        catalogBusy = busy;
        catalogError = errors.join(" · ");
    }
    function setProviderPending(name, q) {
        const next = Object.assign({}, catalogProviderState);
        next[name] = Object.assign({}, providerState(name), {busy:true, error:"", results:[], query:q});
        catalogProviderState = next;
        recomputeCatalog();
    }
    function finishProvider(name, payload) {
        // The backend echoes the exact query. Never attribute an old result to
        // a new search when a user types while yay / Flatpak is still running.
        if (!payload || payload.query !== searchedQuery) return;
        const next = Object.assign({}, catalogProviderState);
        const prev = providerState(name);
        const errors = (payload.errors || []).slice();
        if (payload.ok !== true) errors.push(payload.message || "Search failed");
        next[name] = {busy:false, results: payload.ok === true ? (payload.results || []) : [],
                      error:errors.join(" · "), available: payload.available ? !!payload.available[name] : prev.available};
        catalogProviderState = next;
        recomputeCatalog();
    }
    function providerProcess(name) {
        if (name === "pacman") return catalogSearchPacman;
        if (name === "yay") return catalogSearchYay;
        return catalogSearchFlatpak;
    }
    function activeProviderQuery(name) {
        return name === "pacman" ? pacmanActiveQuery : name === "yay" ? yayActiveQuery : flatpakActiveQuery;
    }
    function startProvider(name) {
        const proc = providerProcess(name);
        if (proc.running || searchedQuery.length < 2) return;
        if (name === "pacman") pacmanActiveQuery = searchedQuery;
        else if (name === "yay") yayActiveQuery = searchedQuery;
        else flatpakActiveQuery = searchedQuery;
        proc.exec(["python3", Quickshell.shellPath("scripts/rustiq-package-manager.py"), "search-source", name, searchedQuery]);
    }
    function providerExited(name, code) {
        // A new query can arrive before the older subprocess exits. Run the
        // queued latest query as soon as this provider becomes free.
        if (activeProviderQuery(name) !== searchedQuery) {
            Qt.callLater(function() { root.startProvider(name); });
            return;
        }
        if (providerState(name).busy) {
            const next = Object.assign({}, catalogProviderState);
            next[name] = Object.assign({}, providerState(name), {
                busy:false,
                error: code === 0 ? name + ": no parseable JSON response" : name + ": backend exited (code " + code + ")"
            });
            catalogProviderState = next;
            recomputeCatalog();
        }
    }
    function lookupCatalog() {
        if (category !== "apps") return;
        const value = catalogQuery.trim();
        if (value.length < 2) {
            searchedQuery = "";
            catalogData = {results:[], available:catalogData.available, errors:[]};
            catalogBusy = false;
            return;
        }
        if (searchedQuery === value && catalogBusy) return;
        searchedQuery = value;
        catalogError = "";
        ["pacman","yay","flatpak"].forEach(function(name) {
            setProviderPending(name, value);
            startProvider(name);
        });
    }
    Timer {
        id: catalogDebounce
        interval: 430; repeat: false
        onTriggered: root.lookupCatalog()
    }
    Process {
        id: catalogSearchPacman
        stdout: StdioCollector { onStreamFinished: {
            try { root.finishProvider("pacman", JSON.parse(this.text.trim())); }
            catch(e) { root.finishProvider("pacman", {query:root.pacmanActiveQuery, ok:false, message:String(e)}); }
        } }
        onExited: (code, status) => root.providerExited("pacman", code)
    }
    Process {
        id: catalogSearchYay
        stdout: StdioCollector { onStreamFinished: {
            try { root.finishProvider("yay", JSON.parse(this.text.trim())); }
            catch(e) { root.finishProvider("yay", {query:root.yayActiveQuery, ok:false, message:String(e)}); }
        } }
        onExited: (code, status) => root.providerExited("yay", code)
    }
    Process {
        id: catalogSearchFlatpak
        stdout: StdioCollector { onStreamFinished: {
            try { root.finishProvider("flatpak", JSON.parse(this.text.trim())); }
            catch(e) { root.finishProvider("flatpak", {query:root.flatpakActiveQuery, ok:false, message:String(e)}); }
        } }
        onExited: (code, status) => root.providerExited("flatpak", code)
    }

    function requestOperation(action, pkg, provider) {
        checkSystemAuth();
        pendingProvider = provider || "pacman";
        pendingAction = action;
        pendingPackage = String(pkg || "").trim();
        confirmationText = "";
        packageStatus = "";
        if (pendingPackage.length && !packageLauncher.running && !authorizedLaunchDelay.running && !systemAuthorization.running)
            Store.requestPackageConfirmation(action, pendingPackage, pendingProvider);
    }
    function resolveGraphicalApp(entry) {
        if (packageResolve.running) return;
        packageStatus = "Locating the owning pacman or Flatpak package…";
        packageResolve.exec(["python3", Quickshell.shellPath("scripts/rustiq-package-manager.py"), "resolve-desktop", String(entry.id || ""), String(entry.name || "")]);
    }
    Process {
        id: packageResolve
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text.trim());
                    if (!response.ok) throw Error(response.message || "Unknown owner");
                    root.requestOperation("remove", response.package, response.provider || "pacman");
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
                    root.packageAwaitingSystemAuth = false;
                    root.packageStatus = response.message || "Package operation returned no details";
                    if (!response.ok) throw Error(root.packageStatus);
                    root.pendingAction = "";
                    root.pendingPackage = "";
                    Qt.callLater(root.refresh);
                    if (root.catalogQuery.trim().length > 1) Qt.callLater(root.lookupCatalog);
                } catch (e) { root.packageAwaitingSystemAuth = false; root.packageStatus = "Package transaction failed: " + e; }
            }
        }
        onExited: (code, status) => {
            root.packageAwaitingSystemAuth = false;
            if (code !== 0 && (root.packageStatus.indexOf("Waiting for") === 0 || !root.packageStatus.length))
                root.packageStatus = "Package operation did not finish. Check the system Polkit agent or Yay diagnostics.";
        }
    }
    function confirmPackage() {
        if (!pendingPackage || packageLauncher.running || authorizedLaunchDelay.running || systemAuthorization.running) return;
        authorizationPassed = false;
        packageAwaitingSystemAuth = pendingProvider !== "flatpak";
        packageStatus = pendingProvider === "yay"
            ? "Building AUR package as your user. When privileged pacman work begins, approve the system Polkit password/fingerprint dialog."
            : pendingProvider === "flatpak"
            ? "Flatpak transaction started. System-wide installation may request Polkit authorization."
            : "Waiting for the system Polkit password/fingerprint dialog. Return here for the transaction result.";
        authorizedCommand = ["python3", Quickshell.shellPath("scripts/rustiq-package-manager.py"), "gui", pendingProvider, pendingAction, pendingPackage];
        // Stage 1: package confirmation FloatingWindow. Stage 2: the native
        // Polkit agent handles real PAM password/fingerprint UI, without a
        // decorative intermediate authorization layer.
        // No package command starts unless that explicit authorization succeeds.
        systemAuthLaunchDelay.restart();
    }
    Timer {
        id: systemAuthLaunchDelay
        interval: 390
        repeat: false
        onTriggered: {
            if (root.pendingPackage.length && !systemAuthorization.running)
                systemAuthorization.exec(["python3", Quickshell.shellPath("scripts/rustiq-package-manager.py"),
                                          "authorize", root.pendingProvider, root.pendingAction, root.pendingPackage]);
        }
    }
    Connections {
        target: Store
        function onPackageOperationConfirmed(action, packageName, provider) {
            if (root.category === "apps" && root.pendingAction === action && root.pendingPackage === packageName && root.pendingProvider === provider) root.confirmPackage();
        }
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
        Qt.callLater(refreshSourceAvailability);
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
                font.pixelSize: Fonts.scale(11)
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
                    Icon { icon: "\ue5d5"; color: Theme.accent; font.pixelSize: Fonts.scale(16) }
                    Text { text: root.loading ? "Loading" : "Refresh"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
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
            font.pixelSize: Fonts.scale(17)
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
                        Text { text: fact.modelData[0]; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: fact.modelData[1]; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }
            }
        }
        Text {
            visible: root.loading && root.facts.length === 0
            text: "Collecting hardware, operating system and package information…"
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
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
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        Text { visible: root.packageStatus.length > 0; text: root.packageStatus; Layout.fillWidth:true; color:Theme.muted; wrapMode:Text.WordWrap; font.pixelSize:Fonts.scale(10) }
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
                        Text { anchors.centerIn: parent; visible: !appIcon.visible; text: String(desktopAppRow.modelData.name || "?").charAt(0).toUpperCase(); color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                    }
                    Text { text: desktopAppRow.modelData.name || "Unknown app"; Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    Text { text: desktopAppRow.modelData.genericName || "Desktop app"; Layout.preferredWidth: 95; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                    Rectangle {
                        Layout.preferredWidth: 64; Layout.preferredHeight: 28
                        radius: 8; color: Theme.surface
                        Text { anchors.centerIn: parent; text: "Manage"; color: Theme.accent; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppinsSB.name }
                        MouseArea { anchors.fill: parent; enabled: !packageResolve.running; cursorShape: Qt.PointingHandCursor; onClicked: root.resolveGraphicalApp(desktopAppRow.modelData) }
                    }
                }
            }
        }
    }

    SettingsSection {
        visible: root.category === "apps"
        heading: "Search apps · Pacman + Yay AUR + Flatpak"
        description: "Searches all installed providers by default. Select a result to install or remove it from RusticQ, without a terminal. AUR builds are third-party code—review their PKGBUILD first."
        symbol: "\ue8b6"
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 43; radius: 11; color: Theme.background
            RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 9
                Icon { icon: "\ue8b6"; color: Theme.accent; font.pixelSize: Fonts.scale(19) }
                TextInput {
                    id: catalogInput
                    Layout.fillWidth: true; Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
                    onTextEdited: {
                        root.catalogQuery = text;
                        if (text.trim().length < 2) {
                            catalogDebounce.stop();
                            root.searchedQuery = "";
                            root.catalogData = Object.assign({}, root.catalogData, {results:[], errors:[]});
                            root.catalogBusy = false;
                        } else catalogDebounce.restart();
                    }
                    Keys.onReturnPressed: root.lookupCatalog()
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: catalogInput.text.length === 0
                        text: "Search all providers (e.g. firefox, steam, gimp)…"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                }
                Text { text: root.catalogBusy ? "Searching…" : "↵"; color: Theme.accent; font.pixelSize: Fonts.scale(11) }
            }
        }
        RowLayout { Layout.fillWidth: true; spacing: 7
            Repeater { model: [ {id:"all",name:"All 3"},{id:"pacman",name:"Pacman"},{id:"yay",name:"Yay · AUR"},{id:"flatpak",name:"Flatpak"} ]
                delegate: Rectangle { id: providerButton
                    required property var modelData
                    readonly property bool chosen: root.catalogProvider === modelData.id
                    Layout.fillWidth: true; Layout.preferredHeight: 35; radius: 9
                    color: chosen ? Qt.alpha(Theme.accent,.20) : Theme.background
                    border.width: chosen ? 1 : 0; border.color: Theme.accent
                    Text { anchors.centerIn: parent; text: providerButton.modelData.name; font.pixelSize: Fonts.scale(10); color: providerButton.chosen ? Theme.accent : Theme.foreground }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.catalogProvider = providerButton.modelData.id }
                }
            }
        }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: Fonts.scale(10); color: Theme.muted
            text: "Available: " + ["pacman","yay","flatpak"].filter(k => root.catalogData.available && root.catalogData.available[k]).join(" · ") + " · " + root.catalogResults.length + " results" + (root.catalogBusy ? " · waiting for remaining providers…" : "") }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Repeater { model: ["pacman","yay","flatpak"]
                delegate: Rectangle {
                    required property string modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 9
                    readonly property var part: root.providerState(modelData)
                    color: part.busy ? Qt.alpha(Theme.accent,.10) : Theme.background
                    border.width: 1; border.color: part.error ? Theme.warning : part.busy ? Theme.accent : Theme.borderaccent
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 6
                        Text { text: modelData === "yay" ? "Yay / AUR" : modelData.charAt(0).toUpperCase() + modelData.slice(1); color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
                        Item { Layout.fillWidth: true }
                        Text { text: part.busy ? "Loading" : (part.error ? "Issue" : String((part.results || []).length) + " found"); color: part.error ? Theme.warning : (part.busy ? Theme.accent : Theme.muted); font.pixelSize: Fonts.scale(9) }
                    }
                }
            }
        }
        Text { visible: root.catalogError.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.catalogError; color: Theme.warning; font.pixelSize: Fonts.scale(10) }
        Text {
            visible: root.searchedQuery.length >= 2 && !root.catalogBusy && root.catalogResults.length === 0 && !root.catalogError.length
            Layout.fillWidth: true
            text: "No packages found. Try a shorter name, choose another provider, or check that your repositories are configured."
            color: Theme.muted
            wrapMode: Text.WordWrap
            font.pixelSize: Fonts.scale(10)
        }
        ListView {
            visible: root.catalogQuery.length > 1
            Layout.fillWidth: true; Layout.preferredHeight: visible ? Math.min(385, Math.max(80, root.catalogResults.length * 61 + 8)) : 0
            clip: true; spacing: 5; boundsBehavior: Flickable.StopAtBounds
            model: root.catalogResults
            delegate: Rectangle { id: catalogRow
                required property var modelData
                width: ListView.view.width; height: 58; radius: 10; color: Theme.background
                RowLayout { anchors.fill: parent; anchors.margins: 9; spacing: 9
                    Rectangle { Layout.preferredWidth: 57; Layout.preferredHeight: 25; radius: 7; color: Qt.alpha(Theme.accent,.13)
                        Text { anchors.centerIn: parent; text: catalogRow.modelData.source === "yay" ? "AUR" : catalogRow.modelData.source === "flatpak" ? "FLAT" : "REPO"; color: Theme.accent; font.pixelSize: Fonts.scale(9) }
                    }
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: catalogRow.modelData.title || catalogRow.modelData.name; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: catalogRow.modelData.description || catalogRow.modelData.name; color: Theme.muted; font.pixelSize: Fonts.scale(9) }
                    }
                    Rectangle { Layout.preferredWidth: 76; Layout.preferredHeight: 32; radius: 8
                        color: catalogRow.modelData.installed ? Qt.alpha(Theme.error,.13) : Qt.alpha(Theme.accent,.15)
                        Text { anchors.centerIn: parent; text: catalogRow.modelData.installed ? "Remove" : "Install"; color: catalogRow.modelData.installed ? Theme.error : Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                        MouseArea { anchors.fill: parent; enabled: !packageLauncher.running; cursorShape: Qt.PointingHandCursor
                            onClicked: root.requestOperation(catalogRow.modelData.installed ? "remove" : "install", catalogRow.modelData.name, catalogRow.modelData.source) }
                    }
                }
            }
        }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 9; color: Theme.background
                TextInput { id: packageNameInput; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground; font.pixelSize: Fonts.scale(11)
                    onTextEdited: root.newPackageName = text
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text.length; text: "Exact package / Flatpak ID…"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                }
            }
            Rectangle { Layout.preferredWidth: 81; Layout.preferredHeight: 38; radius: 9; color: Theme.accent
                Text { anchors.centerIn: parent; text: "Install…"; color: Theme.background; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestOperation("install", root.newPackageName, root.catalogProvider === "all" ? "pacman" : root.catalogProvider) }
            }
        }
        Text { Layout.fillWidth: true; text: "Manual installs use the selected provider (All defaults to Pacman). Search results preserve their provider."; color: Theme.muted; wrapMode: Text.WordWrap; font.pixelSize: Fonts.scale(9) }
    }

    SettingsSection {
        visible: root.category === "apps" && (root.packageAwaitingSystemAuth || packageLauncher.running)
        heading: "System authorization"
        symbol: "\ue897"
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.foreground; font.pixelSize: Fonts.scale(11)
            text: "Authorization is handled by your active system Polkit agent, not by RusticQ. If configured, scan your fingerprint; otherwise enter your password in the system dialog. No credentials are collected or stored by RusticQ." }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.warning; font.pixelSize: Fonts.scale(10)
            text: !root.authCapabilities.pkexec ? "Warning: pkexec unavailable. Pacman administration cannot proceed." :
                  !root.authCapabilities.known_agent_detected ? "Polkit agent not detected by the local probe. If no prompt appears, start hyprpolkitagent or your current Polkit agent; do not run two agents." :
                  (root.authCapabilities.fingerprint_configured ? "Fingerprint authentication may be available via PAM." : "Password authentication expected unless your PAM configuration enables another method.") }
    }
    SettingsSection {
        visible: root.category === "apps" && root.packageStatus.length > 0
        heading: "Package operation status"
        symbol: "\ue88e"
        Text { Layout.fillWidth: true; text: root.packageStatus; color: Theme.foreground; font.pixelSize: Fonts.scale(11); wrapMode: Text.WordWrap }
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
                Icon { icon: "\ue8b6"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true; Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: searchInput.text.length === 0; text: "Search installed packages…"; color: Theme.muted; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppins.name }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.filteredRows.length + " matching entries" + (root.category === "apps" ? " · sorted alphabetically" : "")
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
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
                    Rectangle { Layout.preferredWidth: 27; Layout.preferredHeight: 27; radius: 8; color: Qt.alpha(Theme.accent, 0.12); Icon { anchors.centerIn: parent; icon: root.category === "apps" ? "\ue5c3" : "\ue1db"; color: Theme.accent; font.pixelSize: Fonts.scale(16) } }
                    Text { text: root.category === "apps" ? packageRow.modelData.name : packageRow.modelData.name + (packageRow.modelData.mount ? " · " + packageRow.modelData.mount : ""); Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
                    Text { text: root.category === "apps" ? packageRow.modelData.version : packageRow.modelData.size; Layout.preferredWidth: root.category === "apps" ? 90 : 160; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                    Rectangle {
                        visible: root.category === "apps"
                        Layout.preferredWidth: visible ? 76 : 0; Layout.preferredHeight: 28
                        radius: 8; color: Qt.alpha(Theme.error, 0.12)
                        Text { anchors.centerIn: parent; text: "Uninstall"; color: Theme.error; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppinsSB.name }
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
                Icon { icon: "\ue88e"; font.pixelSize: Fonts.scale(15); color: Theme.accent }
                Text { text: modelData; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
            }
        }
    }
}
