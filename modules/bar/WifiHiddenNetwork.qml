import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: Theme.sectionGap
    property string ssid: ""
    property string password: ""
    property string security: "wpa-psk"
    property string validationMessage: ""
    readonly property bool available: WifiService.wifiDevice !== null && WifiService.enabled
    signal closeRequested()

    function reset() {
        ssid = "";
        password = "";
        security = "wpa-psk";
        validationMessage = "";
    }

    function submit() {
        if (!available || WifiService.hiddenConnecting) return;
        validationMessage = "";
        if (!ssid.length) {
            validationMessage = "Enter the hidden network's exact name (SSID)";
            ssidInput.forceActiveFocus();
            return;
        }
        if (security !== "open" && !password.length) {
            validationMessage = "Enter the Wi-Fi password";
            passwordInput.forceActiveFocus();
            return;
        }
        if (WifiService.connectHidden(ssid, security, password)) password = "";
    }

    onVisibleChanged: {
        reset();
        if (visible) {
            if (!WifiService.hiddenConnecting) WifiService.hiddenMessage = "";
            Qt.callLater(function() { if (root.visible) ssidInput.forceActiveFocus(); });
        }
    }

    Text {
        Layout.fillWidth: true
        text: "Hidden network · enter the exact SSID"
        color: Theme.muted
        wrapMode: Text.WordWrap
        font.family: Fonts.poppins.name
        font.pixelSize: Theme.helperTextSize
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: Theme.rowRadius
        color: Theme.surface
        clip: true
        TextInput {
            id: ssidInput
            objectName: "hiddenSsidInput"
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            text: root.ssid
            enabled: root.available && !WifiService.hiddenConnecting
            color: Theme.foreground
            font.family: Fonts.poppins.name
            font.pixelSize: Theme.controlTextSize
            activeFocusOnTab: true
            Accessible.name: "Hidden Wi-Fi network name"
            onTextEdited: root.ssid = text
            onAccepted: root.submit()
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: !ssidInput.text.length
            text: "Network name (SSID)"
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: Theme.helperTextSize
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [{key: "wpa-psk", label: "WPA/WPA2"},
                    {key: "sae", label: "WPA3"}, {key: "open", label: "Open"}]
            delegate: Rectangle {
                id: securityOption
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: Theme.rowRadius
                color: root.security === modelData.key ? Qt.alpha(Theme.accent, 0.18) : Theme.surface
                enabled: !WifiService.hiddenConnecting
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.label
                Accessible.checked: root.security === modelData.key
                function select() {
                    root.security = modelData.key;
                    root.password = "";
                    root.validationMessage = "";
                }
                Accessible.onPressAction: select()
                Keys.onSpacePressed: select()
                Keys.onReturnPressed: select()
                Text {
                    anchors.centerIn: parent
                    text: securityOption.modelData.label
                    color: root.security === securityOption.modelData.key ? Theme.accent : Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Theme.helperTextSize
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: securityOption.select()
                }
            }
        }
    }
    Rectangle {
        visible: root.security !== "open"
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: Theme.rowRadius
        color: Theme.surface
        clip: true
        TextInput {
            id: passwordInput
            objectName: "hiddenPasswordInput"
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            text: root.password
            echoMode: TextInput.Password
            enabled: root.available && !WifiService.hiddenConnecting
            color: Theme.foreground
            font.family: Fonts.poppins.name
            font.pixelSize: Theme.controlTextSize
            activeFocusOnTab: true
            Accessible.name: "Hidden Wi-Fi password"
            onTextEdited: root.password = text
            onAccepted: root.submit()
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: !passwordInput.text.length
            text: "Wi-Fi password"
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: Theme.helperTextSize
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: Theme.rowRadius
            color: Theme.surface
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Back to Wi-Fi networks"
            Accessible.onPressAction: root.closeRequested()
            Keys.onReturnPressed: root.closeRequested()
            Keys.onSpacePressed: root.closeRequested()
            Text {
                anchors.centerIn: parent
                text: "Back"
                color: Theme.foreground
                font.family: Fonts.poppins.name
                font.pixelSize: Theme.helperTextSize
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() }
        }
        Rectangle {
            objectName: "hiddenConnectButton"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: Theme.rowRadius
            color: Theme.accent
            enabled: root.available && !WifiService.hiddenConnecting
            opacity: enabled ? 1 : 0.5
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Connect to hidden Wi-Fi"
            Accessible.onPressAction: root.submit()
            Keys.onReturnPressed: root.submit()
            Keys.onSpacePressed: root.submit()
            Text {
                anchors.centerIn: parent
                text: WifiService.hiddenConnecting ? "Connecting…" : "Connect"
                color: Theme.background
                font.family: Fonts.poppinsSB.name
                font.pixelSize: Theme.helperTextSize
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: text.length > 0
        text: root.validationMessage || (!root.available ? "Enable an available Wi-Fi adapter first"
              : WifiService.hiddenConnecting ? "Connecting to hidden Wi-Fi…" : WifiService.hiddenMessage)
        color: root.validationMessage || !root.available || WifiService.hiddenFailed ? Theme.error : Theme.muted
        wrapMode: Text.WordWrap
        font.family: Fonts.poppins.name
        font.pixelSize: Theme.helperTextSize
    }
}
