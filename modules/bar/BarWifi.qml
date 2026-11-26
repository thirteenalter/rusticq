import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "../../config"
import "../../components"
import "../../services"

// Native NetworkManager-backed Wi-Fi card. Delegates access their own
// modelData: a Component declared outside a Loader cannot see that Loader's id.
Rectangle {
    id: wifiWidget
    readonly property var settingsTheme: SettingsMaterial.forItem(wifiWidget)
    Layout.fillWidth: true
    radius: wifiWidget.settingsTheme.glassRadius("card", wifiWidget.settingsTheme.sectionRadius)
    clip: true
    border.width: standalone && wifiWidget.settingsTheme.glassEnabled ? 0 : wifiWidget.settingsTheme.glassBorderWidth("card", 1)
    border.color: wifiWidget.settingsTheme.glassBorder("card", wifiWidget.settingsTheme.borderaccent)
    color: standalone && wifiWidget.settingsTheme.glassEnabled ? "transparent" : wifiWidget.settingsTheme.glassColor("card", Qt.alpha(wifiWidget.settingsTheme.foreground, 0.02))

    property bool expanded: true
    property bool standalone: false
    property bool fullSettings: false
    property bool externalScroll: false
    property bool showAdvancedNavigation: true
    property bool advancedOpen: false
    property bool hiddenOpen: false
    property var popupScreen: null
    signal shareQrRequested(var screen, string ssid)
    readonly property real listHeightLimit: 300
    readonly property bool contentOpen: standalone || expanded
    // Normal and Advanced are separate pages. Only the active page scrolls.
    implicitHeight: standalone || advancedOpen ? wifiContent.implicitHeight + 2 * wifiWidget.settingsTheme.sectionPadding : 0

    WifiManager { id: manager }
    readonly property var availableNetworks: manager.wifiDevice && manager.wifiEnabled && manager.wifiHardwareEnabled
        ? manager.wifiDevice.networks.values : []
    readonly property var connectedNetwork: availableNetworks.find(network => network.connected) || null

    property var activeNetwork: null
    property var passwordNetwork: null
    property string passwordText: ""
    property var errorNetwork: null
    property string errorText: ""
    property string portalError: ""

    function resetState() {
        hiddenOpen = false;
        activeNetwork = null;
        passwordNetwork = null;
        passwordText = "";
        errorNetwork = null;
        errorText = "";
        portalError = "";
    }

    onContentOpenChanged: if (!contentOpen) {
        advancedOpen = false;
        resetState();
        wifiSearch.text = "";
    }
    onVisibleChanged: if (!visible) {
        advancedOpen = false;
        resetState();
        wifiSearch.text = "";
    }

    function showAdvanced() {
        resetState();
        advancedOpen = true;
    }

    function sectionOffset(section) {
        if (section === "dns" || section === "sharing")
            return advancedContent.sectionOffset(section) + advancedContent.mapToItem(wifiWidget, 0, 0).y;
        return 0;
    }

    function showNetworks() {
        resetState();
        advancedOpen = false;
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

    function openPortal() {
        if (!WifiService.portalAvailable) return;
        portalError = WifiService.openPortal() ? ""
            : "Could not open the browser. Open http://neverssl.com/ to sign in to public Wi-Fi.";
    }

    Connections {
        target: WifiService
        function onConnectedNetworkChanged() { wifiWidget.portalError = ""; }
    }

    Connections {
        target: manager
        function onWifiEnabledChanged() {
            if (!manager.wifiEnabled) {
                wifiWidget.resetState();
                wifiSearch.text = "";
            }
        }
        function onWifiHardwareEnabledChanged() {
            if (!manager.wifiHardwareEnabled) {
                wifiWidget.resetState();
                wifiSearch.text = "";
            }
        }
        function onWifiDeviceChanged() {
            wifiWidget.resetState();
            wifiSearch.text = "";
        }
    }

    ColumnLayout {
        id: wifiContent
        anchors.fill: parent
        objectName: "wifiContent"
        anchors.margins: wifiWidget.settingsTheme.panelPadding
        spacing: wifiWidget.settingsTheme.contentGap

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: wifiHeader.implicitHeight
            Layout.maximumHeight: wifiHeader.implicitHeight
            spacing: wifiWidget.settingsTheme.inlineGap
            SectionHeader {
                id: wifiHeader
                Layout.fillWidth: true
                title: wifiWidget.advancedOpen ? "Advanced Wi-Fi" : "Wi-Fi"
                subtitle: !wifiWidget.contentOpen ? "" : !manager.wifiDevice ? "No adapter available" : !manager.wifiHardwareEnabled ? "Hardware disabled"
                    : !manager.wifiEnabled ? "Turn on to discover networks" : wifiWidget.connectedNetwork
                    ? "Connected · " + wifiWidget.connectedNetwork.name : "Choose a network to connect"
                iconName: "\ue63e"
                expanded: wifiWidget.contentOpen
                collapsible: !wifiWidget.standalone
                onToggleRequested: if (!wifiWidget.standalone) wifiWidget.expanded = !wifiWidget.expanded
            }
            Rectangle {
                objectName: "wifiPowerToggle"
                visible: wifiWidget.contentOpen && !wifiWidget.advancedOpen
                Layout.preferredWidth: 40; Layout.preferredHeight: 22
                radius: 11
                color: manager.wifiEnabled ? wifiWidget.settingsTheme.accent : wifiWidget.settingsTheme.surface
                opacity: manager.wifiHardwareEnabled ? 1 : 0.5
                activeFocusOnTab: true
                Accessible.role: Accessible.CheckBox
                Accessible.name: "Enable Wi-Fi"
                Accessible.checkable: true
                Accessible.checked: manager.wifiEnabled
                function toggle() { if (manager.wifiHardwareEnabled && manager.wifiDevice !== null) manager.toggleWifi(); }
                Accessible.onPressAction: toggle()
                Keys.onSpacePressed: toggle()
                Keys.onReturnPressed: toggle()
                border.width: activeFocus ? 1 : 0
                border.color: wifiWidget.settingsTheme.foreground
                Rectangle {
                    width: 18; height: 18; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: manager.wifiEnabled ? parent.width - width - 2 : 2
                    color: wifiWidget.settingsTheme.controlKnob
                    Behavior on x { enabled: wifiWidget.settingsTheme.motionEnabled; NumberAnimation { duration: wifiWidget.settingsTheme.motionFastDuration; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: manager.wifiHardwareEnabled && manager.wifiDevice !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.toggle()
                }
            }
            DeviceSettingsButton {
                objectName: "wifiFullscreenButton"
                visible: !wifiWidget.fullSettings
                kind: "wifi"
                section: "details"
                label: "Open Wi-Fi settings"
                symbol: "\ue8b8"
                iconOnly: true
                fullscreen: false
                targetScreen: wifiWidget.popupScreen || Store.sidebarScreen
            }
        }
        RowLayout {
            visible: wifiWidget.contentOpen && !wifiWidget.advancedOpen
            Layout.fillWidth: true
            spacing: wifiWidget.settingsTheme.inlineGap
            NameSearchField {
                id: wifiSearch
                objectName: "wifiNameSearch"
                Layout.fillWidth: true
                placeholder: "Search Wi-Fi by name"
                autoFocus: wifiWidget.contentOpen && !wifiWidget.advancedOpen
                enabled: manager.wifiEnabled && manager.wifiHardwareEnabled && manager.wifiDevice !== null
                onTextChanged: {
                    wifiWidget.activeNetwork = null;
                    wifiWidget.passwordNetwork = null;
                    wifiWidget.passwordText = "";
                    Qt.callLater(function() { wifiList.positionViewAtBeginning(); });
                }
            }
            ScanButton {
                enabled: manager.wifiEnabled && manager.wifiHardwareEnabled && manager.wifiDevice !== null
                scanning: manager.scanning
                onClicked: manager.toggleScan()
            }
        }

        Flickable {
            id: advancedViewport
            objectName: "wifiAdvancedPage"
            visible: wifiWidget.contentOpen && wifiWidget.advancedOpen
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
            implicitHeight: wifiWidget.standalone && !wifiWidget.fullSettings && !wifiWidget.externalScroll
                ? Math.min(advancedPage.implicitHeight, Math.max(120,
                    (wifiWidget.popupScreen ? wifiWidget.popupScreen.height : 995)
                    - 95 - 2 * wifiWidget.settingsTheme.panelPadding - wifiHeader.implicitHeight - 34 - 2 * wifiContent.spacing))
                : advancedPage.implicitHeight
            contentWidth: width
            contentHeight: advancedPage.implicitHeight
            interactive: !wifiWidget.externalScroll
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: advancedPage
                width: advancedViewport.width
                spacing: wifiWidget.settingsTheme.sectionGap
                Rectangle {
                    objectName: "addHiddenWifiButton"
                    visible: !wifiWidget.hiddenOpen
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: wifiWidget.settingsTheme.glassRadius("card", wifiWidget.settingsTheme.rowRadius)
                    color: wifiWidget.settingsTheme.glassColor("card", Qt.alpha(wifiWidget.settingsTheme.accent, 0.16))
                    enabled: manager.wifiEnabled && manager.wifiHardwareEnabled && manager.wifiDevice !== null
                    opacity: enabled ? 1 : 0.45
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Add hidden Wi-Fi"
                    Accessible.onPressAction: wifiWidget.hiddenOpen = true
                    Keys.onReturnPressed: wifiWidget.hiddenOpen = true
                    Keys.onSpacePressed: wifiWidget.hiddenOpen = true
                    RowLayout { anchors.centerIn: parent; spacing: 7
                        Icon { icon: "\ue145"; color: wifiWidget.settingsTheme.accent; font.pixelSize: Fonts.scale(17) }
                        GlassLabel { text: "Add hidden Wi-Fi"; color: wifiWidget.settingsTheme.accent;
                            font.family: Fonts.poppinsSB.name; font.pixelSize: wifiWidget.settingsTheme.helperTextSize }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiWidget.hiddenOpen = true }
                }
                WifiHiddenNetwork {
                    objectName: "hiddenWifiForm"
                    visible: wifiWidget.hiddenOpen
                    Layout.fillWidth: true
                    onCloseRequested: wifiWidget.hiddenOpen = false
                }
                WifiAdvanced {
                    id: advancedContent
                    visible: !wifiWidget.hiddenOpen
                    Layout.fillWidth: true
                    targetScreen: wifiWidget.popupScreen
                    onShareQrRequested: (screen, ssid) => wifiWidget.shareQrRequested(screen, ssid)
                }
            }
        }

        RowLayout {
            objectName: "wifiNetworkHeading"
            visible: wifiWidget.contentOpen && !wifiWidget.advancedOpen && manager.wifiEnabled && manager.wifiHardwareEnabled && manager.wifiDevice !== null
            Layout.fillWidth: true
            GlassLabel {
                Layout.fillWidth: true
                text: "Networks"
                color: wifiWidget.settingsTheme.contentMuted
                font.family: Fonts.poppinsSB.name
                font.pixelSize: Fonts.scale(10)
            }
            GlassLabel {
                text: manager.scanning ? "Scanning…" : wifiList.count + " available"
                color: wifiWidget.settingsTheme.contentMuted
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(10)
            }
        }
        ListView {
            id: wifiList
            objectName: "wifiNetworkList"
            visible: wifiWidget.contentOpen && !wifiWidget.advancedOpen
            Layout.fillWidth: true
            Layout.fillHeight: !wifiWidget.standalone
            Layout.preferredHeight: wifiWidget.standalone
                                    ? Math.min(wifiWidget.listHeightLimit,
                                        Math.max(96, contentHeight + 4, Math.min(300, count * 68))) : -1
            clip: true
            spacing: wifiWidget.settingsTheme.compactGap
            model: ScriptModel {
                comparisonMode: ObjectComparison.Identity
                values: {
                    const query = wifiSearch.query;
                    return wifiWidget.availableNetworks.filter(network => (network.name || "").toLowerCase().includes(query));
                }
            }
            add: Transition {
                enabled: wifiWidget.settingsTheme.motionEnabled
                NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: wifiWidget.settingsTheme.motionEnterDuration; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                enabled: wifiWidget.settingsTheme.motionEnabled
                NumberAnimation { properties: "opacity"; to: 0; duration: wifiWidget.settingsTheme.motionExitDuration; easing.type: Easing.OutCubic }
            }
            displaced: Transition {
                enabled: wifiWidget.settingsTheme.motionEnabled
                NumberAnimation { properties: "x,y"; duration: wifiWidget.settingsTheme.motionEnterDuration; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: networkItem
                required property var modelData
                readonly property var network: modelData
                readonly property bool expanded: wifiWidget.activeNetwork === network
                readonly property bool needsPassword: wifiWidget.passwordNetwork === network
                readonly property bool processing: manager.processingNetwork === network
                width: wifiList.width
                objectName: "wifiNetworkRow"
                height: rowColumn.implicitHeight + wifiWidget.settingsTheme.inlineGap * 2
                radius: wifiWidget.settingsTheme.glassRadius("card", wifiWidget.settingsTheme.rowRadius)
                color: expanded || activeFocus ? wifiWidget.settingsTheme.glassSelected : mainMouse.containsMouse
                    ? wifiWidget.settingsTheme.glassHover : network && network.connected ? wifiWidget.settingsTheme.glassCard : "transparent"
                border.width: activeFocus ? 1 : 0
                border.color: wifiWidget.settingsTheme.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: network ? network.name + ", " + manager.stateText(network) : "Network"
                function expand() {
                    wifiWidget.activeNetwork = expanded ? null : network;
                    wifiWidget.passwordNetwork = null;
                    wifiWidget.passwordText = "";
                }
                Accessible.onPressAction: expand()
                Keys.onReturnPressed: expand()
                Keys.onSpacePressed: expand()

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
                    anchors.topMargin: wifiWidget.settingsTheme.inlineGap
                    anchors.leftMargin: wifiWidget.settingsTheme.controlPadding
                    anchors.rightMargin: wifiWidget.settingsTheme.controlPadding
                    spacing: wifiWidget.settingsTheme.inlineGap

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        spacing: wifiWidget.settingsTheme.contentGap

                        Icon {
                            Layout.preferredWidth: 24
                            icon: manager.signalIcon(networkItem.network
                                  ? networkItem.network.signalStrength : 0)
                            font.pixelSize: Fonts.scale(20)
                            color: networkItem.network && networkItem.network.connected
                                   ? wifiWidget.settingsTheme.accent : wifiWidget.settingsTheme.foreground
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            GlassLabel {
                                Layout.fillWidth: true
                                text: networkItem.network ? networkItem.network.name : ""
                                color: wifiWidget.settingsTheme.foreground
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(12)
                                elide: Text.ElideRight
                            }
                            GlassLabel {
                                Layout.fillWidth: true
                                text: manager.stateText(networkItem.network)
                                color: networkItem.network && networkItem.network.connected
                                       ? wifiWidget.settingsTheme.accent : wifiWidget.settingsTheme.contentMuted
                                font.family: Fonts.poppins.name
                                font.pixelSize: wifiWidget.settingsTheme.helperTextSize
                                elide: Text.ElideRight
                            }
                        }
                        Icon {
                            visible: networkItem.network && networkItem.network.connected && !networkItem.processing
                            icon: "\ue5ca"
                            color: wifiWidget.settingsTheme.accent
                            font.pixelSize: Fonts.scale(18)
                        }
                        Icon {
                            visible: networkItem.network
                                     && networkItem.network.security !== WifiSecurityType.Open
                            icon: "\ue899" // lock
                            color: wifiWidget.settingsTheme.contentMuted
                        }
                        GlassLabel {
                            visible: networkItem.processing
                            text: "…"
                            font.pixelSize: Fonts.scale(18)
                            color: wifiWidget.settingsTheme.accent
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
                            color: wifiWidget.settingsTheme.accent
                            opacity: networkItem.processing ? 0.5 : 1
                            GlassLabel {
                                id: actionText
                                anchors.centerIn: parent
                                text: networkItem.network && networkItem.network.connected
                                      ? "Disconnect" : "Connect"
                                color: wifiWidget.settingsTheme.background
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
                            color: wifiWidget.settingsTheme.glassColor("card", wifiWidget.settingsTheme.surface)
                            radius: wifiWidget.settingsTheme.glassRadius("card", 8)
                            GlassLabel {
                                id: forgetLabel
                                anchors.centerIn: parent
                                text: "Forget"
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(11)
                                color: wifiWidget.settingsTheme.error
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

                    GlassLabel {
                        visible: wifiWidget.errorNetwork === networkItem.network
                                 && wifiWidget.errorText.length > 0
                        Layout.fillWidth: true
                        text: wifiWidget.errorText
                        wrapMode: Text.WordWrap
                        font.family: Fonts.poppins.name
                        font.pixelSize: Fonts.scale(11)
                        color: wifiWidget.settingsTheme.error
                    }

                    RowLayout {
                        visible: networkItem.needsPassword
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            color: wifiWidget.settingsTheme.glassColor("card", wifiWidget.settingsTheme.background)
                            radius: wifiWidget.settingsTheme.glassRadius("card", 8)
                            border.color: wifiWidget.settingsTheme.glassBorder("card", wifiWidget.settingsTheme.borderaccent)
                            clip: true
                            GlassLabel {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Wi-Fi password"
                                font.family: Fonts.poppins.name
                                font.pixelSize: wifiWidget.settingsTheme.helperTextSize
                                color: wifiWidget.settingsTheme.contentMuted
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
                                color: wifiWidget.settingsTheme.foreground
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
                            color: wifiWidget.settingsTheme.accent
                            GlassLabel {
                                anchors.centerIn: parent
                                text: "OK"
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(11)
                                color: wifiWidget.settingsTheme.background
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
                            color: wifiWidget.settingsTheme.glassColor("card", wifiWidget.settingsTheme.surface)
                            radius: wifiWidget.settingsTheme.glassRadius("card", 8)
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
                    height: 42 + wifiWidget.settingsTheme.inlineGap * 2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: networkItem.expand()
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width
                visible: wifiList.count === 0
                spacing: 8
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "\ue1d8"
                    font.pixelSize: Fonts.scale(25)
                    color: wifiWidget.settingsTheme.contentMuted
                }
                GlassLabel {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: !manager.wifiDevice ? "No Wi-Fi adapter found" :
                          !manager.wifiHardwareEnabled ? "Wi-Fi hardware disabled" :
                          !manager.wifiEnabled ? "Wi-Fi is off" :
                          wifiSearch.query.length > 0 && wifiWidget.availableNetworks.length > 0
                              ? "No matching networks" : "No networks found"
                    color: wifiWidget.settingsTheme.contentMuted
                    font.family: Fonts.poppins.name
                    font.pixelSize: wifiWidget.settingsTheme.controlTextSize
                }
                GlassLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: manager.wifiEnabled && manager.wifiHardwareEnabled && manager.wifiDevice !== null
                    text: wifiSearch.query.length > 0 && wifiWidget.availableNetworks.length > 0
                          ? "Try another name or clear the search" :
                          manager.scanning ? "Scanning for networks…" : "Select Scan to find networks"
                    color: wifiWidget.settingsTheme.contentMuted
                    font.family: Fonts.poppins.name
                    font.pixelSize: wifiWidget.settingsTheme.helperTextSize
                }
            }
        }
        RowLayout {
            visible: wifiWidget.contentOpen && (wifiWidget.showAdvancedNavigation || WifiService.portalAvailable)
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8
            Rectangle {
                objectName: "wifiAdvancedNavigation"
                visible: wifiWidget.showAdvancedNavigation
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: wifiWidget.settingsTheme.glassRadius("card", wifiWidget.settingsTheme.rowRadius)
                color: wifiWidget.settingsTheme.glassColor("card", wifiWidget.settingsTheme.surface)
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: wifiWidget.advancedOpen ? "Back to Wi-Fi" : "Advanced Wi-Fi"
                function navigate() {
                    if (wifiWidget.advancedOpen) wifiWidget.showNetworks();
                    else wifiWidget.showAdvanced();
                }
                Accessible.onPressAction: navigate()
                Keys.onReturnPressed: navigate()
                Keys.onSpacePressed: navigate()
                RowLayout { anchors.centerIn: parent; spacing: 7
                    Icon { icon: wifiWidget.advancedOpen ? "\ue5c4" : "\ue8b8"; color: wifiWidget.settingsTheme.accent; font.pixelSize: Fonts.scale(16) }
                    GlassLabel { text: wifiWidget.advancedOpen ? "Back to Wi-Fi" : "Advanced Wi-Fi";
                        color: wifiWidget.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.navigate() }
            }
            ActionButton {
                objectName: "wifiPortalButton"
                visible: WifiService.portalAvailable
                enabled: WifiService.portalAvailable
                Layout.fillWidth: !wifiWidget.showAdvancedNavigation
                Layout.fillHeight: true
                label: "Login portal"
                symbol: "\ue89e"
                onClicked: wifiWidget.openPortal()
            }
        }
        GlassLabel {
            objectName: "wifiPortalError"
            visible: wifiWidget.contentOpen && WifiService.portalAvailable && wifiWidget.portalError.length > 0
            Layout.fillWidth: true
            text: wifiWidget.portalError
            wrapMode: Text.WordWrap
            color: wifiWidget.settingsTheme.error
            font.family: Fonts.poppins.name
            font.pixelSize: wifiWidget.settingsTheme.helperTextSize
        }

    }
}
