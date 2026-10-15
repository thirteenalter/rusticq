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
    implicitWidth: 760
    implicitHeight: 585
    color: Theme.background

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
            anchors.margins: 16
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                color: Qt.alpha(Theme.foreground, 0.04)
                border.color: Theme.borderaccent
                radius: 12
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 9
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 51
                        spacing: 9
                        Rectangle {
                            Layout.preferredWidth: 33
                            Layout.preferredHeight: 33
                            radius: 10
                            color: Qt.alpha(Theme.accent, 0.15)
                            Icon { anchors.centerIn: parent; icon: "\ue8b8"; font.pixelSize: 20; color: Theme.accent }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: "SETTINGS"; font.family: Fonts.poppinsSB.name; font.pixelSize: 13; color: Theme.foreground }
                            Text { text: Theme.useAether ? "AETHER SYNC" : "RUSTICQ ALPHA"; font.family: Fonts.poppins.name; font.pixelSize: 9; color: Theme.muted }
                        }
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
                            Layout.preferredHeight: 44
                            radius: 9
                            color: Store.settingsTab === tab.modelData.key ? Qt.alpha(Theme.accent, 0.19) : "transparent"
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
                                    font.pixelSize: 12
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
                                onClicked: { Store.settingsTab = tab.modelData.key; settingsScroll.contentY = 0; }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: "RUSTIQ ALPHA 1\nQuickshell 0.3.1"
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
                    Layout.preferredHeight: 46
                    Layout.minimumHeight: 46
                    Layout.maximumHeight: 46
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: Store.settingsTab === "appearance" ? "Appearance" : Store.settingsTab === "bar" ? "Bar & modules" :
                                  Store.settingsTab === "display" ? "Display configuration" : Store.settingsTab === "ai" ? "AI Providers" : "About this shell"
                            color: Theme.foreground
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: 19
                        }
                        Text {
                            text: "PERSONALIZE RUSTICQ"
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

                Flickable {
                    id: settingsScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentHeight: settingContent.implicitHeight + 18
                    ColumnLayout {
                        id: settingContent
                        width: settingsScroll.width
                        spacing: 12

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
                            spacing: 11
                            Text {
                                text: "Bar layout mode"
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: 14
                                color: Theme.foreground
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Select a layout. The bar updates live on every monitor; your module toggles remain saved."
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
                                        color: selected ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
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
                                                Icon {
                                                    visible: modeCard.selected
                                                    icon: "\ue5ca"; font.pixelSize: 18; color: Theme.accent
                                                }
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
                                                color: modeCard.modelData.key === "professional" ? Theme.background : Qt.alpha(Theme.foreground, 0.06)
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 6; anchors.rightMargin: 6
                                                    spacing: 4
                                                    Rectangle {
                                                        Layout.preferredWidth: modeCard.modelData.key === "simple" ? 11 : 36
                                                        Layout.preferredHeight: modeCard.modelData.key === "clean-compact" ? 2 : 12
                                                        radius: 4
                                                        color: modeCard.modelData.key === "separated" ? Theme.background : Qt.alpha(Theme.accent, 0.4)
                                                    }
                                                    Item { Layout.fillWidth: true }
                                                    Rectangle {
                                                        Layout.preferredWidth: modeCard.modelData.key === "simple" ? 13 : 21
                                                        Layout.preferredHeight: ["compact", "clean-compact"].indexOf(modeCard.modelData.key) !== -1 ? 5 : 10
                                                        radius: 4
                                                        color: modeCard.modelData.key === "simple" ? Theme.accent : Theme.muted
                                                    }
                                                    Item { Layout.fillWidth: true }
                                                    Rectangle {
                                                        Layout.preferredWidth: modeCard.modelData.key === "simple" ? 12 : 45
                                                        Layout.preferredHeight: 12
                                                        radius: 4
                                                        color: modeCard.modelData.key === "separated" ? Theme.background : Qt.alpha(Theme.accent, 0.4)
                                                    }
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
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                            Text {
                                text: "Visible modules"
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: 14
                                color: Theme.foreground
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Choose which components appear on your desktop bar. Changes are saved immediately."
                                wrapMode: Text.WordWrap
                                color: Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: 11
                            }
                            Repeater {
                                model: [
                                    {label: "Workspace switcher", desc: "Hyprland workspaces", key: "showWorkspaces", icon: "\ue30b"},
                                    {label: "Weather", desc: "Weather indicator", key: "showWeather", icon: "\ue430"},
                                    {label: "System indicators", desc: "Wi-Fi, battery, Bluetooth", key: "showIndicators", icon: "\ue8b8"},
                                    {label: "Quick modes", desc: "One group for desktop mode controls", key: "showQuickModes", icon: "\ue429"},
                                    {label: "Auto-hide quick modes", desc: "Reveal on hover; hide when the pointer leaves", key: "quickModesAutoHide", icon: "\ue8f4"},
                                    {label: "Keep Awake", desc: "Show Keep Awake in Quick modes", key: "showKeepAwake", icon: "\ue541"},
                                    {label: "Silent", desc: "Show notification Do Not Disturb in Quick modes", key: "showSilent", icon: "\ue7f6"},
                                    {label: "Gaming Mode", desc: "Show Performance power profile in Quick modes", key: "showGamingMode", icon: "\ue30f"},
                                    {label: "Night Mode", desc: "Show warm screen temperature in Quick modes", key: "showNightMode", icon: "\ue51c"},
                                    {label: "Mute Microphone", desc: "Show microphone mute in Quick modes", key: "showMicMute", icon: "\ue02b"}
                                ]
                                delegate: Rectangle {
                                    id: moduleRow
                                    required property var modelData
                                    readonly property bool enabledSetting: SettingsStore[modelData.key]
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 65
                                    radius: 11
                                    color: Theme.surface
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10
                                        Icon {
                                            Layout.minimumWidth: 24
                                            Layout.preferredWidth: 24
                                            Layout.maximumWidth: 24
                                            Layout.alignment: Qt.AlignVCenter
                                            icon: moduleRow.modelData.icon
                                            font.pixelSize: 20
                                            color: Theme.accent
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 1
                                            Text {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignLeft
                                                elide: Text.ElideRight
                                                text: moduleRow.modelData.label
                                                color: Theme.foreground
                                                font.family: Fonts.poppinsSB.name
                                                font.pixelSize: 12
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignLeft
                                                elide: Text.ElideRight
                                                text: moduleRow.modelData.desc
                                                color: Theme.muted
                                                font.family: Fonts.poppins.name
                                                font.pixelSize: 10
                                            }
                                        }
                                        Icon {
                                            Layout.minimumWidth: 24
                                            Layout.preferredWidth: 24
                                            Layout.maximumWidth: 24
                                            Layout.alignment: Qt.AlignVCenter
                                            icon: moduleRow.enabledSetting ? "\ue5ca" : "\ue5cd"
                                            color: moduleRow.enabledSetting ? Theme.accent : Theme.muted
                                            font.pixelSize: 20
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            SettingsStore[moduleRow.modelData.key] = !moduleRow.enabledSetting;
                                            SettingsStore.save();
                                        }
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
                                text: "Connected displays and their current settings. Launch nwg-displays to change placement, scale, resolution or refresh rate."
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
                                    Text { text: "RusticQ · Alpha 1"; font.family: Fonts.poppinsSB.name; font.pixelSize: 16; color: Theme.foreground; Layout.alignment: Qt.AlignHCenter }
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
