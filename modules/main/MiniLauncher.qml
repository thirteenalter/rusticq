import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../services"
import "../../config"
import "../../components"

Rectangle {
    id: root
    signal launched()
    radius: Theme.sectionRadius
    color: Theme.background
    border.width: 1
    border.color: Theme.borderaccent
    property string query: ""
    property var results: []
    property var frequent: []
    property bool showAll: false
    // Reuse the existing launcher for local tools; no independent search daemon.
    readonly property var providerMatch: /^:(emoji|settings|wallpaper|color|ocr|files|folders|windows|workspaces|notes)(?:\s+(.*))?$/i.exec(query.trim())
    readonly property bool toolsMode: providerMatch !== null
    readonly property string toolName: providerMatch ? providerMatch[1].toLowerCase() : ""
    readonly property string toolQuery: providerMatch ? (providerMatch[2] || "") : ""
    property var toolRows: []
    property string toolMessage: ""
    property bool toolError: false
    property string searchInflight: ""
    readonly property int selectionCount: toolsMode ? toolRows.length : displayedResults.length
    function requestToolSearch() {
        if (!toolsMode) { toolSearchTimer.stop(); toolRows = []; return; }
        toolMessage = "";
        toolSearchTimer.restart();
    }
    Timer { id: toolSearchTimer; interval: 170; repeat: false; onTriggered: {
        if (toolSearchProcess.running) return;
        root.searchInflight = root.toolName + "|" + root.toolQuery;
        toolSearchProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-launcher-tools.py"),
                                "search", root.toolName, root.toolQuery]);
    } }
    Process {
        id: toolSearchProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const response = JSON.parse(this.text);
                if (root.toolsMode && root.toolName === response.mode && root.toolQuery === response.query) {
                    root.toolRows = response.ok === true ? (response.items || []) : [];
                    root.selectedIndex = 0;
                    root.toolError = response.ok !== true;
                    root.toolMessage = response.ok === true ? "" : (response.message || "Search unavailable");
                }
            } catch (e) { if (root.toolsMode) { root.toolError = true; root.toolMessage = "Tool search failed: " + e; } }
        } }
        onExited: (code, status) => {
            if (root.toolsMode && root.searchInflight !== root.toolName + "|" + root.toolQuery)
                toolSearchTimer.restart();
        }
    }
    Process {
        id: toolRunProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const response = JSON.parse(this.text);
                root.toolError = response.ok !== true;
                root.toolMessage = response.message || (root.toolError ? "Action failed" : "Done");
                if (!root.toolError) toolDismissTimer.restart();
            } catch (e) { root.toolError = true; root.toolMessage = "Action failed: " + e; }
        } }
        onExited: (code, status) => {
            if (code !== 0 && !root.toolMessage.length) { root.toolError = true; root.toolMessage = "Tool exited with code " + code; }
        }
    }
    Timer { id: toolDismissTimer; interval: 850; repeat: false; onTriggered: root.launched() }
    function chooseTool(entry) {
        if (!entry || toolRunProcess.running) return;
        if (entry.action === "settings") {
            Store.showSettings(entry.payload, Store.launcherScreen);
            launched();
            return;
        }
        if (entry.action === "file" || entry.action === "folder" ||
            entry.action === "window" || entry.action === "workspace") {
            // The actual open/focus operation runs independently after the layer closes.
            Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/rusticq-launcher-tools.py"),
                                     "execute", entry.action, entry.payload]);
            launched();
            return;
        }
        if (entry.action === "ocr" || entry.action === "color") {
            // Close the full-screen layer before capture/picker starts.
            // An independent process finishes even when this LazyLoader unloads.
            Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/rusticq-launcher-tools.py"),
                                     "execute-later", entry.action, entry.payload]);
            launched();
            return;
        }
        toolMessage = "Running " + entry.action + "…";
        toolError = false;
        toolRunProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-launcher-tools.py"),
                             "execute", entry.action, entry.payload]);
    }
    // Explicit calculator mode: `=2*(3+4)`; no arbitrary Python/JS evaluation.
    readonly property bool calculatorMode: query.trim().startsWith("=")
    property string calculatorResult: ""
    property string calculatorError: ""
    property string calculatorInFlight: ""
    function calculateLater() {
        calculatorResult = "";
        calculatorError = "";
        if (calculatorMode && query.trim().length > 1) calcDebounce.restart();
        else calcDebounce.stop();
    }
    Timer {
        id: calcDebounce
        interval: 150
        repeat: false
        onTriggered: {
            if (calcProcess.running) return;
            root.calculatorInFlight = root.query.trim().substring(1);
            calcProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-calc.py"), root.calculatorInFlight]);
        }
    }
    Process {
        id: calcProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const response = JSON.parse(this.text);
                if (root.calculatorMode && root.query.trim().substring(1) === response.expression) {
                    root.calculatorResult = response.ok === true ? String(response.result) : "";
                    root.calculatorError = response.ok === true ? "" : (response.error || "Invalid expression");
                }
            } catch (e) {
                if (root.calculatorMode) root.calculatorError = "Calculator unavailable";
            }
        } }
        onExited: (code, status) => {
            if (root.calculatorMode && root.query.trim().substring(1) !== root.calculatorInFlight)
                calcDebounce.restart();
        }
    }
    function copyResult() {
        if (!calculatorMode || calculatorResult.length === 0) return;
        Quickshell.execDetached(["wl-copy", "--", calculatorResult]);
    }
    property int selectedIndex: 0
    onResultsChanged: selectedIndex = 0
    function moveSelection(delta) {
        if (!selectionCount) return;
        selectedIndex = Math.max(0, Math.min(selectionCount - 1, selectedIndex + delta));
        if (toolsMode) toolList.positionViewAtIndex(selectedIndex, ListView.Contain);
        else appList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }
    function launchSelected() {
        if (calculatorMode) { copyResult(); return; }
        if (toolsMode) { if (toolRows.length) chooseTool(toolRows[Math.min(selectedIndex, toolRows.length-1)]); return; }
        if (displayedResults.length) launch(displayedResults[Math.min(selectedIndex, displayedResults.length - 1)]);
    }
    readonly property bool cleanHover: SettingsStore.launcherLayoutMode === "clean-hover"
    property bool revealPreview: false
    readonly property bool showResults: !cleanHover || query.trim().length > 0 || revealPreview
    readonly property var displayedResults: cleanHover && query.trim().length === 0 ? results.slice(0, 8) : results
    Timer {
        id: collapsePreview
        interval: 650
        onTriggered: if (root.cleanHover && root.query.trim().length === 0 && !launcherHovered.hovered)
            root.revealPreview = false
    }
    HoverHandler {
        id: launcherHovered
        onHoveredChanged: {
            if (hovered) collapsePreview.stop();
            else if (root.query.trim().length === 0) collapsePreview.restart();
        }
    }
    function launch(entry) {
        try {
            entry.execute();
            AppUsage.noteLaunch(entry);
            launched();
        } catch (e) { console.warn("Launcher failed to start " + textOf(entry.name) + ": " + e); }
    }

    function rebuild() {
        const entries = DesktopEntries.applications.values;
        const found = [];
        const searching = query.trim().length > 0;
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            if (!entry) continue;
            const relevance = searching ? searchScore(entry, query.trim().toLowerCase()) : 1;
            if (relevance > 0) found.push({entry: entry, score: relevance});
        }
        found.sort((a, b) => {
            if (searching && a.score !== b.score) return b.score - a.score;
            const sa = AppUsage.stats(a.entry), sb = AppUsage.stats(b.entry);
            if (sa.pinned !== sb.pinned) return sa.pinned ? -1 : 1;
            if (sa.count !== sb.count) return sb.count - sa.count;
            if (sa.last !== sb.last) return sb.last - sa.last;
            return textOf(a.entry.name).localeCompare(textOf(b.entry.name));
        });
        const ordered = found.map(item => item.entry);
        frequent = ordered.filter(e => {
            const st = AppUsage.stats(e);
            return st.pinned || st.count > 0;
        }).slice(0, 6);
        results = ordered;
    }
    onQueryChanged: { rebuild(); calculateLater(); requestToolSearch(); }
    Connections {
        target: AppUsage
        function onUsageChanged() { root.rebuild(); }
    }
    Component.onCompleted: rebuild()
    onVisibleChanged: if (visible) {
        root.revealPreview = false;
        root.query = "";
        root.selectedIndex = 0;
        root.toolRows = [];
        root.toolMessage = "";
        Qt.callLater(function() { rebuild(); searchField.forceActiveFocus(); });
    }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.rebuild(); }
    }

    function iconSource(entry) {
        const icon = textOf(entry.icon);
        return icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true);
    }
    function textOf(value) {
        return value === undefined || value === null ? "" : String(value);
    }
    // Bounded typo tolerance: only names/words, no extra subprocess or indexer.
    function editDistance2(a, b) {
        if (!a || !b || Math.abs(a.length - b.length) > 2) return 3;
        if (a === b) return 0;
        let previous = [];
        for (let j = 0; j <= b.length; j++) previous.push(j);
        for (let i = 1; i <= a.length; i++) {
            const row = [i];
            let lowest = row[0];
            for (let j = 1; j <= b.length; j++) {
                const cost = a.charAt(i-1) === b.charAt(j-1) ? 0 : 1;
                const value = Math.min(row[j-1]+1, previous[j]+1, previous[j-1]+cost);
                row.push(value);
                if (value < lowest) lowest = value;
            }
            if (lowest > 2) return 3;
            previous = row;
        }
        return previous[b.length];
    }
    function searchScore(entry, text) {
        const q = text.trim().toLowerCase();
        if (!q) return 1;
        if (q.startsWith("=") || q.startsWith(":")) return 0;
        const name = textOf(entry.name).toLowerCase();
        const generic = textOf(entry.genericName).toLowerCase();
        const comment = textOf(entry.comment).toLowerCase();
        const appId = textOf(entry.id).toLowerCase();
        const keywords = Array.isArray(entry.keywords) ? entry.keywords.join(" ").toLowerCase() : "";
        if (name === q) return 150;
        if (name.startsWith(q)) return 140;
        if (name.split(/[\s\-_.,\/]+/).some(token => token.startsWith(q))) return 110;
        if (name.includes(q)) return 90;
        if (appId.startsWith(q)) return 80;
        if (generic.includes(q) || keywords.includes(q)) return 65;
        if (comment.includes(q) || appId.includes(q)) return 40;
        if (q.length >= 4 && q.length <= 24) {
            const words = name.split(/[\s\-_.,\/]+/).filter(token => token.length >= 3).slice(0, 8);
            let best = 3;
            for (const word of words) best = Math.min(best, editDistance2(word.slice(0, 24), q));
            if (best <= 2) return 38 - best * 8;
        }
        return 0;
    }


    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 12
                color: Qt.alpha(Theme.accent, 0.12)
                RusticQIcon { anchors.centerIn: parent; iconSize: 23; visible: SettingsStore.showRusticQIcon }
                Icon { anchors.centerIn: parent; icon: "\ue8b6"; font.pixelSize: Fonts.scale(20); color: Theme.accent; visible: !SettingsStore.showRusticQIcon }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "App Launcher"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(15) }
                Text { visible: !root.cleanHover; text: "Apps · =math · :files · :windows · :workspaces · :notes · :emoji · :ocr"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
            }
            Text {
                visible: !root.cleanHover
                text: DesktopEntries.applications.values.length + " apps"
                color: Theme.muted
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(10)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 11
            color: Theme.surface
            border.width: 0
            HoverHandler {
                onHoveredChanged: if (hovered && root.cleanHover) root.revealPreview = true
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                Icon { icon: "\ue8b6"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground
                    selectionColor: Qt.alpha(Theme.accent, 0.35)
                    selectedTextColor: Theme.foreground
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(12)
                    text: root.query
                    onTextEdited: root.query = text
                    Component.onCompleted: Qt.callLater(function() { forceActiveFocus(); })
                    Keys.onEscapePressed: Store.launcherVisible = false
                    Keys.onDownPressed: event => { root.moveSelection(1); event.accepted = true; }
                    Keys.onUpPressed: event => { root.moveSelection(-1); event.accepted = true; }
                    Keys.onReturnPressed: event => { root.launchSelected(); event.accepted = true; }
                    Keys.onEnterPressed: event => { root.launchSelected(); event.accepted = true; }
                    Text {
                        visible: searchField.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Apps / =math / :files / :notes / :settings"
                        color: Theme.muted
                        font.family: Fonts.poppins.name
                        font.pixelSize: Fonts.scale(11)
                    }
                }
                Rectangle {
                    visible: root.query.length > 0
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 7
                    color: Qt.alpha(Theme.accent, 0.12)
                    Icon { anchors.centerIn: parent; icon: "\ue5cd"; font.pixelSize: Fonts.scale(16); color: Theme.foreground }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.query = ""; searchField.text = ""; searchField.forceActiveFocus(); }
                    }
                }
            }
        }

        Rectangle {
            visible: root.calculatorMode
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 56 : 0
            radius: 11
            color: Theme.surface
            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 11
                Icon { icon: "\uea5e"; color: Theme.accent; font.pixelSize: Fonts.scale(20) }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: root.calculatorResult.length ? "= " + root.calculatorResult : root.calculatorError.length ? root.calculatorError : "Try =sqrt(144) + 8"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                    Text { text: root.calculatorResult.length ? "Enter or click to copy · requires wl-copy" : "Math: +  -  *  /  ^  sqrt()  sin()  pi"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                }
                Rectangle {
                    visible: root.calculatorResult.length > 0
                    Layout.preferredWidth: 62; Layout.preferredHeight: 32; radius: 8; color: Qt.alpha(Theme.accent, 0.16)
                    Text { anchors.centerIn: parent; text: "Copy"; color: Theme.accent; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyResult() }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.showResults
            Layout.preferredHeight: visible ? 1 : 0
            color: Theme.borderaccent
        }

        ColumnLayout {
            visible: !root.toolsMode && !root.cleanHover && root.query.trim() === "" && root.frequent.length > 0 && SettingsStore.launcherHeight >= 470
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Icon { icon: "\ue838"; font.pixelSize: Fonts.scale(17); color: Theme.accent }
                Text { text: "Pinned & frequently used"; font.family: Fonts.poppinsSB.name; color: Theme.foreground; font.pixelSize: Fonts.scale(11); Layout.fillWidth: true }
                Text { text: root.frequent.length + " apps"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: SettingsStore.launcherFavoriteColumns
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: root.frequent
                    delegate: Rectangle {
                        id: frequentApp
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(42, SettingsStore.launcherIconSize + 16)
                        radius: 11
                        color: favMouse.containsMouse ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 7
                            IconImage {
                                Layout.preferredWidth: SettingsStore.launcherIconSize; Layout.preferredHeight: SettingsStore.launcherIconSize
                                source: root.iconSource(frequentApp.modelData)
                                visible: String(source).length > 0
                            }
                            Text { text: root.textOf(frequentApp.modelData.name); Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                        }
                        MouseArea { id: favMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(frequentApp.modelData) }
                    }
                }
            }
        }

        RowLayout {
            visible: !root.toolsMode && !root.cleanHover
            Layout.fillWidth: true
            Text { text: root.query.trim() === "" ? "All applications" : "Search results"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11); Layout.fillWidth: true }
            Text { text: root.results.length + " found"; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
        }

        ListView {
            id: appList
            visible: !root.toolsMode && root.showResults
            Layout.fillWidth: true
            Layout.fillHeight: !root.toolsMode && root.showResults
            Layout.preferredHeight: !root.toolsMode && root.showResults ? -1 : 0
            clip: true
            spacing: 6
            model: root.displayedResults
            currentIndex: root.selectedIndex
            onCurrentIndexChanged: if (currentIndex !== root.selectedIndex && currentIndex >= 0) root.selectedIndex = currentIndex
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: appRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Math.max(SettingsStore.launcherRowHeight, SettingsStore.launcherIconSize + 20)
                radius: 12
                color: appRow.index === root.selectedIndex ? Qt.alpha(Theme.accent, 0.20) : appMouse.containsMouse ? Qt.alpha(Theme.accent, 0.12) : Theme.surface
                border.width: appRow.index === root.selectedIndex ? 1 : 0
                border.color: Theme.accent

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: SettingsStore.launcherIconSize + 10
                        Layout.preferredHeight: SettingsStore.launcherIconSize + 10
                        radius: 11
                        color: Qt.alpha(Theme.accent, 0.11)
                        IconImage {
                            id: appIcon
                            anchors.centerIn: parent
                            width: SettingsStore.launcherIconSize; height: SettingsStore.launcherIconSize
                            source: root.iconSource(appRow.modelData)
                            visible: String(source).length > 0
                        }
                        Text {
                            visible: !appIcon.visible
                            anchors.centerIn: parent
                            text: root.textOf(appRow.modelData.name).length ? root.textOf(appRow.modelData.name).charAt(0).toUpperCase() : "•"
                            color: Theme.accent
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: Math.max(13, Math.round(SettingsStore.launcherIconSize * 0.5))
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: root.textOf(appRow.modelData.name)
                            color: Theme.foreground
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: Fonts.scale(12)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: root.textOf(appRow.modelData.genericName) || root.textOf(appRow.modelData.comment) || root.textOf(appRow.modelData.id)
                            color: Theme.muted
                            font.family: Fonts.poppins.name
                            font.pixelSize: Fonts.scale(10)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                        color: pinMouse.containsMouse ? Qt.alpha(Theme.accent, 0.15) : "transparent"
                        Icon { anchors.centerIn: parent; icon: AppUsage.stats(appRow.modelData).pinned ? "\ue838" : "\ue83a"; font.pixelSize: Fonts.scale(18); color: Theme.accent }
                        MouseArea {
                            z: 3
                            id: pinMouse
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AppUsage.togglePinned(appRow.modelData)
                        }
                    }
                }

                MouseArea {
                    id: appMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.rightMargin: 43
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: { root.selectedIndex = appRow.index; }
                    onClicked: { root.selectedIndex = appRow.index; root.launch(appRow.modelData); }
                }
            }
        }

        ListView {
            id: toolList
            visible: root.toolsMode
            Layout.fillWidth: true
            Layout.fillHeight: root.toolsMode
            Layout.preferredHeight: root.toolsMode ? -1 : 0
            clip: true
            spacing: 6
            model: root.toolRows
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: toolRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Math.max(58, SettingsStore.launcherRowHeight)
                radius: 11
                color: toolRow.index === root.selectedIndex ? Qt.alpha(Theme.accent, .19) : toolMouse.containsMouse ? Qt.alpha(Theme.accent,.11) : Theme.surface
                border.width: toolRow.index === root.selectedIndex ? 1 : 0
                border.color: Theme.accent
                RowLayout { anchors.fill: parent; anchors.margins: 10; spacing: 10
                    Text { text: toolRow.modelData.icon || "•"; color: Theme.accent; font.pixelSize: Fonts.scale(20); Layout.preferredWidth: 32; horizontalAlignment: Text.AlignHCenter }
                    ColumnLayout { Layout.fillWidth: true; spacing: 3
                        Text { text: toolRow.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: toolRow.modelData.detail; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); elide: Text.ElideMiddle; Layout.fillWidth: true }
                    }
                    Icon { icon: "\ue5cc"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                }
                MouseArea { id: toolMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = toolRow.index
                    onClicked: { root.selectedIndex = toolRow.index; root.chooseTool(toolRow.modelData); }
                }
            }
        }
        Text {
            visible: root.toolsMode
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.toolMessage.length ? root.toolMessage : root.toolRows.length ? "↑/↓ select · Enter to run · actions are local and opt-in" : "No matching items · try :files report, :notes +task, or :windows"
            color: root.toolError ? Theme.error : Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(10)
        }

        Text {
            visible: !root.toolsMode && (!root.cleanHover || (root.query.trim().length > 0 && root.results.length === 0))
            Layout.fillWidth: true
            text: root.results.length === 0 ? "No matching applications" : root.query.trim().length > 0 ? root.results.length + " matching apps · ↑/↓ select · Enter launch" : "Installed applications · choose to launch"
            wrapMode: Text.WordWrap
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(10)
        }
    }
}
