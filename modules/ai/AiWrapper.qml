import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../config"
import "../../components"

// Full-height left sidebar, with exactly three vertical regions:
// header (fixed), messages (flex), composer (fixed). Nothing is allowed to
// stretch the send button or input into the chat viewport.
PanelWindow {
    id: panel
    anchors.top: true
    anchors.left: true
    anchors.bottom: true
    margins.left: 10
    margins.top: 50
    margins.bottom: 50
    implicitWidth: 400
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    HyprlandFocusGrab {
        active: true
        windows: [panel]
        onCleared: Store.aiVisible = false
    }

    property bool busy: false
    property string pendingPayload: ""
    ListModel { id: chatHistory }
    Process {
        id: cloudRequest
        stdinEnabled: true
        command: ["python3", Quickshell.shellPath("scripts/cloud_ai.py"), "ask"]
        onStarted: {
            write(panel.pendingPayload + "\n");
            panel.pendingPayload = "";
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text.trim());
                    if (!response.ok) throw Error(response.message || "Unknown cloud AI error");
                    chatHistory.append({ role: "assistant", content: response.reply });
                } catch (e) {
                    chatHistory.append({ role: "system", content: "AI request failed: " + e });
                }
                panel.busy = false;
                scrollToEnd.start();
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && panel.busy) {
                chatHistory.append({ role: "system", content: "AI helper could not run (exit " + code + "). Check Python 3 and libsecret." });
                panel.busy = false;
                scrollToEnd.start();
            }
        }
    }
    Timer {
        id: scrollToEnd
        interval: 30
        onTriggered: messageList.positionViewAtEnd()
    }
    function sendMessage() {
        const prompt = composer.text.trim();
        if (!prompt || busy) return;
        composer.text = "";
        chatHistory.append({ role: "user", content: prompt });
        const recent = [];
        for (let i = Math.max(0, chatHistory.count - 18); i < chatHistory.count; i++) {
            const entry = chatHistory.get(i);
            if (entry.role === "user" || entry.role === "assistant")
                recent.push({ role: entry.role, content: entry.content });
        }
        // Send prompts via stdin, never command-line arguments or logs.
        pendingPayload = JSON.stringify({provider: SettingsStore.aiProvider,
                                         model: SettingsStore.aiModel, messages: recent});
        busy = true;
        cloudRequest.running = true;
        scrollToEnd.start();
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Theme.background
        border.width: 1
        border.color: Theme.borderaccent
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.minimumHeight: 48
                Layout.maximumHeight: 48
                spacing: 9
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Theme.surface
                    Icon { anchors.centerIn: parent; icon: "\ue8b8"; font.pixelSize: 20; color: Theme.accent }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { text: "RusticQ AI"; font.family: Fonts.poppinsSB.name; font.pixelSize: 16; color: Theme.foreground }
                    Text {
                        text: SettingsStore.aiProvider.toUpperCase() + " / " + SettingsStore.aiModel
                        font.family: Fonts.poppins.name
                        font.pixelSize: 10
                        color: Theme.muted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 9
                    color: Theme.surface
                    Icon { anchors.centerIn: parent; icon: "\ue8b8"; font.pixelSize: 18; color: Theme.accent }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Store.showSettings("ai")
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 9
                    color: Theme.surface
                    Icon { anchors.centerIn: parent; icon: "\ue5cd"; font.pixelSize: 18; color: Theme.foreground }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Store.aiVisible = false
                    }
                }
            }

            Rectangle {
                id: conversation
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 150
                radius: 15
                color: Qt.alpha(Theme.foreground, 0.025)
                clip: true

                ListView {
                    id: messageList
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    spacing: 10
                    model: chatHistory
                    delegate: Item {
                        id: messageRow
                        required property string role
                        required property string content
                        width: messageList.width
                        height: bubble.height + 2
                        Rectangle {
                            id: bubble
                            width: messageRow.width * 0.91
                            height: messageText.implicitHeight + 22
                            x: messageRow.role === "user" ? messageRow.width - width : 0
                            radius: 13
                            color: messageRow.role === "user" ? Qt.alpha(Theme.accent, 0.19) : Theme.surface
                            Text {
                                id: messageText
                                anchors.fill: parent
                                anchors.margins: 11
                                text: messageRow.content
                                textFormat: Text.PlainText
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                font.family: Fonts.poppins.name
                                font.pixelSize: 12
                                color: messageRow.role === "system" ? Theme.error : Theme.foreground
                            }
                        }
                    }
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 38
                    spacing: 11
                    visible: chatHistory.count === 0
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: 18
                        color: Qt.alpha(Theme.accent, 0.12)
                        Icon { anchors.centerIn: parent; icon: "\ue8b8"; font.pixelSize: 30; color: Theme.accent }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Your personal workspace"
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: 15
                        color: Theme.foreground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Chat with your selected cloud provider. Messages are sent to its API and are not saved by the shell."
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Fonts.poppins.name
                        font.pixelSize: 11
                        color: Theme.muted
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                Layout.minimumHeight: 18
                Layout.maximumHeight: 18
                Text {
                    Layout.fillWidth: true
                    text: panel.busy ? "Generating response…" : "Enter to send · Cloud API"
                    elide: Text.ElideRight
                    font.family: Fonts.poppins.name
                    font.pixelSize: 10
                    color: panel.busy ? Theme.accent : Theme.muted
                }
                Text {
                    text: "Clear"
                    opacity: chatHistory.count > 0 ? 1 : 0.4
                    font.family: Fonts.poppins.name
                    font.pixelSize: 10
                    color: Theme.muted
                    MouseArea { anchors.fill: parent; enabled: chatHistory.count > 0 && !panel.busy; cursorShape: Qt.PointingHandCursor; onClicked: chatHistory.clear() }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.minimumHeight: 48
                Layout.maximumHeight: 48
                RowLayout {
                    anchors.fill: parent
                    spacing: 8
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 12
                        color: Theme.surface
                        TextInput {
                            id: composer
                            anchors.fill: parent
                            anchors.leftMargin: 13
                            anchors.rightMargin: 13
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            color: Theme.foreground
                            font.family: Fonts.poppins.name
                            font.pixelSize: 12
                            onAccepted: panel.sendMessage()
                        }
                        Text {
                            visible: composer.text.length === 0
                            anchors.left: parent.left
                            anchors.leftMargin: 13
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Ask something…"
                            color: Theme.muted
                            font.family: Fonts.poppins.name
                            font.pixelSize: 12
                            MouseArea { anchors.fill: parent; onClicked: composer.forceActiveFocus() }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: 12
                        color: panel.busy ? Theme.surface : Theme.accent
                        Icon {
                            anchors.centerIn: parent
                            icon: "\ue163"
                            font.pixelSize: 21
                            color: panel.busy ? Theme.muted : Theme.background
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !panel.busy
                            onClicked: panel.sendMessage()
                        }
                    }
                }
            }
        }
    }
}
