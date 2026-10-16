import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"
import "../bar"

// Focused two-pane settings window: persistent navigation, scrollable content,
// live appearance preview, no full-height input/toggle elements.
FloatingWindow {
    id: settingsWindow
    visible: Store.settingsVisible
    title: Theme.useAether ? "RusticQ · Aether Settings" : "RusticQ · Gruvbox Settings"
    implicitWidth: 1090
    implicitHeight: 760
    color: Theme.background
    property string query: ""
    readonly property var searchIndex: [
        {tab:"appearance",title:"Color source · Gruvbox / Aether",words:"theme wallpaper palette accent color"},
        {tab:"bar",title:"Bar position",words:"top bottom left right"},
        {tab:"bar",title:"Bar layout modes",words:"compact separated professional simple"},
        {tab:"bar",title:"Clean Compact details",words:"hover icons right labels"},
        {tab:"bar",title:"Realtime margin editor",words:"slider gap padding edge spacing"},
        {tab:"bar",title:"Modules and individual icons",words:"wifi bluetooth battery volume notification task view launcher search app"},
        {tab:"bar",title:"Desktop widgets",words:"calendar system monitor clock background wallpaper plugin"},
        {tab:"bar",title:"Custom dock",words:"auto hide app launcher shortcuts hover"},
        {tab:"display",title:"Monitor arrangement",words:"display resolution hertz refresh rate scaling position apply"},
        {tab:"ai",title:"AI Providers",words:"api key cloud claude gemini openai"},
        {tab:"about",title:"About RusticQ",words:"quickshell version license"}
    ]
    function openSearchResult(entry) {
        Store.settingsTab = entry.tab;
        settingsWindow.query = "";
        Qt.callLater(function() {
            let target = null;
            if (entry.title.indexOf("margin") !== -1) target = marginSearchAnchor;
            else if (entry.title.indexOf("individual") !== -1) target = modulesSearchAnchor;
            else if (entry.title.indexOf("Desktop widgets") !== -1) target = widgetsSearchAnchor;
            else if (entry.title.indexOf("Custom dock") !== -1) target = dockSearchAnchor;
            else if (entry.title.indexOf("Clean Compact") !== -1) target = cleanSearchAnchor;
            else if (entry.title.indexOf("layout modes") !== -1) target = modeSearchAnchor;
            const y = target ? target.mapToItem(settingContent, 0, 0).y - 12 : 0;
            settingsScroll.contentY = Math.max(0, Math.min(Math.max(0, settingsScroll.contentHeight - settingsScroll.height), y));
        });
    }
    readonly property var foundSettings: searchIndex.filter(entry => (entry.title + " " + entry.words + " " + entry.tab).toLowerCase().indexOf(query.toLowerCase().trim()) !== -1)

    function saveModel() {
        const model = aiModelInput.text.trim();
        if (!/^[A-Za-z0-9_.-]{2,100}$/.test(model)) { keyStatusText.text = "Invalid model ID"; return; }
        SettingsStore.aiModel = model;
        SettingsStore.save();
        keyStatusText.text = "Model ID saved";
    }
    QtObject {
        id: keyAction
        property string payload: ""
        property string action: ""
        function startAction(nextAction, data) {
            if (keyProcess.running) { keyStatusText.text = "Keyring busy; try again"; return; }
            action = nextAction;
            payload = JSON.stringify(data) + "\n";
            keyStatusText.text = "Working with keyring…";
            keyProcess.command = ["python3", Quickshell.shellPath("scripts/cloud_ai.py"), nextAction];
            keyProcess.running = true;
        }
    }
    Process {
        id: keyProcess
        stdinEnabled: true
        onStarted: { write(keyAction.payload); keyAction.payload = ""; }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text.trim());
                    if (!response.ok) throw Error(response.message || "Keyring operation failed");
                    if (keyAction.action === "status")
                        keyStatusText.text = response.configured ? "API key configured in Linux keyring" : "No API key saved for this provider";
                    else keyStatusText.text = response.message;
                } catch (e) { keyStatusText.text = "Keyring: " + e; }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) keyStatusText.text = "Key helper failed (exit " + code + ")";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        border.width: 1
        border.color: Theme.borderaccent
        radius: 16
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: 19
            spacing: 20

            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                color: Qt.alpha(Theme.foreground, 0.04)
                border.color: Theme.borderaccent
                radius: 12
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 12
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 137
                        radius: 15
                        color: Qt.alpha(Theme.accent, 0.085)
                        border.color: Theme.borderaccent
                        clip: true
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 4
                            Rectangle {
                                Layout.preferredWidth: 47
                                Layout.preferredHeight: 47
                                radius: 13
                                color: Qt.alpha(Theme.accent, .19)
                                Icon { anchors.centerIn: parent; icon: "\ue8b8"; font.pixelSize: 27; color: Theme.accent }
                            }
                            Item { Layout.fillHeight: true }
                            Text { text: Theme.useAether ? "AETHER SYNC" : "RUSTICQ SETTINGS"; font.family: Fonts.poppinsSB.name; font.pixelSize: 16; color: Theme.foreground }
                            Text { text: "RUSTIQ DESKTOP · ALPHA 3 RC4"; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 28
                        Text { text: "S E T T I N G S"; font.family: Fonts.poppinsSB.name; font.pixelSize: 10; color: Theme.muted }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                    Repeater {
                        model: [
                            { name: "Appearance", key: "appearance", icon: "\ue40a" },
                            { name: "Bar & modules", key: "bar", icon: "\ue8b8" },
                            { name: "Displays", key: "display", icon: "\ue30b" },
                            { name: "AI Providers", key: "ai", icon: "\ue8f4" },
                            { name: "About", key: "about", icon: "\ue88e" }
                        ]
                        delegate: Rectangle {
                            id: tab
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 13
                            color: Store.settingsTab === tab.modelData.key ? Qt.alpha(Theme.accent, 0.16) : Theme.surface
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 9
                                spacing: 10
                                Icon { icon: tab.modelData.icon; font.pixelSize: 18; color: Store.settingsTab === tab.modelData.key ? Theme.accent : Theme.muted }
                                Text {
                                    text: tab.modelData.name
                                    Layout.fillWidth: true
                                    color: Theme.foreground
                                    font.family: Fonts.poppins.name
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: Store.settingsTab === tab.modelData.key
                                    Layout.preferredWidth: 4
                                    Layout.preferredHeight: 17
                                    radius: 2
                                    color: Theme.accent
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Store.settingsTab = tab.modelData.key; settingsWindow.query = ""; settingsScroll.contentY = 0; }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: "RUSTIQ · ALPHA 3 RC4\nQuickshell 0.3.1"
                        wrapMode: Text.WordWrap
                        font.family: Fonts.poppins.name
                        font.pixelSize: 10
                        color: Theme.muted
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 13
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 66
                    Layout.minimumHeight: 66
                    Layout.maximumHeight: 66
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: Store.settingsTab === "appearance" ? "Appearance" : Store.settingsTab === "bar" ? "Bar & modules" :
                                  Store.settingsTab === "display" ? "Display configuration" : Store.settingsTab === "ai" ? "AI Providers" : "About this shell"
                            color: Theme.foreground
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: 23
                        }
                        Text {
                            text: "RUSTIQ / ALPHA 3 RC4"
                            font.family: Fonts.poppins.name
                            font.pixelSize: 10
                            color: Theme.muted
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 10
                        color: Theme.surface
                        Icon { anchors.centerIn: parent; icon: "\ue5cd"; font.pixelSize: 19; color: Theme.foreground }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Store.settingsVisible = false }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 39
                    radius: 11
                    color: Theme.surface
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                        Icon { icon: "\ue8b6"; font.pixelSize: 19; color: Theme.accent }
                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true; Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            text: settingsWindow.query
                            onTextEdited: settingsWindow.query = text
                            color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 12
                            clip: true
                            Text {
                                visible: searchInput.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search settings · " + Store.settingsTab
                                color: Theme.muted; font.pixelSize: 11; font.family: Fonts.poppins.name
                            }
                        }
                        Icon { icon: "\ue5cd"; font.pixelSize: 17; color: Theme.muted; visible: settingsWindow.query.length > 0
                            MouseArea { anchors.fill: parent; onClicked: settingsWindow.query = "" }
                        }
                    }
                }
                ListView {
                    visible: settingsWindow.query.trim().length > 0
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
                    model: settingsWindow.foundSettings
                    delegate: Rectangle {
                        id: hit
                        required property var modelData
                        width: ListView.view.width; height: 62; radius: 11; color: Theme.surface
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12
                            Icon { icon: "\ue8b6"; font.pixelSize: 18; color: Theme.accent }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text { text: hit.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                                Text { text: hit.modelData.tab.toUpperCase() + " · " + hit.modelData.words; color: Theme.muted; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            Icon { icon: "\ue5cc"; color: Theme.accent; font.pixelSize: 18 }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                settingsWindow.openSearchResult(hit.modelData);
                            }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: settingsWindow.foundSettings.length === 0; text: "No matching settings"; color: Theme.muted; font.pixelSize: 12 }
                }
                Flickable {
                    id: settingsScroll
                    visible: settingsWindow.query.trim().length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentHeight: settingContent.implicitHeight + 30
                    ColumnLayout {
                        id: settingContent
                        width: settingsScroll.width
                        spacing: 16

                        // Appearance: preview before customization, not an empty form.
                        ColumnLayout {
                            visible: Store.settingsTab === "appearance"
                            Layout.fillWidth: true
                            spacing: 12
                            Text { text: "Live theme preview"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                radius: 12
                                color: Qt.alpha(Theme.foreground, 0.045)
                                border.color: Theme.borderaccent
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 13
                                    spacing: 10
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        radius: 10
                                        color: Theme.background
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12; anchors.rightMargin: 12
                                            Icon { icon: "\ue5ca"; font.pixelSize: 17; color: Theme.accent }
                                            Text { text: "Workspaces"; color: Theme.foreground; font.pixelSize: 11; font.family: Fonts.poppins.name }
                                            Item { Layout.fillWidth: true }
                                            Icon { icon: "\ue63e"; font.pixelSize: 18; color: Theme.accent }
                                            Text { text: "100%"; color: Theme.foreground; font.pixelSize: 11; font.family: Fonts.poppinsSB.name }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 65
                                            radius: 10
                                            color: Theme.surface
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 9
                                                Icon { icon: "\ue8b8"; font.pixelSize: 22; color: Theme.accent }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text { text: "Quick Control"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                                                    Text { text: Theme.useAether ? "Aether live colors" : "Gruvbox accents"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            Layout.preferredWidth: 61
                                            Layout.preferredHeight: 65
                                            radius: 10
                                            color: Qt.alpha(Theme.accent, 0.20)
                                            Icon { anchors.centerIn: parent; icon: "\ue40a"; font.pixelSize: 24; color: Theme.accent }
                                        }
                                    }
                                }
                            }
                            Text { text: "Color source"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Text {
                                Layout.fillWidth: true
                                text: "Choose independent Gruvbox or follow Aether's last applied wallpaper palette."
                                color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                            Repeater {
                                model: [
                                    { key: "gruvbox", title: "Independent Gruvbox", info: "Fixed Gruvbox Dark; select an accent below" },
                                    { key: "aether", title: "Follow Aether", info: "Watch ~/.config/aether/theme/colors.toml" }
                                ]
                                delegate: Rectangle {
                                    id: sourceRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    radius: 11
                                    color: SettingsStore.colorSource === modelData.key ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                                    border.width: SettingsStore.colorSource === modelData.key ? 1 : 0
                                    border.color: Theme.accent
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 12; spacing: 10
                                        Icon { icon: sourceRow.modelData.key === "aether" ? "\ue40a" : "\ue8b8"; font.pixelSize: 21; color: Theme.accent }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Text { text: sourceRow.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                                            Text { text: sourceRow.modelData.info; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                                        }
                                        Icon { visible: SettingsStore.colorSource === sourceRow.modelData.key; icon: "\ue5ca"; font.pixelSize: 17; color: Theme.accent }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { SettingsStore.colorSource = sourceRow.modelData.key; SettingsStore.save(); }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: SettingsStore.colorSource === "aether"
                                text: Theme.aetherAvailable ? "Aether palette detected · Live sync enabled" : "Aether palette not detected · Using Gruvbox fallback until Aether applies a theme"
                                color: Theme.aetherAvailable ? Theme.success : Theme.warning
                                font.family: Fonts.poppins.name; font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                            Text { text: "Gruvbox accent color"; visible: SettingsStore.colorSource === "gruvbox"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Repeater {
                                model: [
                                    {name: "orange", label: "Gruvbox Orange", hex: "#d65d0e"},
                                    {name: "green", label: "Gruvbox Green", hex: "#b8bb26"},
                                    {name: "blue", label: "Gruvbox Aqua", hex: "#83a598"},
                                    {name: "purple", label: "Gruvbox Purple", hex: "#d3869b"}
                                ]
                                delegate: Rectangle {
                                    id: accentRow
                                    visible: SettingsStore.colorSource === "gruvbox"
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: 11
                                    color: SettingsStore.accentName === accentRow.modelData.name ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                                    border.width: SettingsStore.accentName === accentRow.modelData.name ? 1 : 0
                                    border.color: Theme.accent
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 12
                                        spacing: 10
                                        Rectangle { Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 7; color: accentRow.modelData.hex }
                                        Text {
                                            Layout.fillWidth: true
                                            text: accentRow.modelData.label
                                            color: Theme.foreground
                                            font.family: Fonts.poppins.name
                                            font.pixelSize: 12
                                        }
                                        Icon {
                                            icon: "\ue5ca"
                                            font.pixelSize: 18
                                            color: Theme.accent
                                            visible: SettingsStore.accentName === accentRow.modelData.name
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { SettingsStore.accentName = accentRow.modelData.name; SettingsStore.save(); }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: SettingsStore.colorSource === "aether" ? "Aether source: " + Theme.aetherPath : "Base palette #282828 / #3c3836 / #ebdbb2 · Poppins and Material Symbols"
                                wrapMode: Text.WordWrap
                                color: Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: 10
                            }
                        }

                        ColumnLayout {
                            visible: Store.settingsTab === "bar"
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 16
                                color: Theme.surface
                                border.color: Theme.borderaccent
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 11
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Rectangle {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            radius: 12
                                            color: Qt.alpha(Theme.accent, 0.14)
                                            Icon { anchors.centerIn: parent; icon: "\ue8b8"; font.pixelSize: 21; color: Theme.accent }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text { text: "Bar foundation"; font.family: Fonts.poppinsSB.name; font.pixelSize: 15; color: Theme.foreground }
                                            Text { text: "Placement, layout mode, and the overall structure of the top or side bar."; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted }
                                        }
                                    }

                                    Text {
                                        text: "Bar position"
                                        font.family: Fonts.poppinsSB.name
                                        font.pixelSize: 14
                                        color: Theme.foreground
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Choose the screen edge. Left and Right use a dedicated vertical layout; popups open toward the desktop."
                                        font.family: Fonts.poppins.name
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        color: Theme.muted
                                    }
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 4
                                        columnSpacing: 9
                                        rowSpacing: 9
                                        Repeater {
                                            model: [
                                                { key: "top", label: "Top", icon: "\ue5d8" },
                                                { key: "bottom", label: "Bottom", icon: "\ue5db" },
                                                { key: "left", label: "Left", icon: "\ue5de" },
                                                { key: "right", label: "Right", icon: "\ue5df" }
                                            ]
                                            delegate: Rectangle {
                                                id: positionCard
                                                required property var modelData
                                                readonly property bool selected: SettingsStore.barPosition === modelData.key
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 72
                                                radius: 12
                                                color: selected ? Qt.alpha(Theme.accent, 0.13) : Theme.background
                                                border.width: selected ? 1 : 0
                                                border.color: Theme.accent
                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4
                                                    Icon { Layout.alignment: Qt.AlignHCenter; icon: positionCard.modelData.icon; font.pixelSize: 22; color: positionCard.selected ? Theme.accent : Theme.foreground }
                                                    Text { Layout.alignment: Qt.AlignHCenter; text: positionCard.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        SettingsStore.barPosition = positionCard.modelData.key;
                                                        SettingsStore.save();
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                                    Text {
                                        id: modeSearchAnchor
                                        text: "Bar layout mode"
                                        font.family: Fonts.poppinsSB.name
                                        font.pixelSize: 14
                                        color: Theme.foreground
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Each mode applies to all four screen edges. Side bars reorganize controls vertically; preferences stay saved."
                                        wrapMode: Text.WordWrap
                                        font.family: Fonts.poppins.name
                                        font.pixelSize: 11
                                        color: Theme.muted
                                    }
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 9
                                        rowSpacing: 9
                                        Repeater {
                                            model: [
                                                { key: "compact", label: "Compact", info: "Dense, low-profile bar", icon: "\ue5d1" },
                                                { key: "clean-compact", label: "Clean Compact", info: "Bare buttons, Quick Settings pill", icon: "\ue5d1" },
                                                { key: "separated", label: "Separated", info: "Left and right islands", icon: "\ue86c" },
                                                { key: "professional", label: "Professional", info: "Full-width status header", icon: "\ue30b" },
                                                { key: "simple", label: "Simple", info: "Arch, centered clock, control", icon: "\ue5d4" }
                                            ]
                                            delegate: Rectangle {
                                                id: modeCard
                                                required property var modelData
                                                readonly property bool selected: SettingsStore.barMode === modelData.key
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 115
                                                radius: 12
                                                color: selected ? Qt.alpha(Theme.accent, 0.13) : Theme.background
                                                border.width: selected ? 1 : 0
                                                border.color: Theme.accent
                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 11
                                                    spacing: 7
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 8
                                                        Icon { icon: modeCard.modelData.icon; font.pixelSize: 18; color: Theme.accent }
                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: modeCard.modelData.label
                                                            font.family: Fonts.poppinsSB.name
                                                            font.pixelSize: 12
                                                            color: Theme.foreground
                                                        }
                                                        Icon { visible: modeCard.selected; icon: "\ue5ca"; font.pixelSize: 18; color: Theme.accent }
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modeCard.modelData.info
                                                        font.family: Fonts.poppins.name
                                                        font.pixelSize: 10
                                                        color: Theme.muted
                                                        elide: Text.ElideRight
                                                    }
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 25
                                                        radius: modeCard.modelData.key === "professional" ? 0 : 7
                                                        color: modeCard.modelData.key === "professional" ? Theme.surface : Qt.alpha(Theme.foreground, 0.06)
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 6; anchors.rightMargin: 6
                                                            spacing: 4
                                                            Rectangle { Layout.preferredWidth: modeCard.modelData.key === "simple" ? 11 : 36; Layout.preferredHeight: modeCard.modelData.key === "clean-compact" ? 2 : 12; radius: 4; color: modeCard.modelData.key === "separated" ? Theme.surface : Qt.alpha(Theme.accent, 0.4) }
                                                            Item { Layout.fillWidth: true }
                                                            Rectangle { Layout.preferredWidth: modeCard.modelData.key === "simple" ? 13 : 21; Layout.preferredHeight: ["compact", "clean-compact"].indexOf(modeCard.modelData.key) !== -1 ? 5 : 10; radius: 4; color: modeCard.modelData.key === "simple" ? Theme.accent : Theme.muted }
                                                            Item { Layout.fillWidth: true }
                                                            Rectangle { Layout.preferredWidth: modeCard.modelData.key === "simple" ? 12 : 45; Layout.preferredHeight: 12; radius: 4; color: modeCard.modelData.key === "separated" ? Theme.surface : Qt.alpha(Theme.accent, 0.4) }
                                                        }
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        SettingsStore.barMode = modeCard.modelData.key;
                                                        SettingsStore.save();
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: SettingsStore.barMode === "clean-compact"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: visible ? 160 : 0
                                        radius: 13
                                        color: Theme.background
                                        border.width: 1
                                        border.color: Theme.borderaccent
                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: 14; spacing: 10
                                            Text { id: cleanSearchAnchor; text: "Clean Compact · Right-side labels"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 14 }
                                            Text { Layout.fillWidth: true; text: "Choose how labels appear. Battery and volume percentages stay visible."; wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                                            RowLayout {
                                                Layout.fillWidth: true; spacing: 8
                                                Repeater {
                                                    model: [
                                                        {label: "Icons only", key: "icons", icon: "\ue5ca"},
                                                        {label: "With details", key: "details", icon: "\ue8b8"},
                                                        {label: "On hover", key: "hover", icon: "\ue8f4"}
                                                    ]
                                                    delegate: Rectangle {
                                                        id: detailOption
                                                        required property var modelData
                                                        readonly property bool chosen: SettingsStore.cleanRightMode === modelData.key
                                                        Layout.fillWidth: true; Layout.preferredHeight: 61; radius: 10
                                                        color: chosen ? Qt.alpha(Theme.accent, .16) : Theme.surface
                                                        border.width: chosen ? 1 : 0; border.color: Theme.accent
                                                        RowLayout {
                                                            anchors.centerIn: parent; spacing: 6
                                                            Icon { icon: detailOption.chosen ? "\ue5ca" : detailOption.modelData.icon; font.pixelSize: 17; color: Theme.accent }
                                                            Text { text: detailOption.modelData.label; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                                                        }
                                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.cleanRightMode = detailOption.modelData.key; SettingsStore.save(); } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 16
                                color: Theme.surface
                                border.color: Theme.borderaccent
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 11
                                    RowLayout {
                                        Layout.fillWidth: true
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Text { id: marginSearchAnchor; text: "Realtime margin editor"; font.family: Fonts.poppinsSB.name; font.pixelSize: 14; color: Theme.foreground }
                                            Text { text: "Independent margins for each bar mode · 0–32 px · updates immediately"; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.muted }
                                        }
                                        Rectangle {
                                            Layout.preferredWidth: 100; Layout.preferredHeight: 30; radius: 8; color: Theme.background
                                            Text { anchors.centerIn: parent; text: "Reset mode"; font.family: Fonts.poppins.name; font.pixelSize: 10; color: Theme.foreground }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetBarMargins() }
                                        }
                                    }
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2; columnSpacing: 9; rowSpacing: 9
                                        Repeater {
                                            model: [
                                                {edge: "top", name: "Top"}, {edge: "bottom", name: "Bottom"},
                                                {edge: "left", name: "Left"}, {edge: "right", name: "Right"}
                                            ]
                                            delegate: Rectangle {
                                                id: marginCard
                                                required property var modelData
                                                readonly property int fallback: SettingsStore.barMode === "professional" ? 0 :
                                                    (SettingsStore.barPosition === "left" || SettingsStore.barPosition === "right") ? 4 :
                                                    (modelData.edge === "left" || modelData.edge === "right") ? 6 :
                                                    (SettingsStore.barMode === "compact" || SettingsStore.barMode === "clean-compact") ? 4 : 6
                                                readonly property int value: SettingsStore.marginFor(modelData.edge, fallback)
                                                Layout.fillWidth: true; Layout.preferredHeight: 96; radius: 11
                                                color: Theme.background
                                                ColumnLayout {
                                                    anchors.fill: parent; anchors.margins: 12; spacing: 7
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text { text: marginCard.modelData.name; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; color: Theme.foreground }
                                                        Item { Layout.fillWidth: true }
                                                        Text { text: marginCard.value + " px"; font.family: Fonts.poppinsSB.name; font.pixelSize: 12; color: Theme.accent }
                                                    }
                                                    MarginSlider {
                                                        Layout.fillWidth: true; Layout.preferredHeight: 25
                                                        value: marginCard.value
                                                        onPreview: next => SettingsStore.setBarMargin(marginCard.modelData.edge, next, false)
                                                        onCommit: next => SettingsStore.setBarMargin(marginCard.modelData.edge, next, true)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Text { Layout.fillWidth: true; text: "Tip: switch to another bar mode to set its own margins. Reset restores that mode's original spacing."; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10; wrapMode: Text.WordWrap }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 16
                                color: Theme.surface
                                border.color: Theme.borderaccent
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 11
                                    Text {
                                        id: modulesSearchAnchor
                                        text: "Modules & individual icons"
                                        font.family: Fonts.poppinsSB.name
                                        font.pixelSize: 14
                                        color: Theme.foreground
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Turn bar modules on or off independently. Launcher, AI, indicators and Quick Control can each be shown only where you want them."
                                        wrapMode: Text.WordWrap
                                        color: Theme.muted
                                        font.family: Fonts.poppins.name
                                        font.pixelSize: 11
                                    }
                                    Repeater {
                                        model: [
                                            {label: "App launcher", desc: "Search and launch installed applications", key: "showLauncher", icon: "\ue8b6"},
                                            {label: "Arch / AI launcher", desc: "Left launcher button", key: "showArch", icon: "\ueb8e"},
                                            {label: "Workspace switcher", desc: "Hyprland workspaces", key: "showWorkspaces", icon: "\ue30b"},
                                            {label: "Weather", desc: "Weather icon and temperature", key: "showWeather", icon: "\ue430"},
                                            {label: "Clock", desc: "Time icon and time label", key: "showTime", icon: "\ue8b5"},
                                            {label: "Calendar", desc: "Date icon and date label", key: "showDate", icon: "\uebcc"},
                                            {label: "Bluetooth", desc: "Independent Bluetooth indicator", key: "showBluetooth", icon: "\ue1a7"},
                                            {label: "Wi-Fi", desc: "Independent Wi-Fi indicator", key: "showWifi", icon: "\ue63e"},
                                            {label: "Battery", desc: "Battery status and charging percentage", key: "showBattery", icon: "\uf304"},
                                            {label: "Audio", desc: "Volume indicator and percentage", key: "showAudio", icon: "\ue050"},
                                            {label: "Task View icon", desc: "System metrics and processes popup in bar", key: "showTaskView", icon: "\uf190"},
                                            {label: "Notification center", desc: "Automatic toasts and Quick Control history", key: "showNotifications", icon: "\ue7f4"},
                                            {label: "Quick Control button", desc: "Open the full control panel", key: "showQuickControl", icon: "\ue69b"},
                                            {label: "System indicators (group)", desc: "Master toggle for status icons", key: "showIndicators", icon: "\ue8b8"},
                                            {label: "Quick modes", desc: "Compact system mode controls", key: "showQuickModes", icon: "\ue429"}
                                        ]
                                        delegate: SettingsToggle {}
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 16
                                color: Theme.surface
                                border.color: Theme.borderaccent
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 11
                                    Text { text: "Menu bar"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 14 }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Inspired by desktop menu bars. File, Shell and Tools are optional; Edit, View and Share are enabled by default when the menu bar is shown."
                                        wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 11
                                    }
                                    Repeater {
                                        model: [
                                            {label: "Show menu bar", desc: "Show enabled sections at the left", key: "showMenuBar", icon: "\ue5d2"},
                                            {label: "File", desc: "Open Home, Downloads or configuration", key: "showMenuFile", icon: "\ue2c7"},
                                            {label: "Edit", desc: "Appearance, Bar and AI settings", key: "showMenuEdit", icon: "\ue3c9"},
                                            {label: "View", desc: "Switch bar layout modes", key: "showMenuView", icon: "\ue8f4"},
                                            {label: "Share", desc: "Local screenshots", key: "showMenuShare", icon: "\ue3c2"},
                                            {label: "Shell", desc: "Launch a terminal or system monitor", key: "showMenuShell", icon: "\ueb8e"},
                                            {label: "Tools", desc: "Quick access to Settings and screenshots", key: "showMenuTools", icon: "\ue8b8"}
                                        ]
                                        delegate: SettingsToggle {}
                                    }
                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                                    Text { text: "Quick modes"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 14 }
                                    Repeater {
                                        model: [
                                            {label: "Auto-hide quick modes", desc: "Reveal options on hover", key: "quickModesAutoHide", icon: "\ue8f4"},
                                            {label: "Keep Awake", desc: "Prevent sleep temporarily", key: "showKeepAwake", icon: "\ue541"},
                                            {label: "Silent", desc: "Do Not Disturb", key: "showSilent", icon: "\ue7f6"},
                                            {label: "Gaming Mode", desc: "Performance power profile", key: "showGamingMode", icon: "\ue30f"},
                                            {label: "Night Mode", desc: "Warm screen temperature", key: "showNightMode", icon: "\ue51c"},
                                            {label: "Mute Microphone", desc: "Microphone mute", key: "showMicMute", icon: "\ue02b"}
                                        ]
                                        delegate: SettingsToggle {}
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 16
                                color: Theme.surface
                                border.color: Theme.borderaccent
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 11
                                    Text { id: widgetsSearchAnchor; text: "Desktop widgets · behind windows"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 15 }
                                    Text { text: "Widgets live on the Wayland Bottom layer, above wallpaper but behind application windows. Disabled by default."; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: 11 }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 84
                                        radius: 13
                                        color: Theme.background
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10
                                            Repeater {
                                                model: [
                                                    {icon:"\ue916", title:"Calendar", desc:"Monthly view"},
                                                    {icon:"\ue1db", title:"System", desc:"CPU / RAM"},
                                                    {icon:"\ue8b5", title:"Clock", desc:"Large time"}
                                                ]
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    radius: 11
                                                    color: Theme.surface
                                                    ColumnLayout {
                                                        anchors.centerIn: parent
                                                        spacing: 4
                                                        Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 10; color: Qt.alpha(Theme.accent, 0.12); Icon { anchors.centerIn: parent; icon: modelData.icon; font.pixelSize: 16; color: Theme.accent } }
                                                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData.title; font.family: Fonts.poppinsSB.name; font.pixelSize: 10; color: Theme.foreground }
                                                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData.desc; font.family: Fonts.poppins.name; font.pixelSize: 9; color: Theme.muted }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Repeater {
                                        model: [
                                            {label:"Calendar widget",desc:"Persistent monthly calendar",key:"desktopCalendar",icon:"\ue916"},
                                            {label:"System widget",desc:"Live CPU and memory overview",key:"desktopSystem",icon:"\ue1db"},
                                            {label:"Clock widget",desc:"Large clock and date",key:"desktopClock",icon:"\ue8b5"}
                                        ]
                                        delegate: SettingsToggle {}
                                    }
                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                                    Text { id: dockSearchAnchor; text: "Custom dock"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 15 }
                                    Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Bottom-edge dock with optional auto-hide and quick app actions. The first item opens an application launcher using an installed drun tool if available."; color: Theme.muted; font.pixelSize: 11; font.family: Fonts.poppins.name }
                                    Repeater {
                                        model: [
                                            {label:"Enable dock",desc:"Application shortcuts on the bottom edge",key:"showDock",icon:"\ue8b8"},
                                            {label:"Auto-hide dock",desc:"Reveal when hovering the small bottom handle",key:"dockAutoHide",icon:"\ue8f4"},
                                            {label:"Dock · Files",desc:"Open home folder",key:"dockFiles",icon:"\ue2c7"},
                                            {label:"Dock · Browser",desc:"Open default browser",key:"dockBrowser",icon:"\ue80b"},
                                            {label:"Dock · Settings",desc:"Open RusticQ settings",key:"dockSettings",icon:"\ue8b8"},
                                            {label:"Dock · Task View",desc:"Show detailed process monitor",key:"dockTaskView",icon:"\uf190"},
                                            {label:"Dock · AI",desc:"Cloud assistant sidebar",key:"dockAI",icon:"\ue8f4"}
                                        ]
                                        delegate: SettingsToggle {}
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            visible: Store.settingsTab === "display"
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                Layout.fillWidth: true
                                text: "Arrange screens by dragging the monitor previews. Expand each display for available resolutions, Hz and scale, then Apply when ready."
                                color: Theme.muted
                                wrapMode: Text.WordWrap
                                font.family: Fonts.poppins.name
                                font.pixelSize: 11
                            }
                            BarMonitors { Layout.fillWidth: true }
                        }

                        ColumnLayout {
                            visible: Store.settingsTab === "ai"
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: "Choose a cloud provider, configure its model, and store an API key in your Linux keyring. No secret is saved in QML configuration files."
                                wrapMode: Text.WordWrap
                                color: Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: 11
                            }
                            Text { text: "Provider"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Repeater {
                                model: [
                                    { name: "OpenAI · ChatGPT", provider: "openai", model: "gpt-4.1-mini" },
                                    { name: "Anthropic · Claude", provider: "anthropic", model: "claude-haiku-4-5-20251001" },
                                    { name: "Google · Gemini", provider: "gemini", model: "gemini-2.5-flash" }
                                ]
                                delegate: Rectangle {
                                    id: providerRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 45
                                    radius: 10
                                    color: SettingsStore.aiProvider === providerRow.modelData.provider ? Qt.alpha(Theme.accent, 0.15) : Theme.surface
                                    border.color: SettingsStore.aiProvider === providerRow.modelData.provider ? Theme.accent : "transparent"
                                    border.width: SettingsStore.aiProvider === providerRow.modelData.provider ? 1 : 0
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 12
                                        spacing: 9
                                        Icon { icon: "\ue8f4"; font.pixelSize: 18; color: Theme.accent }
                                        Text { Layout.fillWidth: true; text: providerRow.modelData.name; font.pixelSize: 12;
                                            font.family: Fonts.poppins.name; color: Theme.foreground }
                                        Icon { icon: "\ue5ca"; visible: SettingsStore.aiProvider === providerRow.modelData.provider;
                                               font.pixelSize: 19; color: Theme.accent }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            SettingsStore.aiProvider = providerRow.modelData.provider;
                                            SettingsStore.aiModel = providerRow.modelData.model;
                                            SettingsStore.save();
                                            aiModelInput.text = SettingsStore.aiModel;
                                            keyInput.text = "";
                                            keyStatusText.text = "Checking keyring…";
                                            keyAction.startAction("status", {provider: SettingsStore.aiProvider});
                                        }
                                    }
                                }
                            }
                            Text { text: "Model ID"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 45
                                radius: 10
                                color: Theme.surface
                                TextInput {
                                    id: aiModelInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: SettingsStore.aiModel
                                    color: Theme.foreground
                                    font.family: Fonts.poppins.name
                                    font.pixelSize: 12
                                    onAccepted: saveModel()
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 9
                                color: Theme.accent
                                Text { anchors.centerIn: parent; text: "Save Model ID"; color: Theme.background;
                                    font.family: Fonts.poppinsSB.name; font.pixelSize: 11 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveModel() }
                            }
                            Text { text: "API key (Linux Secret Service)"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 13 }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 10
                                color: Theme.surface
                                TextInput {
                                    id: keyInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    echoMode: TextInput.Password
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.foreground
                                    font.family: Fonts.poppins.name
                                    font.pixelSize: 12
                                    clip: true
                                }
                                Text { visible: keyInput.text.length === 0; anchors.verticalCenter: parent.verticalCenter;
                                    x: 12; text: "Paste API key here (hidden)"; color: Theme.muted; font.pixelSize: 11;
                                    font.family: Fonts.poppins.name }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 9; color: Theme.accent
                                    Text { anchors.centerIn: parent; text: "Save key"; font.pixelSize: 11; color: Theme.background;
                                        font.family: Fonts.poppinsSB.name }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                                        onClicked: {
                                            if (!keyInput.text.trim()) { keyStatusText.text = "Enter an API key first"; return; }
                                            keyAction.startAction("key-set", {provider: SettingsStore.aiProvider, key: keyInput.text.trim()});
                                            keyInput.text = "";
                                        } }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 9; color: Theme.surface
                                    Text { anchors.centerIn: parent; text: "Check status"; font.pixelSize: 11; color: Theme.foreground;
                                        font.family: Fonts.poppinsSB.name }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                                        onClicked: keyAction.startAction("status", {provider: SettingsStore.aiProvider}) }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 90; Layout.preferredHeight: 36; radius: 9; color: Theme.surface
                                    Text { anchors.centerIn: parent; text: "Remove key"; font.pixelSize: 11; color: Theme.foreground;
                                        font.family: Fonts.poppinsSB.name }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                                        onClicked: keyAction.startAction("key-delete", {provider: SettingsStore.aiProvider}) }
                                }
                            }
                            Text {
                                id: keyStatusText
                                Layout.fillWidth: true
                                text: "Select Check status to verify keyring access"
                                wrapMode: Text.WordWrap
                                color: Theme.muted
                                font.pixelSize: 11
                                font.family: Fonts.poppins.name
                            }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                            Text {
                                Layout.fillWidth: true
                                text: "Use an API key for in-shell chat. Website login is separate: it opens your provider in a browser and does not authorize the shell."
                                wrapMode: Text.WordWrap
                                color: Theme.muted
                                font.pixelSize: 11
                                font.family: Fonts.poppins.name
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 9; color: Theme.surface
                                Text { anchors.centerIn: parent; text: "Open provider website (browser login)";
                                    font.pixelSize: 11; color: Theme.foreground; font.family: Fonts.poppinsSB.name }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const site = SettingsStore.aiProvider === "openai" ? "https://chatgpt.com/" :
                                            SettingsStore.aiProvider === "anthropic" ? "https://claude.ai/" : "https://gemini.google.com/";
                                        Quickshell.execDetached(["xdg-open", site]);
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            visible: Store.settingsTab === "about"
                            Layout.fillWidth: true
                            spacing: 12
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 118
                                radius: 12
                                color: Theme.surface
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Icon { icon: "\ue8b8"; font.pixelSize: 28; color: Theme.accent; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: "RusticQ · Alpha 3 RC4"; font.family: Fonts.poppinsSB.name; font.pixelSize: 16; color: Theme.foreground; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: "Target: Arch Linux / Quickshell 0.3.1"; font.family: Fonts.poppins.name; font.pixelSize: 11; color: Theme.muted; Layout.alignment: Qt.AlignHCenter }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Configuration: user-settings.json\nTheme: config/Theme.qml\nMonitor control: nwg-displays (optional)\nAI backend: OpenAI / Anthropic / Gemini · Requires API key & libsecret\n\nChanges to appearance and bar visibility are saved automatically."
                                wrapMode: Text.WordWrap
                                color: Theme.foreground
                                font.family: Fonts.poppins.name
                                font.pixelSize: 12
                                lineHeight: 1.55
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    Layout.minimumHeight: 18
                    Layout.maximumHeight: 18
                    Icon { icon: "\ue5ca"; font.pixelSize: 15; color: Theme.success }
                    Text {
                        Layout.fillWidth: true
                        text: "UI settings only · Keys stored separately in keyring"
                        font.family: Fonts.poppins.name
                        font.pixelSize: 10
                        color: Theme.muted
                    }
                }
            }
        }
    }
    onVisibleChanged: { if (!visible) Store.settingsVisible = false; }
}
