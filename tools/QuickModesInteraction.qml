import QtQuick
import QtTest
import "../components"
import "../config"
import "../services"

Item {
    width: 600
    height: 160
    Indicators { id: indicators; x: 20; y: 8; compact: true; backgroundEnabled: false }
    ScanButton { id: scan; x: 20; y: 110 }
    SignalSpy { id: scanClicks; target: scan; signalName: "clicked" }
    QuickModes {
        id: group
        anchors.right: parent.right
        anchors.rightMargin: 40
        y: 40
        backgroundEnabled: false
        visible: SettingsStore.showQuickModes && hasModules
    }
    TestCase {
        name: "QuickModesInteraction"
        when: true
        function initTestCase() {
            console.log("INTERACTION TESTS START");
            compare(SettingsStore.showNightMode, false);
            compare(SettingsStore.showMicMute, false);
        }
        function cleanupTestCase() { console.log("INTERACTION RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
        function cleanup() { console.log("TEST " + qtest_results.functionName + " failed=" + qtest_results.failed); }
        function init() {
            SettingsStore.showQuickModes = true;
            SettingsStore.quickModesAutoHide = true;
            SettingsStore.showKeepAwake = true;
            SettingsStore.showSilent = true;
            SettingsStore.showGamingMode = true;
            SettingsStore.showNightMode = true;
            SettingsStore.showMicMute = true;
            scan.enabled = true;
            scan.scanning = false;
            scanClicks.clear();
            mouseMove(group, -300, 70);
            group.focus = false;
            group.revealed = false;
            wait(30);
        }
        function descendants(item) {
            let result = [item];
            for (const child of item.children) result = result.concat(descendants(child));
            return result;
        }
        function test_clean_indicator_colors_and_spacing() {
            const units = descendants(indicators).filter(item => item.iconSlotWidth !== undefined);
            compare(units.length, 3);
            const icons = units.map(item => descendants(item).find(child => child.icon !== undefined));
            for (const icon of icons) {
                compare(icon.width, 18);
                compare(icon.font.pixelSize, 16);
                compare(icon.color, Theme.foreground);
            }
            compare(units[1].x - units[0].x - units[0].width, 12);
            compare(units[2].x - units[1].x - units[1].width, 12);
            BluetoothService.connected = false;
            WifiService.connected = false;
            compare(icons[0].color, Theme.foreground);
            compare(icons[1].color, Theme.foreground);
            WifiService.connected = true;
            WifiService.strength = 25;
            compare(icons[1].color, Theme.warning);
            const wifiLabel = descendants(units[1]).find(item => item.text !== undefined && item.icon === undefined);
            compare(wifiLabel.color, Theme.warning);
            WifiService.strength = 26;
            compare(icons[1].color, Theme.foreground);
            BatteryService.percentage = 10;
            compare(icons[2].color, Theme.error);
            const batteryLabel = descendants(units[2]).find(item => item.text !== undefined && item.icon === undefined);
            compare(batteryLabel.color, Theme.error);
            BatteryService.charging = true;
            compare(icons[2].color, Theme.foreground);
            compare(batteryLabel.color, Theme.foreground);
            mouseMove(units[0], 9, 9);
            wait(50);
            const label = descendants(units[0]).find(item => item.text !== undefined && item.icon === undefined);
            verify(label.visible);
            compare(label.font.pixelSize, 12);
            compare(label.color, Theme.foreground);
            compare(label.x - icons[0].x - icons[0].width, 6);
        }
        function test_scan_button_states_and_clicks() {
            compare(scan.width, 100);
            compare(scan.height, 32);
            compare(scan.label, "Scan");
            mouseClick(scan, 50, 16);
            compare(scanClicks.count, 1);
            scan.scanning = true;
            compare(scan.label, "Stop scan");
            scan.enabled = false;
            compare(scan.opacity, 0.45);
            mouseClick(scan, 50, 16);
            compare(scanClicks.count, 1);
        }
        function test_nearby_hover_and_delayed_close() {
            compare(group.expanded, false);
            compare(group.width, 28);
            const right = group.x + group.width;
            mouseMove(group, group.width + 4, 12);
            tryCompare(group, "expanded", true);
            verify(group.width > 28);
            compare(group.x + group.width, right);
            mouseMove(group, 14, 12);
            wait(500);
            compare(group.expanded, true);
            mouseMove(group, -50, 60);
            wait(150);
            compare(group.expanded, true);
            tryCompare(group, "expanded", false, 1000);
            compare(group.width, 28);
        }
        function test_click_toggles_mode_without_closing() {
            group.reveal();
            wait(30);
            mouseClick(group, 14, 12);
            compare(QuickModesService.keepAwake, true);
            compare(group.expanded, true);
            mouseClick(group, 14, 12);
            compare(QuickModesService.keepAwake, false);
        }
        function test_visible_modules_and_autohide_setting() {
            SettingsStore.quickModesAutoHide = false;
            tryCompare(group, "expanded", true);
            tryVerify(() => group.width > 28);
            const width = group.width;
            SettingsStore.showSilent = false;
            compare(group.modes.length, 4);
            tryVerify(() => group.width < width);
            mouseMove(group, -50, 60);
            wait(500);
            compare(group.expanded, true);
            SettingsStore.showKeepAwake = false;
            SettingsStore.showGamingMode = false;
            SettingsStore.showNightMode = false;
            SettingsStore.showMicMute = false;
            tryCompare(group, "visible", false);
            SettingsStore.save();
        }
    }
}
