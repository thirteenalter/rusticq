import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import "../../config"
import "../../components"
import "../../services"

// A single persistent AI surface: left sidebar or a real wlroots overlay,
// never a Hyprland tiled application or an expanding text input.
PanelWindow {
    id: panel
    readonly property bool fullMode: Store.aiFullMode
    anchors { top: true; left: true; bottom: true; right: panel.fullMode }
    margins { left: panel.fullMode ? 0 : 10; top: panel.fullMode ? 0 : 50; bottom: panel.fullMode ? 0 : 50; right: 0 }
    implicitWidth: panel.fullMode && panel.screen ? panel.screen.width : 402
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: panel.fullMode ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        active: panel.visible && !panel.fullMode
        windows: [panel]
        onCleared: Store.aiVisible = false
    }

    property bool busy: false
    property string pendingPayload: ""
    property bool providerPickerOpen: false
    property bool modelPickerOpen: false
    readonly property var providerChoices: [
        {id:"openai", label:"OpenAI", model:"gpt-4.1-mini"},
        {id:"anthropic", label:"Claude", model:"claude-haiku-4-5-20251001"},
        {id:"gemini", label:"Gemini", model:"gemini-2.5-flash"}
    ]
    readonly property var modelChoices: SettingsStore.aiProvider === "openai" ? ["gpt-4.1-mini", "gpt-4.1", "gpt-4o-mini"] :
        SettingsStore.aiProvider === "anthropic" ? ["claude-haiku-4-5-20251001", "claude-sonnet-4-5-20250929"] :
        ["gemini-2.5-flash", "gemini-2.5-pro"]
    function selectProvider(entry) {
        SettingsStore.aiProvider = entry.id;
        SettingsStore.aiModel = entry.model;
        SettingsStore.save();
        providerPickerOpen = false;
        modelPickerOpen = false;
    }
    function selectModel(model) { SettingsStore.aiModel = model; SettingsStore.save(); modelPickerOpen = false; }
    Process {
        id: cloudRequest
        stdinEnabled: true
        command: ["python3", Quickshell.shellPath("scripts/cloud_ai.py"), "ask"]
        onStarted: { write(panel.pendingPayload + "\n"); panel.pendingPayload = ""; }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text.trim());
                    if (!response.ok) throw Error(response.message || "Cloud response error");
                    AiChats.append("assistant", response.reply);
                } catch (e) { AiChats.append("system", "AI request failed: " + e); }
                panel.busy = false;
                scrollToEnd.restart();
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && panel.busy) {
                AiChats.append("system", "Cloud helper exited with code " + code + ". Check provider and API key.");
                panel.busy = false;
                scrollToEnd.restart();
            }
        }
    }
    Timer { id: scrollToEnd; interval: 50; onTriggered: if (messageList.count) messageList.positionViewAtEnd() }
    function sendMessage() {
        const prompt = composer.text.trim();
        if (!prompt || panel.busy) return;
        composer.text = "";
        AiChats.append("user", prompt);
        const recent = AiChats.activeMessages.slice(-18)
            .filter(e => e.role === "user" || e.role === "assistant")
            .map(e => ({ role:e.role, content:e.content }));
        pendingPayload = JSON.stringify({provider:SettingsStore.aiProvider, model:SettingsStore.aiModel, messages:recent});
        busy = true;
        cloudRequest.running = true;
        scrollToEnd.restart();
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: panel.fullMode ? 0 : Theme.sectionRadius
        border.width: panel.fullMode ? 0 : 1
        border.color: Theme.borderaccent
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                visible: panel.fullMode
                Layout.preferredWidth: panel.fullMode ? 254 : 0
                Layout.fillHeight: true
                color: Theme.surface
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        RusticQIcon { iconSize: 30 }
                        Text { Layout.fillWidth: true; text: "RusticQ AI"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(15) }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10; color: Theme.borderaccent
                        RowLayout { anchors.centerIn: parent; spacing: 7
                            Icon { icon: "\ue145"; color: Theme.accent; font.pixelSize: 18 }
                            Text { text: "New conversation"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                        }
                        MouseArea { anchors.fill: parent; enabled: !panel.busy; cursorShape: Qt.PointingHandCursor; onClicked: AiChats.newChat() }
                    }
                    Text { text: "CONVERSATIONS"; color: Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                    ListView {
                        id: threadsList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                        model: AiChats.threads
                        delegate: Rectangle {
                            id: thread
                            required property var modelData
                            readonly property bool selected: AiChats.activeId === modelData.id
                            width: threadsList.width; height: 48; radius: 10
                            color: selected ? Qt.alpha(Theme.accent, 0.14) : Theme.background
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 5; spacing: 7
                                Icon { icon: "\ue0b7"; font.pixelSize: 17; color: Theme.accent }
                                Text { Layout.fillWidth: true; text: thread.modelData.title; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 7
                                    color: deleteMouse.containsMouse ? Theme.borderaccent : "transparent"
                                    Icon { anchors.centerIn: parent; icon: "\ue872"; color: Theme.muted; font.pixelSize: 15 }
                                    MouseArea { id: deleteMouse; anchors.fill: parent; hoverEnabled: true; enabled: !panel.busy; cursorShape: Qt.PointingHandCursor; onClicked: AiChats.remove(thread.modelData.id) }
                                }
                            }
                            MouseArea { anchors.fill: parent; anchors.rightMargin: 32; cursorShape: Qt.PointingHandCursor; enabled: !panel.busy; onClicked: { AiChats.selectChat(thread.modelData.id); scrollToEnd.restart(); } }
                        }
                    }
                    Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Session history stays in memory · Requests go to your selected provider."; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                }
            }
            Rectangle { visible: panel.fullMode; Layout.preferredWidth: panel.fullMode ? 1 : 0; Layout.fillHeight: true; color: Theme.borderaccent }

            Item {
                id: conversationPane
                Layout.fillWidth: true; Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: panel.fullMode ? 24 : 12
                    anchors.rightMargin: panel.fullMode ? 24 : 12
                    anchors.topMargin: panel.fullMode ? 18 : 12
                    anchors.bottomMargin: panel.fullMode ? 20 : 12
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 43; Layout.maximumHeight: 43
                        spacing: 8
                        Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 10; color: Theme.surface
                            Icon { anchors.centerIn: parent; icon: "\uf371"; color: Theme.accent; font.pixelSize: 19 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { Layout.fillWidth: true; text: panel.fullMode ? AiChats.currentTitle : "RusticQ AI"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(14); elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: SettingsStore.aiProvider.toUpperCase() + " / " + SettingsStore.aiModel; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); elide: Text.ElideRight }
                        }
                        Repeater {
                            model: [{icon:panel.fullMode ? "\ue5d1" : "\ue5d0", action:"expand"}, {icon:"\ue8b8", action:"settings"}, {icon:"\ue5cd",action:"close"}]
                            delegate: Rectangle {
                                id: headerAction
                                required property var modelData
                                Layout.preferredWidth: 31; Layout.preferredHeight: 31; radius: 9; color: Theme.surface
                                Icon { anchors.centerIn: parent; icon: headerAction.modelData.icon; font.pixelSize: 18; color: Theme.foreground }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                    if (headerAction.modelData.action === "expand") Store.aiFullMode = !Store.aiFullMode;
                                    else if (headerAction.modelData.action === "settings") Store.showSettings("ai");
                                    else Store.aiVisible = false;
                                } }
                            }
                        }
                    }
                    // Inline selectors share the SettingsStore values with Settings > AI.
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 31; Layout.maximumHeight: 31; spacing: 7
                        Rectangle { id: providerButton; Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 9; color: Theme.surface
                            RowLayout { anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 8; spacing: 6
                                Icon { icon: "\uf371"; color: Theme.accent; font.pixelSize: 14 }
                                Text { Layout.fillWidth: true; text: SettingsStore.aiProvider.toUpperCase(); elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                                Icon { icon: "\ue5cf"; color: Theme.muted; font.pixelSize: 16 }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { panel.providerPickerOpen = !panel.providerPickerOpen; panel.modelPickerOpen = false; } }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 9; color: Theme.surface
                            RowLayout { anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 8; spacing: 6
                                Text { Layout.fillWidth: true; text: SettingsStore.aiModel; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                                Icon { icon: "\ue5cf"; color: Theme.muted; font.pixelSize: 16 }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { panel.modelPickerOpen = !panel.modelPickerOpen; panel.providerPickerOpen = false; } }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.maximumHeight: 1; color: Theme.borderaccent }
                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                        clip: true
                        ListView {
                            id: messageList
                            anchors.fill: parent; spacing: 10; clip: true
                            model: AiChats.activeMessages
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Item {
                                id: messageRow
                                required property var modelData
                                readonly property bool fromUser: modelData.role === "user"
                                width: messageList.width
                                height: bubble.implicitHeight + 2
                                Rectangle {
                                    id: bubble
                                    readonly property int pad: 12
                                    width: Math.max(180, Math.min(messageRow.width * (panel.fullMode ? 0.83 : 0.98), panel.fullMode ? 780 : 350))
                                    implicitHeight: Math.max(48, bodyText.implicitHeight + 2 * pad + 19)
                                    x: messageRow.fromUser ? messageRow.width - width : 0
                                    radius: 12; color: messageRow.fromUser ? Qt.alpha(Theme.accent, 0.15) : Theme.surface
                                    Text { text: messageRow.fromUser ? "YOU" : messageRow.modelData.role === "system" ? "RUSTICQ" : "ASSISTANT"; x: bubble.pad; y: 7; color: Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(9) }
                                    Text {
                                        id: bodyText
                                        x: bubble.pad; y: 24; width: parent.width - bubble.pad * 2
                                        text: messageRow.fromUser ? messageRow.modelData.content : AiChats.safeMarkdown(messageRow.modelData.content)
                                        textFormat: messageRow.fromUser || messageRow.modelData.role === "system" ? Text.PlainText : Text.MarkdownText
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        color: messageRow.modelData.role === "system" ? Theme.error : Theme.foreground
                                        font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
                                        onLinkActivated: link => Qt.openUrlExternally(link)
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            visible: AiChats.activeMessages.length === 0
                            anchors.centerIn: parent
                            width: Math.max(150, Math.min(parent.width - 28, 350))
                            spacing: 9
                            RusticQIcon { Layout.alignment: Qt.AlignHCenter; iconSize: 44 }
                            Text { Layout.fillWidth: true; text: "Your AI workspace"; horizontalAlignment: Text.AlignHCenter; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(15) }
                            Text { Layout.fillWidth: true; text: "Ask a question, start a new conversation, or choose a model above."; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 17; Layout.maximumHeight: 17; spacing: 8
                        Text { Layout.fillWidth: true; text: panel.busy ? "Generating…" : "Enter to send"; color: panel.busy ? Theme.accent : Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                        Text { text: "Clear chat"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                            MouseArea { anchors.fill: parent; enabled: !panel.busy && AiChats.activeMessages.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: AiChats.clearCurrent() }
                        }
                    }
                    // Fixed-size input footer. Nothing here requests fillHeight.
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 48; Layout.minimumHeight: 48; Layout.maximumHeight: 48
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 12; color: Theme.surface
                            TextInput { id: composer; anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 13; verticalAlignment: TextInput.AlignVCenter; clip: true; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12); onAccepted: panel.sendMessage(); Keys.onEscapePressed: Store.aiVisible = false }
                            Text { visible: composer.text.length === 0; anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter; text: "Ask something…"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
                        }
                        Rectangle { Layout.preferredWidth: 46; Layout.preferredHeight: 48; radius: 12; color: panel.busy ? Theme.surface : Theme.accent
                            Icon { anchors.centerIn: parent; icon: "\ue163"; color: panel.busy ? Theme.muted : Theme.background; font.pixelSize: 20 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !panel.busy; onClicked: panel.sendMessage() }
                        }
                    }
                }
                // Menu overlays intentionally cover the toolbar, never the composer.
                Rectangle {
                    id: selectorPopup
                    visible: panel.providerPickerOpen || panel.modelPickerOpen
                    z: 20
                    anchors.top: parent.top; anchors.topMargin: 88
                    anchors.left: parent.left; anchors.leftMargin: panel.fullMode ? 24 : 12
                    width: Math.min(parent.width - (panel.fullMode ? 48 : 24), panel.fullMode ? 340 : 350)
                    implicitHeight: selectorContent.implicitHeight + 12
                    radius: 12; color: Theme.surface; border.width: 1; border.color: Theme.borderaccent
                    ColumnLayout { id: selectorContent; x: 6; y: 6; width: parent.width - 12; spacing: 3
                        Repeater {
                            model: panel.providerPickerOpen ? panel.providerChoices : panel.modelChoices
                            delegate: Rectangle { id: selectorEntry; required property var modelData
                                Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 8
                                color: selectorMouse.containsMouse ? Qt.alpha(Theme.accent, 0.15) : "transparent"
                                Text { anchors.fill: parent; anchors.leftMargin: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                    text: panel.providerPickerOpen ? selectorEntry.modelData.label : String(selectorEntry.modelData)
                                    color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
                                MouseArea { id: selectorMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: {
                                    if (panel.providerPickerOpen) panel.selectProvider(selectorEntry.modelData);
                                    else panel.selectModel(String(selectorEntry.modelData));
                                } }
                            }
                        }
                    }
                }
            }
        }
    }
}
