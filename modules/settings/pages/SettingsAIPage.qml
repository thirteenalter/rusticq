import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    id: settingsPageRoot
    readonly property var settingsTheme: SettingsMaterial.forItem(settingsPageRoot)
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
                if (keyAction.action === "status") keyStatusText.text = response.configured ? "API key configured in Linux keyring" : "No API key saved for this provider";
                else keyStatusText.text = response.message;
            } catch (e) { keyStatusText.text = "Keyring: " + e; }
        }
    }
    onExited: (code, status) => { if (code !== 0) keyStatusText.text = "Key helper failed (exit " + code + ")"; }
}

                            width: parent ? parent.width : 680
                            Layout.fillWidth: true
                            spacing: 12

                            GlassLabel {
                                Layout.fillWidth: true
                                text: "Choose a cloud provider, configure its model, and store an API key in your Linux keyring. No secret is saved in QML configuration files."
                                wrapMode: Text.WordWrap
                                color: settingsPageRoot.settingsTheme.contentMuted
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(12)
                            }
                            GlassLabel { text: "Provider"; color: settingsPageRoot.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
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
                                    radius: settingsPageRoot.settingsTheme.glassRadius("card", 10)
                                    color: settingsPageRoot.settingsTheme.glassColor("card", SettingsStore.aiProvider === providerRow.modelData.provider ? Qt.alpha(settingsPageRoot.settingsTheme.accent, 0.15) : settingsPageRoot.settingsTheme.surface)
                                    border.color: settingsPageRoot.settingsTheme.glassBorder("card", SettingsStore.aiProvider === providerRow.modelData.provider ? settingsPageRoot.settingsTheme.accent : "transparent")
                                    border.width: settingsPageRoot.settingsTheme.glassBorderWidth("card", SettingsStore.aiProvider === providerRow.modelData.provider ? 1 : 0)
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 12
                                        spacing: 9
                                        Icon { icon: "\uf371"; font.pixelSize: Fonts.scale(18); color: settingsPageRoot.settingsTheme.accent }
                                        GlassLabel { Layout.fillWidth: true; text: providerRow.modelData.name; font.pixelSize: Fonts.scale(12);
                                            font.family: Fonts.poppins.name; color: settingsPageRoot.settingsTheme.foreground }
                                        Icon { icon: "\ue5ca"; visible: SettingsStore.aiProvider === providerRow.modelData.provider;
                                               font.pixelSize: Fonts.scale(19); color: settingsPageRoot.settingsTheme.accent }
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
                            GlassLabel { text: "Model ID"; color: settingsPageRoot.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 45
                                radius: settingsPageRoot.settingsTheme.glassRadius("card", 10)
                                color: settingsPageRoot.settingsTheme.glassColor("card", settingsPageRoot.settingsTheme.surface)
                                TextInput {
                                    id: aiModelInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: SettingsStore.aiModel
                                    color: settingsPageRoot.settingsTheme.foreground
                                    font.family: Fonts.poppins.name
                                    font.pixelSize: Fonts.scale(12)
                                    onAccepted: saveModel()
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 9
                                color: settingsPageRoot.settingsTheme.accent
                                GlassLabel { anchors.centerIn: parent; text: "Save Model ID"; color: settingsPageRoot.settingsTheme.background;
                                    font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveModel() }
                            }
                            GlassLabel { text: "Suggested models"; color: settingsPageRoot.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                            ColumnLayout { Layout.fillWidth: true; spacing: 5
                                Repeater {
                                    model: SettingsStore.aiProvider === "openai" ? ["gpt-4.1-mini", "gpt-4.1", "gpt-4o-mini"] :
                                           SettingsStore.aiProvider === "anthropic" ? ["claude-haiku-4-5-20251001", "claude-sonnet-4-5-20250929"] :
                                           ["gemini-2.5-flash", "gemini-2.5-pro"]
                                    delegate: Rectangle { id: modelChoice; required property string modelData
                                        Layout.fillWidth: true; Layout.preferredHeight: 32; radius: settingsPageRoot.settingsTheme.glassRadius("card", 9)
                                        color: settingsPageRoot.settingsTheme.glassColor("card", SettingsStore.aiModel === modelData ? Qt.alpha(settingsPageRoot.settingsTheme.accent,0.15) : settingsPageRoot.settingsTheme.surface)
                                        RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                                            GlassLabel { Layout.fillWidth: true; text: modelChoice.modelData; color: settingsPageRoot.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
                                            Icon { visible: SettingsStore.aiModel === modelChoice.modelData; icon: "\ue5ca"; color: settingsPageRoot.settingsTheme.accent; font.pixelSize: 16 }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.aiModel = modelChoice.modelData; SettingsStore.save(); aiModelInput.text = modelChoice.modelData; } }
                                    }
                                }
                            }
                            GlassLabel { text: "API key (Linux Secret Service)"; color: settingsPageRoot.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: settingsPageRoot.settingsTheme.glassRadius("card", 10)
                                color: settingsPageRoot.settingsTheme.glassColor("card", settingsPageRoot.settingsTheme.surface)
                                TextInput {
                                    id: keyInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    echoMode: TextInput.Password
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: settingsPageRoot.settingsTheme.foreground
                                    font.family: Fonts.poppins.name
                                    font.pixelSize: Fonts.scale(12)
                                    clip: true
                                }
                                GlassLabel { visible: keyInput.text.length === 0; anchors.verticalCenter: parent.verticalCenter;
                                    x: 12; text: "Paste API key here (hidden)"; color: settingsPageRoot.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(12);
                                    font.family: Fonts.poppins.name }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 9; color: settingsPageRoot.settingsTheme.accent
                                    GlassLabel { anchors.centerIn: parent; text: "Save key"; font.pixelSize: Fonts.scale(12); color: settingsPageRoot.settingsTheme.background;
                                        font.family: Fonts.poppinsSB.name }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                                        onClicked: {
                                            if (!keyInput.text.trim()) { keyStatusText.text = "Enter an API key first"; return; }
                                            keyAction.startAction("key-set", {provider: SettingsStore.aiProvider, key: keyInput.text.trim()});
                                            keyInput.text = "";
                                        } }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 36; radius: settingsPageRoot.settingsTheme.glassRadius("card", 9); color: settingsPageRoot.settingsTheme.glassColor("card", settingsPageRoot.settingsTheme.surface)
                                    GlassLabel { anchors.centerIn: parent; text: "Check status"; font.pixelSize: Fonts.scale(12); color: settingsPageRoot.settingsTheme.foreground;
                                        font.family: Fonts.poppinsSB.name }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                                        onClicked: keyAction.startAction("status", {provider: SettingsStore.aiProvider}) }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 90; Layout.preferredHeight: 36; radius: settingsPageRoot.settingsTheme.glassRadius("card", 9); color: settingsPageRoot.settingsTheme.glassColor("card", settingsPageRoot.settingsTheme.surface)
                                    GlassLabel { anchors.centerIn: parent; text: "Remove key"; font.pixelSize: Fonts.scale(12); color: settingsPageRoot.settingsTheme.foreground;
                                        font.family: Fonts.poppinsSB.name }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                                        onClicked: keyAction.startAction("key-delete", {provider: SettingsStore.aiProvider}) }
                                }
                            }
                            GlassLabel {
                                id: keyStatusText
                                Layout.fillWidth: true
                                text: "Select Check status to verify keyring access"
                                wrapMode: Text.WordWrap
                                color: settingsPageRoot.settingsTheme.contentMuted
                                font.pixelSize: Fonts.scale(12)
                                font.family: Fonts.poppins.name
                            }
                            Item { Layout.fillWidth: true; Layout.preferredHeight: settingsPageRoot.settingsTheme.sectionGap }
                            GlassLabel {
                                Layout.fillWidth: true
                                text: "Use an API key for in-shell chat. Website login is separate: it opens your provider in a browser and does not authorize the shell."
                                wrapMode: Text.WordWrap
                                color: settingsPageRoot.settingsTheme.contentMuted
                                font.pixelSize: Fonts.scale(12)
                                font.family: Fonts.poppins.name
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 38; radius: settingsPageRoot.settingsTheme.glassRadius("card", 9); color: settingsPageRoot.settingsTheme.glassColor("card", settingsPageRoot.settingsTheme.surface)
                                GlassLabel { anchors.centerIn: parent; text: "Open provider website (browser login)";
                                    font.pixelSize: Fonts.scale(12); color: settingsPageRoot.settingsTheme.foreground; font.family: Fonts.poppinsSB.name }
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
