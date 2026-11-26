import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Networking
import "../modules/bar"
import "../components"
import "../services"
import "../config"
import "../modules/settings"
import "../modules/main"

Item {
    width: 780
    height: 900
    BarWifi {
        id: wifiCard
        width: 368
        height: implicitHeight
        standalone: true
        popupScreen: ({height: 720})
    }
    ApplicationAudioMixer { id: mixer; x: 390; width: 350 }
    SettingsWindow { id: settings }
    DeviceSettingsWindow { id: devices }
    MiniAudio { id: compactAudio; x: 390; y: 450; width: 350; height: implicitHeight }
    BarBluetooth { id: bluetoothCard; visible: false; x: 390; y: 450; width: 368; height: 336; standalone: true }
    SignalSpy { id: deviceRequests; target: Store; signalName: "deviceSettingsRequested" }
    QtObject {
        id: officeNetwork
        property string name: "Office Wi-Fi"
        property bool connected: false
        property bool known: true
        property int security: WifiSecurityType.Wpa2Psk
        property int state: 0
        property real signalStrength: 0.8
        property int connectCalls: 0
        signal connectionFailed(int reason)
        function connect() { connectCalls++; }
    }
    QtObject {
        id: guestNetwork
        property string name: "Guest lounge"
        property bool connected: false
        property bool known: false
        property int security: WifiSecurityType.Open
        property int state: 0
        property real signalStrength: 0.6
        signal connectionFailed(int reason)
    }
    QtObject {
        id: headphones
        property string name: "Studio Headphones"
        property string address: "11:22:33:44:55:66"
        property bool connected: false
        property bool paired: false
        property bool pairing: false
        property bool batteryAvailable: false
        property real battery: 0
        property int pairCalls: 0
        function pair() { pairCalls++; }
    }
    QtObject {
        id: keyboard
        property string name: "Desk Keyboard"
        property string address: "AA:BB:CC:DD:EE:FF"
        property bool connected: false
        property bool paired: true
        property bool pairing: false
        property bool batteryAvailable: false
        property real battery: 0
    }
    QtObject {
        id: playback
        property var audio: QtObject { property real volume: 0.4; property bool muted: false; property var channels: [1, 2] }
        property bool ready: true
        property bool isStream: true
        property bool isSink: true
        property string description: "Browser audio"
        property string nickname: ""
        property string name: "browser-stream"
        property var properties: ({"application.name": "Firefox", "media.name": "Example video"})
    }
    QtObject {
        id: microphone
        property var audio: QtObject { property real volume: 0.7; property bool muted: false }
        property bool isStream: true
        property bool isSink: false
    }
    QtObject {
        id: speaker
        property var audio: QtObject { property real volume: 0.6; property bool muted: false }
        property bool isStream: false
        property bool isSink: true
    }
    TestCase {
        name: "WifiAudioInteraction"
        when: true
        function cleanupTestCase() {
            console.log("WIFI AUDIO RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed");
        }
        function cleanup() {
            console.log("WIFI AUDIO TEST " + qtest_results.functionName + " failed=" + qtest_results.failed);
            Store.settingsVisible = false;
            Store.closeDeviceSettings();
        }
        function childrenOf(item) {
            let found = [item];
            for (const child of item.children) found = found.concat(childrenOf(child));
            return found;
        }
        function named(name) {
            return childrenOf(wifiCard).find(item => item.objectName === name);
        }
        function saveSettingsPreview(name) {
            const folder = Quickshell.env("RUSTICQ_UI_CAPTURE_DIR");
            if (folder && folder.length) grabImage(settings.contentItem).save(folder + "/" + name + ".png");
        }
        function init() {
            wifiCard.visible = false;
            wifiCard.standalone = true;
            wifiCard.expanded = true;
            wifiCard.height = Qt.binding(() => wifiCard.implicitHeight);
            bluetoothCard.standalone = true;
            bluetoothCard.expanded = false;
            Store.closeDeviceSettings();
            deviceRequests.clear();
            wifiCard.popupScreen = ({height: 720});
            wifiCard.showNetworks();
            WifiService.hiddenConnecting = false;
            WifiService.hiddenMessage = "";
            WifiService.hiddenFailed = false;
            WifiService.enabled = true;
            WifiService.wifiDevice = {name: "wlan0"};
            WifiService.connectedNetwork = null;
            WifiService.portalDetected = false;
            WifiService.portalCalls = 0;
            WifiService.portalLaunchSucceeds = true;
            wifiCard.showAdvancedNavigation = true;
            WifiService.calls = 0;
            Fixtures.WifiFixture.device = Fixtures.WifiFixture.adapter;
            Fixtures.WifiFixture.adapter.networks.values = [];
            Fixtures.Bluetooth.defaultAdapter = Fixtures.Bluetooth.adapter;
            Fixtures.Bluetooth.adapter.enabled = true;
            Fixtures.Bluetooth.adapter.devices.values = [];
            bluetoothCard.visible = false;
            compactAudio.visible = true;
            officeNetwork.connectCalls = 0;
            officeNetwork.connected = false;
            SettingsStore.uiDensity = "comfortable";
            guestNetwork.name = "Guest lounge";
            headphones.pairCalls = 0;
            keyboard.name = "Desk Keyboard";
            Pipewire.nodes.values = [];
            mixer.visible = true;
            playback.audio.volume = 0.4;
            playback.audio.muted = false;
            playback.audio.channels = [1, 2];
            playback.properties = {"application.name": "Firefox", "media.name": "Example video"};
            wifiCard.visible = true;
            wifiCard.Window.window.requestActivate();
            wait(40);
        }
        function test_advanced_is_separate_and_back_restores_networks() {
            const navigation = named("wifiAdvancedNavigation");
            const add = named("addHiddenWifiButton");
            const list = named("wifiNetworkList");
            const page = named("wifiAdvancedPage");
            verify(list.visible);
            verify(!add.visible);
            mouseClick(navigation);
            tryCompare(wifiCard, "advancedOpen", true);
            wait(50);
            verify(!list.visible);
            verify(page.visible);
            verify(add.visible);
            verify(wifiCard.height <= 625);
            mouseClick(add);
            tryCompare(wifiCard, "hiddenOpen", true);
            wait(50);
            verify(named("hiddenWifiForm").visible);
            mouseClick(navigation);
            tryCompare(wifiCard, "advancedOpen", false);
            verify(list.visible);
            verify(!page.visible);
            verify(!add.visible);
            verify(!wifiCard.hiddenOpen);
        }
        function test_wifi_name_search_live_results_clear_and_connect() {
            const search = named("wifiNameSearch");
            const list = named("wifiNetworkList");
            Fixtures.WifiFixture.adapter.networks.values = [officeNetwork, guestNetwork];
            tryCompare(list, "count", 2);
            const input = childrenOf(search).find(item => item.objectName === "nameSearchInput");
            tryCompare(input, "activeFocus", true);
            input.insert(0, "  oFFICE  ");
            tryCompare(list, "count", 1);
            tryVerify(() => list.itemAtIndex(0) !== null);
            const row = list.itemAtIndex(0);
            compare(row.network, officeNetwork);
            guestNetwork.name = "Office guest";
            tryCompare(list, "count", 2);
            compare(list.itemAtIndex(0), row);
            guestNetwork.name = "Guest lounge";
            tryCompare(list, "count", 1);
            wifiCard.connectSelected(list.itemAtIndex(0).network);
            compare(officeNetwork.connectCalls, 1);
            search.text = "no-such-network";
            tryCompare(list, "count", 0);
            tryVerify(() => childrenOf(wifiCard).some(item => item.visible && item.text === "No matching networks"));
            waitForRendering(wifiCard);
            mouseClick(childrenOf(search).find(item => item.objectName === "clearNameSearch"));
            compare(search.text, "");
            compare(input.activeFocus, true);
            tryCompare(list, "count", 2);
            search.text = "guest";
            Fixtures.WifiFixture.adapter.networks.values = [officeNetwork];
            tryCompare(list, "count", 0);
            Fixtures.WifiFixture.device = null;
            tryCompare(search, "enabled", false);
            compare(search.text, "");
        }
        function test_wifi_surface_insets_connected_state_and_row_actions() {
            Fixtures.WifiFixture.adapter.networks.values = [officeNetwork, guestNetwork];
            officeNetwork.connected = true;
            const list=named("wifiNetworkList"),content=named("wifiContent"),search=named("wifiNameSearch");
            tryCompare(list,"count",2);
            for(const density of ["comfortable","compact"]){
                SettingsStore.uiDensity=density;wait(30);
                fuzzyCompare(content.x,Theme.panelPadding,.75);
                fuzzyCompare(content.width,wifiCard.width-2*Theme.panelPadding,.75);
                fuzzyCompare(search.mapToItem(wifiCard,0,0).x,Theme.panelPadding,.75);
                fuzzyCompare(list.mapToItem(wifiCard,0,0).x,Theme.panelPadding,.75);
                const row=list.itemAtIndex(0);verify(row!==null);
                verify(row.height>=54);verify(row.color.a>0);
                mouseClick(row,20,25);wait(30);compare(wifiCard.activeNetwork,officeNetwork);
                const actions=childrenOf(row).filter(item=>item.text==="Disconnect" && item.visible);
                compare(actions.length,1);verify(row.height>70);
                mouseClick(row,20,25);wait(30);compare(wifiCard.activeNetwork,null);
            }
            officeNetwork.connected=false;SettingsStore.uiDensity="comfortable";
        }
        function test_search_focus_on_expanded_quick_cards() {
            const wifiSearch = named("wifiNameSearch");
            wifiCard.standalone = false;
            wifiCard.height = 350;
            wifiCard.expanded = false;
            verify(!wifiSearch.visible);
            wifiCard.expanded = true;
            tryCompare(findChild(wifiSearch, "nameSearchInput"), "activeFocus", true);
            wifiCard.expanded = false;
            verify(!wifiSearch.visible);
            bluetoothCard.standalone = false;
            bluetoothCard.expanded = false;
            bluetoothCard.visible = true;
            const btSearch = findChild(bluetoothCard, "bluetoothNameSearch");
            verify(!btSearch.visible);
            bluetoothCard.expanded = true;
            tryCompare(findChild(btSearch, "nameSearchInput"), "activeFocus", true);
            bluetoothCard.expanded = false;
            verify(!btSearch.visible);
            wait(20);
            compare(findChild(btSearch, "nameSearchInput").activeFocus, false);
        }
        function test_name_search_focus_reopen_advanced_and_no_focus_theft() {
            const wifiSearch = named("wifiNameSearch");
            const wifiInput = childrenOf(wifiSearch).find(item => item.objectName === "nameSearchInput");
            tryCompare(wifiInput, "activeFocus", true);
            keyClick(Qt.Key_G);
            compare(wifiSearch.text, "g");
            keyClick(Qt.Key_Escape);
            compare(wifiSearch.text, "");
            compare(wifiInput.activeFocus, true);
            wifiCard.showAdvanced();
            verify(!wifiSearch.visible);
            wifiCard.showNetworks();
            tryCompare(wifiInput, "activeFocus", true);
            const other = childrenOf(compactAudio).find(item => item.objectName === "audioFullscreenButton");
            other.forceActiveFocus();
            tryCompare(other, "activeFocus", true);
            Fixtures.WifiFixture.adapter.networks.values = [officeNetwork, guestNetwork];
            wait(40);
            compare(other.activeFocus, true);
            // Clicking the field's icon/padding forwards focus to the input.
            mouseClick(wifiSearch, 4, wifiSearch.height / 2);
            tryCompare(wifiInput, "activeFocus", true);
            wifiCard.visible = false;
            wifiCard.visible = true;
            wait(20);
            tryCompare(wifiInput, "activeFocus", true);
            bluetoothCard.visible = true;
            const btSearch = childrenOf(bluetoothCard).find(item => item.objectName === "bluetoothNameSearch");
            const btInput = childrenOf(btSearch).find(item => item.objectName === "nameSearchInput");
            tryCompare(btInput, "activeFocus", true);
            keyClick(Qt.Key_H);
            compare(btSearch.text, "h");
            bluetoothCard.visible = false;
            bluetoothCard.visible = true;
            tryCompare(btInput, "activeFocus", true);
            compare(btSearch.text, "");
            Fixtures.Bluetooth.adapter.enabled = false;
            verify(!btSearch.enabled);
            Fixtures.Bluetooth.adapter.enabled = true;
            tryCompare(btInput, "activeFocus", true);
        }
        function test_bluetooth_name_search_live_results_clear_and_pair() {
            compactAudio.visible = false;
            bluetoothCard.visible = true;
            Fixtures.Bluetooth.adapter.devices.values = [headphones, keyboard];
            const search = childrenOf(bluetoothCard).find(item => item.objectName === "bluetoothNameSearch");
            const list = childrenOf(bluetoothCard).find(item => item.objectName === "bluetoothDeviceList");
            tryCompare(list, "count", 2);
            const input = childrenOf(search).find(item => item.objectName === "nameSearchInput");
            tryCompare(input, "activeFocus", true);
            input.insert(0, "  HEAD  ");
            tryCompare(list, "count", 1);
            const row = list.itemAt(0);
            compare(row.device, headphones);
            keyboard.name = "Head keyboard";
            tryCompare(list, "count", 2);
            compare(list.itemAt(0), row);
            const pair = childrenOf(row).find(item => item.cursorShape === Qt.PointingHandCursor);
            waitForRendering(bluetoothCard);
            mouseClick(pair);
            compare(headphones.pairCalls, 1);
            search.text = "no-such-device";
            tryCompare(list, "count", 0);
            tryVerify(() => childrenOf(bluetoothCard).some(item => item.visible && item.text
                && item.text.startsWith("No matching devices")));
            waitForRendering(bluetoothCard);
            mouseClick(childrenOf(search).find(item => item.objectName === "clearNameSearch"));
            tryCompare(list, "count", 2);
            compare(search.text, "");
            compare(input.activeFocus, true);
            search.text = "head";
            Fixtures.Bluetooth.adapter.enabled = false;
            tryCompare(list, "count", 0);
            compare(search.text, "");
            compare(search.enabled, false);
            Fixtures.Bluetooth.defaultAdapter = null;
            compare(search.enabled, false);
        }
        function test_hidden_validation_submit_and_clear_on_back() {
            wifiCard.showAdvanced();
            wifiCard.hiddenOpen = true;
            wait(30);
            const form = named("hiddenWifiForm");
            form.submit();
            compare(WifiService.calls, 0);
            verify(form.validationMessage.length > 0);
            form.ssid = " Exact hidden SSID ";
            form.password = "private-test-password";
            form.submit();
            compare(WifiService.calls, 1);
            compare(WifiService.requestedSsid, " Exact hidden SSID ");
            compare(WifiService.requestedSecurity, "wpa-psk");
            compare(form.password, "");
            form.submit();
            compare(WifiService.calls, 1);
            wifiCard.showNetworks();
            compare(form.ssid, "");
            compare(form.password, "");
        }
        function test_open_network_and_unavailable_adapter() {
            wifiCard.showAdvanced();
            wifiCard.hiddenOpen = true;
            wait(30);
            const form = named("hiddenWifiForm");
            form.ssid = "Open hidden";
            form.security = "open";
            form.submit();
            compare(WifiService.calls, 1);
            compare(WifiService.requestedSecurity, "open");
            WifiService.hiddenConnecting = false;
            WifiService.enabled = false;
            form.submit();
            compare(WifiService.calls, 1);
            compare(named("hiddenConnectButton").enabled, false);
        }
        function test_portal_reopen_and_adapter_removal() {
            const button = named("wifiPortalButton");
            verify(!button.visible);
            wifiCard.openPortal();
            compare(WifiService.portalCalls, 0);
            for (const security of [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk,
                                    WifiSecurityType.Sae, WifiSecurityType.Unknown]) {
                WifiService.connectedNetwork = {name: "Private Wi-Fi", security: security};
                verify(!button.visible);
                wifiCard.openPortal();
            }
            compare(WifiService.portalCalls, 0);
            for (const security of [WifiSecurityType.Open, WifiSecurityType.Wpa2Psk, WifiSecurityType.Unknown]) {
                WifiService.portalDetected = security !== WifiSecurityType.Open;
                WifiService.connectedNetwork = {name: "Public hotspot", security: security};
                tryCompare(button, "visible", true);
                mouseClick(button);
            }
            compare(WifiService.portalCalls, 3);
            wifiCard.showAdvanced();
            verify(button.visible);
            waitForRendering(wifiCard);
            wifiCard.Window.window.requestActivate();
            button.forceActiveFocus();
            tryCompare(button, "activeFocus", true);
            keyClick(Qt.Key_Space);
            compare(WifiService.portalCalls, 4);
            verify(button.x + button.width <= wifiCard.width);
            verify(named("wifiAdvancedNavigation").width > 120);
            const folder = Quickshell.env("RUSTICQ_UI_CAPTURE_DIR");
            if (folder && folder.length) grabImage(wifiCard).save(folder + "/wifi-portal.png");
            WifiService.enabled = false;
            tryCompare(button, "visible", false);
            WifiService.enabled = true;
            tryCompare(button, "visible", true);
            WifiService.wifiDevice = null;
            tryCompare(button, "visible", false);
            wifiCard.openPortal();
            compare(WifiService.portalCalls, 4);
        }
        function test_portal_browser_error_retry_and_navigation() {
            WifiService.connectedNetwork = {name: "Public hotspot", security: WifiSecurityType.Open};
            const button = named("wifiPortalButton");
            const error = named("wifiPortalError");
            tryCompare(button, "visible", true);
            WifiService.portalLaunchSucceeds = false;
            mouseClick(button);
            tryCompare(error, "visible", true);
            verify(error.text.includes("http://neverssl.com/"));
            WifiService.portalLaunchSucceeds = true;
            mouseClick(button);
            tryCompare(error, "visible", false);
            compare(WifiService.portalCalls, 2);
            // The device window hides Advanced navigation; portal stays usable.
            wifiCard.showAdvancedNavigation = false;
            verify(button.visible);
            mouseClick(button);
            compare(WifiService.portalCalls, 3);
            WifiService.portalLaunchSucceeds = false;
            mouseClick(button);
            verify(error.visible);
            WifiService.connectedNetwork = null;
            tryCompare(button, "visible", false);
            compare(wifiCard.portalError, "");
            wifiCard.openPortal();
            compare(WifiService.portalCalls, 4);
        }
        function test_audio_playback_filter_names_volume_and_mute() {
            Pipewire.nodes.values = [speaker, microphone, playback];
            tryCompare(mixer, "playbackStreams", [playback]);
            const repeater = childrenOf(mixer).find(item => item.objectName === "applicationAudioStreams");
            tryCompare(repeater, "count", 1);
            wait(50);
            const app = repeater.itemAt(0);
            compare(app.appName, "Firefox");
            compare(app.mediaName, "Example video");
            verify(childrenOf(app).some(item => item.objectName === "applicationAudioMeter"));
            compare(app.level, 0.5);
            const slider = childrenOf(app).find(item => item.adjustable !== undefined);
            slider.userChanged(0.65);
            compare(playback.audio.volume, 0.65);
            compare(speaker.audio.volume, 0.6);
            const mute = childrenOf(app).find(item => typeof item.toggleMute === "function");
            mouseClick(mute);
            compare(playback.audio.muted, true);
            compare(app.level, 0);
            compare(speaker.audio.muted, false);
            playback.properties = {};
            compare(app.appName, "Browser audio");
            Pipewire.nodes.values = [speaker, microphone];
            tryCompare(repeater, "count", 0);
        }
        function test_hidden_mixer_releases_stream_delegates() {
            Pipewire.nodes.values = [playback];
            const repeater = childrenOf(mixer).find(item => item.objectName === "applicationAudioStreams");
            tryCompare(repeater, "count", 1);
            mixer.visible = false;
            tryCompare(repeater, "count", 0);
            mixer.visible = true;
            tryCompare(repeater, "count", 1);
        }
        function test_unknown_channels_use_compatible_meter() {
            playback.audio.channels = [0, 0];
            Pipewire.nodes.values = [playback];
            const repeater = childrenOf(mixer).find(item => item.objectName === "applicationAudioStreams");
            tryCompare(repeater, "count", 1);
            const app = repeater.itemAt(0);
            compare(app.nativeChannelsKnown, false);
            tryCompare(app, "level", 0.25);
            mixer.visible = false;
            tryCompare(repeater, "count", 0);
        }
        function deviceNamed(name) {
            return childrenOf(devices.contentItem).find(item => item.objectName === name);
        }
        function saveDevicePreview(name) {
            const folder = Quickshell.env("RUSTICQ_UI_CAPTURE_DIR");
            if (folder && folder.length) grabImage(devices.contentItem).save(folder + "/" + name + ".png");
        }
        function test_wifi_compact_window_and_feature_buttons() {
            wifiCard.popupScreen = null;
            Store.sidebarVisible = true;
            mouseClick(named("wifiFullscreenButton"));
            compare(Store.deviceSettingsPending, true);
            compare(Store.deviceSettingsVisible, false);
            compare(Store.sidebarVisible, false);
            compare(deviceRequests.count, 1);
            tryCompare(Store, "deviceSettingsVisible", true);
            tryCompare(devices, "fullscreen", false);
            verify(devices.height <= 620);
            verify(devices.maximumSize.height <= 620);
            compare(deviceNamed("toggleDeviceFullscreen"), undefined);
            tryCompare(devices, "loadedKind", "wifi");
            waitForRendering(devices.contentItem);
            const loader = deviceNamed("deviceSettingsPageLoader");
            saveDevicePreview("device-wifi");
            verify(loader.item.advancedOpen);
            verify(deviceNamed("deviceSettingsScroll").height >= 160);
            verify(loader.item.implicitHeight > 200);
            mouseClick(deviceNamed("deviceFeature_hidden"));
            tryCompare(Store, "deviceSettingsSection", "hidden");
            verify(loader.item.hiddenOpen);
            wait(40);
            const form = childrenOf(loader.item).find(item => item.objectName === "hiddenWifiForm");
            form.password = "clear-on-section-change";
            mouseClick(deviceNamed("deviceFeature_dns"));
            tryCompare(Store, "deviceSettingsSection", "dns");
            compare(form.password, "");
            wait(40);
            const wifiScroll = deviceNamed("deviceSettingsScroll");
            if (wifiScroll.contentHeight > wifiScroll.height) tryVerify(() => wifiScroll.contentY > 0, 1000);
            mouseClick(deviceNamed("deviceSettingsBack"));
            tryCompare(Store, "deviceSettingsSection", "networks");
            compare(loader.item.advancedOpen, false);
            mouseClick(deviceNamed("closeDeviceSettings"));
            tryCompare(Store, "deviceSettingsVisible", false);
        }
        function test_audio_compact_window_and_jumps_to_sections() {
            const button = childrenOf(compactAudio).find(item => item.objectName === "audioFullscreenButton");
            mouseClick(button);
            tryCompare(Store, "deviceSettingsVisible", true);
            compare(Store.deviceSettingsKind, "audio");
            compare(compactAudio.advancedOpen, false);
            tryCompare(devices, "fullscreen", false);
            verify(devices.height <= 620);
            tryCompare(devices, "loadedKind", "audio");
            waitForRendering(devices.contentItem);
            mouseClick(deviceNamed("deviceFeature_output"));
            tryCompare(Store, "deviceSettingsSection", "output");
            wait(40);
            const scroll = deviceNamed("deviceSettingsScroll");
            saveDevicePreview("device-audio");
            if (scroll.contentHeight > scroll.height) verify(scroll.contentY > 0);
            const outputY = scroll.contentY;
            mouseClick(deviceNamed("deviceFeature_microphone"));
            tryCompare(Store, "deviceSettingsSection", "microphone");
            wait(40);
            verify(scroll.contentY >= outputY);
            mouseClick(deviceNamed("deviceCategory_bluetooth"));
            tryCompare(devices, "loadedKind", "bluetooth");
            mouseClick(deviceNamed("deviceCategory_power"));
            tryCompare(devices, "loadedKind", "power");
        }
        function test_audio_advanced_stays_in_normal_panel() {
            compactAudio.advancedOpen = false;
            const button = childrenOf(compactAudio).find(item => item.objectName === "audioAdvancedButton");
            mouseClick(button);
            compare(compactAudio.advancedOpen, true);
            compare(Store.deviceSettingsVisible, false);
            compare(Store.deviceSettingsPending, false);
            compare(deviceRequests.count, 0);
            mouseClick(button);
            compare(compactAudio.advancedOpen, false);
        }
        function test_cancel_pending_device_window_and_reject_unknown_kind() {
            Store.openDeviceSettings("unknown-device", null, "unknown-section");
            compare(Store.deviceSettingsPending, false);
            Store.openDeviceSettings("bluetooth", null, "unknown-section");
            compare(Store.deviceSettingsSection, "devices");
            compare(Store.deviceSettingsPending, true);
            Store.closeDeviceSettings();
            wait(300);
            compare(Store.deviceSettingsVisible, false);
        }
        function test_settings_groups_routes_and_search() {
            settings.navigate("home");
            Store.settingsVisible = true;
            wait(60);
            compare(settings.activePage.label, "Settings");
            compare(settings.settingsGroup, "home");
            saveSettingsPreview("settings-home");
            const sidebar=childrenOf(settings.contentItem).find(item=>item.objectName==="rusticq-settings-sidebar");
            verify(sidebar!==undefined);
            verify(settings.navigationPages.some(page=>page.key==="bar"));
            verify(settings.navigationPages.some(page=>page.key==="wifi"));
            verify(settings.navigationPages.some(page=>page.group==="Connectivity"));
            settings.navigate("system");
            compare(settings.settingsGroup,"system");
            saveSettingsPreview("settings-system");
            for (const tab of ["wifi", "bluetooth", "audio", "power", "bar"]) {
                settings.navigate(tab);
                wait(60);
                compare(settings.activePage.key, tab);
            }
            settings.query = "hidden SSID";
            verify(settings.matched.some(item => item.tab === "wifi"));
            settings.navigate("home");
            compare(settings.query, "");
        }
    }
}
