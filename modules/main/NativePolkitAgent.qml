import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import "../../config"

// Real, long-lived Polkit authentication agent. It registers with polkitd and
// delegates identity verification, prompts, retries and fingerprint to PAM.
// This is NOT a custom sudo dialog and never runs a privileged shell command.
// Keep independent from package confirmation windows: other applications must
// also be able to authenticate even if RusticQ Settings is closed.
Scope {
    id: root
    readonly property var flow: nativeAgent.flow
    readonly property bool activeRequest: nativeAgent.isActive && flow !== null
    property string lastError: ""
    function activeMonitor() {
        const focused = Hyprland.focusedMonitor;
        const name = focused ? focused.name : "";
        for (let i = 0; i < Quickshell.screens.length; ++i) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
        }
        return Store.settingsScreen || (Quickshell.screens.length ? Quickshell.screens[0] : null);
    }
    function sendResponse() {
        if (!root.flow || !root.flow.isResponseRequired) return;
        // Never log, persist, serialize, or forward the credential to Store or
        // any Python process. Submit solely to Quickshell's native Polkit flow.
        const answer = secretField.text;
        secretField.clear();
        root.flow.submit(answer);
    }
    function abortRequest() {
        secretField.clear();
        if (root.flow) root.flow.cancelAuthenticationRequest();
    }

    PolkitAgent {
        id: nativeAgent
        onAuthenticationRequestStarted: {
            root.lastError = "";
            secretField.clear();
            Qt.callLater(function() {
                if (authWindow.visible && root.flow && root.flow.isResponseRequired)
                    secretField.forceActiveFocus();
            });
        }
    }

    // This is the actual privileged-authentication UI. The earlier package
    // overlay is non-privileged consent and closes before pkexec is invoked.
    PanelWindow {
        id: authWindow
        visible: root.activeRequest
        screen: root.activeMonitor()
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        onVisibleChanged: {
            secretField.clear();
            if (visible) Qt.callLater(function() {
                if (root.flow && root.flow.isResponseRequired) secretField.forceActiveFocus();
                else keyboard.forceActiveFocus();
            });
        }
        HyprlandFocusGrab {
            active: authWindow.visible
            windows: [authWindow]
            // Do not cancel on focus transfer: PAM may open a fingerprint prompt
            // or another registered agent may use focus while authenticating.
        }
        Connections {
            target: root.flow
            ignoreUnknownSignals: true
            function onIsResponseRequiredChanged() {
                if (root.flow && root.flow.isResponseRequired)
                    Qt.callLater(function() { if (authWindow.visible) secretField.forceActiveFocus(); });
            }
            function onAuthenticationRequestCancelled() { secretField.clear(); }
            function onAuthenticationSucceeded() { secretField.clear(); }
            function onAuthenticationFailed() { secretField.clear(); }
        }
        FocusScope {
            id: keyboard
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.abortRequest()
            Rectangle { anchors.fill: parent; color: Qt.alpha("#07090b", 0.80) }
            Rectangle {
                width: Math.min(486, Math.max(320, parent.width - 46))
                height: cardColumn.implicitHeight + 42
                anchors.centerIn: parent
                color: Theme.background
                radius: Theme.sectionRadius
                border.width: 1
                border.color: Theme.borderaccent
                ColumnLayout {
                    id: cardColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 21
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            width: 42; height: 42; radius: 11
                            color: Qt.alpha(Theme.accent, .15)
                            Text { anchors.centerIn: parent; text: "🔒"; font.pixelSize: 20 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: "System authentication"; color: Theme.foreground; font.pixelSize: 17; font.bold: true }
                            Text { text: "Verified by Polkit / PAM, not RusticQ scripts"; color: Theme.muted; font.pixelSize: 11 }
                        }
                    }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: root.flow ? root.flow.message : "Waiting for a system request"
                        color: Theme.foreground; font.pixelSize: 12
                        textFormat: Text.PlainText
                    }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
                        text: root.flow ? "Action: " + root.flow.actionId : ""
                        color: Theme.muted; font.pixelSize: 10
                        textFormat: Text.PlainText
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        color: Theme.surface; radius: 10
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 10
                            spacing: 4
                            Text { text: root.flow ? (root.flow.inputPrompt || "Authenticate to continue") : "Authenticate to continue"
                                color: Theme.foreground; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            Text { text: root.flow && !root.flow.isResponseRequired ? "Waiting for PAM / fingerprint device…" : "Enter the requested response"
                                color: Theme.muted; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 43
                        visible: root.flow !== null && root.flow.isResponseRequired
                        color: Theme.surface; radius: 9
                        TextInput {
                            id: secretField
                            anchors.fill: parent; anchors.margins: 11
                            color: Theme.foreground
                            font.pixelSize: 13
                            echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                            selectByMouse: false
                            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                            onAccepted: root.sendResponse()
                        }
                    }
                    Text {
                        visible: root.flow !== null && !!root.flow.supplementaryMessage
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: root.flow ? root.flow.supplementaryMessage : ""
                        textFormat: Text.PlainText
                        color: root.flow && root.flow.supplementaryIsError ? Theme.error : Theme.muted
                        font.pixelSize: 11
                    }
                    Text {
                        visible: root.flow !== null && root.flow.failed
                        text: "Authentication failed. Try again."
                        color: Theme.error; font.pixelSize: 11
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 9
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 42
                            radius: 10; color: Theme.surface
                            Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.foreground; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.abortRequest() }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 42
                            radius: 10
                            opacity: root.flow && root.flow.isResponseRequired ? 1 : 0.5
                            color: Theme.accent
                            Text { anchors.centerIn: parent; text: "Authenticate"; color: Theme.background; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                enabled: !!root.flow && root.flow.isResponseRequired
                                onClicked: root.sendResponse() }
                        }
                    }
                }
            }
        }
    }
}
