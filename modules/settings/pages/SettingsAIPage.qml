import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
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
                                        Icon { icon: "\uf371"; font.pixelSize: 18; color: Theme.accent }
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
