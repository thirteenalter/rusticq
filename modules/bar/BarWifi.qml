import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../../config"
import "../../components"
import "../../services"

// Native NetworkManager-backed Wi-Fi card. Delegates access their own
// modelData: a Component declared outside a Loader cannot see that Loader's id.
Rectangle {
    id: wifiWidget
    Layout.fillWidth: true
    radius: Theme.sectionRadius
    clip: true
    border.width: 1
    border.color: Theme.borderaccent
    color: Qt.alpha(Theme.foreground, 0.02)

    property bool expanded: true
    property bool standalone: false
    readonly property bool contentOpen: standalone || expanded

    WifiManager { id: manager }

    property var activeNetwork: null
    property var passwordNetwork: null
    property string passwordText: ""
    property var errorNetwork: null
    property string errorText: ""

    function resetState() {
        activeNetwork = null;
        passwordNetwork = null;
        passwordText = "";
        errorNetwork = null;
        errorText = "";
    }

    function connectSelected(network) {
        if (!network) return;
        errorNetwork = null;
        errorText = "";
        if (network.connected) {
            manager.disconnectNetwork(network);
            activeNetwork = null;
        } else if (!network.known && network.security === WifiSecurityType.Unknown) {
            // Work around Quickshell 0.3.1: open Wi-Fi networks may be
            // incorrectly classified as Unknown (fixed upstream in 0.3.2).
            // Try the normal NetworkManager connection without inventing a PSK.
            // If secrets really are required, connectionFailed will report it.
            manager.connectNetwork(network);
        } else if (!network.known && network.security !== WifiSecurityType.Open) {
            if (network.security !== WifiSecurityType.WpaPsk
                && network.security !== WifiSecurityType.Wpa2Psk
                && network.security !== WifiSecurityType.Sae) {
                errorNetwork = network;
                errorText = "This security type needs NetworkManager settings";
            } else {
                passwordNetwork = network;
                passwordText = "";
                activeNetwork = network;
            }
        } else {
            manager.connectNetwork(network);
        }
    }

    function submitPassword(network) {
        if (!network || !passwordText.length) return;
        manager.connectWithPassword(network, passwordText);
        passwordText = "";
        passwordNetwork = null;
    }

    Connections {
        target: manager
        function onWifiEnabledChanged() {
            if (!manager.wifiEnabled) wifiWidget.resetState();
        }
        function onWifiDeviceChanged() {
            wifiWidget.resetState();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: 12

        SectionHeader {
            Layout.fillWidth: true
            title: "Wi-Fi"
            iconName: "\ue63e"
            expanded: wifiWidget.contentOpen
            collapsible: !wifiWidget.standalone
            onToggleRequested: if (!wifiWidget.standalone) wifiWidget.expanded = !wifiWidget.expanded
        }
        RowLayout {
            visible: wifiWidget.contentOpen
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8
            Text {
                text: manager.wifiEnabled ? "Wi-Fi enabled" : "Wi-Fi disabled"
                Layout.fillWidth: true
                font.family: Fonts.poppins.name
                font.pixelSize: Theme.controlTextSize
                color: Theme.muted
            }
            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 22
                radius: 11
                color: manager.wifiEnabled ? Theme.accent : Theme.surface
                opacity: manager.wifiHardwareEnabled ? 1 : 0.5
                Rectangle {
                    width: 18; height: 18; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: manager.wifiEnabled ? parent.width - width - 2 : 2
                    color: Theme.foreground
                    Behavior on x { NumberAnimation { duration: 140 } }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: manager.wifiHardwareEnabled && manager.wifiDevice !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: manager.toggleWifi()
                }
            }
        }
        RowLayout {
            visible: wifiWidget.contentOpen
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Networks"
                color: Theme.foreground
                font.family: Fonts.poppinsSB.name
                font.pixelSize: Theme.controlTextSize
            }
            ScanButton {
                enabled: manager.wifiEnabled && manager.wifiHardwareEnabled && manager.wifiDevice !== null
                scanning: manager.scanning
                onClicked: manager.toggleScan()
            }
        }

        ListView {
            id: wifiList
            visible: wifiWidget.contentOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: manager.wifiDevice ? manager.wifiDevice.networks : null

            delegate: Rectangle {
                id: networkItem
                required property var modelData
                readonly property var network: modelData
                readonly property bool expanded: wifiWidget.activeNetwork === network
                readonly property bool needsPassword: wifiWidget.passwordNetwork === network
                readonly property bool processing: manager.processingNetwork === network
                width: wifiList.width
                height: rowColumn.implicitHeight + 14
                radius: Theme.rowRadius
                color: expanded ? Qt.alpha(Theme.accent, 0.12) : mainMouse.containsMouse
                       ? Qt.alpha(Theme.foreground, 0.09) : Theme.surface

                Connections {
                    target: networkItem.network
                    function onConnectionFailed(reason) {
                        manager.clearProcessing(networkItem.network);
                        wifiWidget.activeNetwork = networkItem.network;
                        wifiWidget.errorNetwork = networkItem.network;
                        wifiWidget.errorText = manager.failReasonText(reason);
                        // Let user re-enter the password after bad credentials.
                        if (reason === ConnectionFailReason.NoSecrets) {
                            const sec = networkItem.network.security;
                            if (sec === WifiSecurityType.WpaPsk
                                || sec === WifiSecurityType.Wpa2Psk
                                || sec === WifiSecurityType.Sae) {
                                wifiWidget.passwordNetwork = networkItem.network;
                            } else {
                                // connectWithPsk is only valid for WPA/SAE.
                                // Unknown is not enough evidence to request a PSK.
                                wifiWidget.passwordNetwork = null;
                                wifiWidget.errorText = "Configure this network in NetworkManager";
                            }
                        }
                    }
                    function onConnectedChanged() {
                        if (networkItem.network) {
                            manager.clearProcessing(networkItem.network);
                            if (wifiWidget.passwordNetwork === networkItem.network)
                                wifiWidget.passwordNetwork = null;
                            if (wifiWidget.errorNetwork === networkItem.network)
                                wifiWidget.errorNetwork = null;
                        }
                    }
                }

                ColumnLayout {
                    id: rowColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        spacing: 10

                        Icon {
                            Layout.preferredWidth: 24
                            icon: manager.signalIcon(networkItem.network
                                  ? networkItem.network.signalStrength : 0)
                            font.pixelSize: Fonts.scale(20)
                            color: networkItem.network && networkItem.network.connected
                                   ? Theme.accent : Theme.foreground
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: networkItem.network ? networkItem.network.name : ""
                                color: Theme.foreground
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(13)
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: manager.stateText(networkItem.network)
                                color: networkItem.network && networkItem.network.connected
                                       ? Theme.accent : Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: Theme.helperTextSize
                                elide: Text.ElideRight
                            }
                        }
                        Icon {
                            visible: networkItem.network
                                     && networkItem.network.security !== WifiSecurityType.Open
                            icon: "\ue899" // lock
                            color: Theme.muted
                        }
                        Text {
                            visible: networkItem.processing
                            text: "…"
                            font.pixelSize: Fonts.scale(18)
                            color: Theme.accent
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: networkItem.expanded
                        spacing: 10

                        Rectangle {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: actionText.implicitWidth + 22
                            radius: 8
                            color: Theme.accent
                            opacity: networkItem.processing ? 0.5 : 1
                            Text {
                                id: actionText
                                anchors.centerIn: parent
                                text: networkItem.network && networkItem.network.connected
                                      ? "Disconnect" : "Connect"
                                color: Theme.background
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(11)
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !networkItem.processing
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiWidget.connectSelected(networkItem.network)
                            }
                        }

                        Rectangle {
                            visible: networkItem.network ? networkItem.network.known : false
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: forgetLabel.implicitWidth + 20
                            color: Theme.surface
                            radius: 8
                            Text {
                                id: forgetLabel
                                anchors.centerIn: parent
                                text: "Forget"
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(11)
                                color: Theme.error
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !networkItem.processing
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    manager.forgetNetwork(networkItem.network);
                                    wifiWidget.resetState();
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        visible: wifiWidget.errorNetwork === networkItem.network
                                 && wifiWidget.errorText.length > 0
                        Layout.fillWidth: true
                        text: wifiWidget.errorText
                        wrapMode: Text.WordWrap
                        font.family: Fonts.poppins.name
                        font.pixelSize: Fonts.scale(11)
                        color: Theme.error
                    }

                    RowLayout {
                        visible: networkItem.needsPassword
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            color: Theme.background
                            radius: 8
                            border.color: Theme.borderaccent
                            clip: true
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Wi-Fi password"
                                font.family: Fonts.poppins.name
                                font.pixelSize: Theme.helperTextSize
                                color: Theme.muted
                                visible: passwordInput.text.length === 0
                            }
                            TextInput {
                                id: passwordInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                text: wifiWidget.passwordText
                                echoMode: TextInput.Password
                                focus: networkItem.needsPassword
                                color: Theme.foreground
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(12)
                                onTextEdited: wifiWidget.passwordText = text
                                Keys.onReturnPressed: wifiWidget.submitPassword(networkItem.network)
                                Keys.onEnterPressed: wifiWidget.submitPassword(networkItem.network)
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 35
                            Layout.preferredHeight: 32
                            radius: 8
                            color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: "OK"
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(11)
                                color: Theme.background
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiWidget.submitPassword(networkItem.network)
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 32
                            color: Theme.surface
                            radius: 8
                            Icon { anchors.centerIn: parent; icon: "\ue5cd" }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wifiWidget.passwordNetwork = null;
                                    wifiWidget.passwordText = "";
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: mainMouse
                    x: 0
                    y: 0
                    width: parent.width
                    height: 52
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        wifiWidget.activeNetwork = networkItem.expanded ? null : networkItem.network;
                        wifiWidget.passwordNetwork = null;
                        wifiWidget.passwordText = "";
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: wifiList.count === 0
                spacing: 8
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "\ue1d8"
                    font.pixelSize: Fonts.scale(25)
                    color: Theme.muted
                }
                Text {
                    text: !manager.wifiDevice ? "No Wi-Fi adapter found" :
                          !manager.wifiHardwareEnabled ? "Wi-Fi hardware disabled" :
                          !manager.wifiEnabled ? "Wi-Fi is off" : "No networks found"
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Theme.controlTextSize
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: manager.wifiEnabled && manager.wifiDevice !== null
                    text: manager.scanning ? "Scanning for networks…" : "Select Scan to find networks"
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Theme.helperTextSize
                }
            }
        }
    }
}
