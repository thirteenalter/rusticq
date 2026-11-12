import QtQuick
import QtTest
import Quickshell
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
    SignalSpy { id: deviceRequests; target: Store; signalName: "deviceSettingsRequested" }
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
            Store.closeDeviceSettings();
            deviceRequests.clear();
            wifiCard.popupScreen = ({height: 720});
            wifiCard.showNetworks();
            WifiService.hiddenConnecting = false;
            WifiService.hiddenMessage = "";
            WifiService.hiddenFailed = false;
            WifiService.enabled = true;
            WifiService.calls = 0;
            Pipewire.nodes.values = [];
            mixer.visible = true;
            playback.audio.volume = 0.4;
            playback.audio.muted = false;
            playback.audio.channels = [1, 2];
            playback.properties = {"application.name": "Firefox", "media.name": "Example video"};
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
        function test_wifi_fullscreen_icon_and_feature_buttons() {
            wifiCard.popupScreen = null;
            Store.sidebarVisible = true;
            mouseClick(named("wifiFullscreenButton"));
            compare(Store.deviceSettingsPending, true);
            compare(Store.deviceSettingsVisible, false);
            compare(Store.sidebarVisible, false);
            compare(deviceRequests.count, 1);
            tryCompare(Store, "deviceSettingsVisible", true);
            tryCompare(devices, "fullscreen", true);
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
            if (wifiScroll.contentHeight > wifiScroll.height) verify(wifiScroll.contentY > 0);
            mouseClick(deviceNamed("deviceSettingsBack"));
            tryCompare(Store, "deviceSettingsSection", "networks");
            compare(loader.item.advancedOpen, false);
            mouseClick(deviceNamed("closeDeviceSettings"));
            tryCompare(Store, "deviceSettingsVisible", false);
        }
        function test_audio_fullscreen_icon_and_jumps_to_sections() {
            const button = childrenOf(compactAudio).find(item => item.objectName === "audioFullscreenButton");
            mouseClick(button);
            tryCompare(Store, "deviceSettingsVisible", true);
            compare(Store.deviceSettingsKind, "audio");
            compare(compactAudio.advancedOpen, false);
            tryCompare(devices, "fullscreen", true);
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
            mouseClick(deviceNamed("toggleDeviceFullscreen"));
            tryCompare(devices, "fullscreen", false);
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
            const uiButton = childrenOf(settings.contentItem).find(item => item.objectName === "settingsGroup_ui");
            verify(uiButton !== undefined);
            waitForRendering(settings.contentItem);
            mouseClick(uiButton);
            tryCompare(settings, "settingsGroup", "ui");
            verify(settings.navigationPages.some(page => page.key === "bar"));
            verify(!settings.navigationPages.some(page => page.key === "wifi"));
            mouseClick(childrenOf(settings.contentItem).find(item => item.objectName === "settingsGroup_system"));
            tryCompare(settings, "settingsGroup", "system");
            saveSettingsPreview("settings-system");
            verify(settings.navigationPages.some(page => page.key === "wifi"));
            verify(!settings.navigationPages.some(page => page.key === "bar"));
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
