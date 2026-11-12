#!/usr/bin/env python3
"""Quickshell 0.3.1 clock interactions, layout and persistence; isolated settings."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "components"
import "modules/settings/pages"
ShellRoot {
    Window {
        visible: true
        width: 850; height: 1100
        Clock { id: first; x: 10; y: 10; showDate: true }
        Clock { id: second; x: 10; y: 60; showDate: true }
        Clock { id: rail; x: 780; y: 100; vertical: true; showDetails: false }
        InfoSegment { id: weather; x: 650; y: 10; symbol: "\\ue430"; caption: "27°" }
        ClockSettingsEditor { id: editor; x: 10; y: 160; width: 700 }
        SignalSpy { id: timeClicks; target: first; signalName: "timeActivated" }
        SignalSpy { id: dateClicks; target: first; signalName: "dateActivated" }
        TestCase {
            name: "ClockCustomization"
            when: true
            function descendants(item) {
                let result = [item];
                for (const child of item.children) result = result.concat(descendants(child));
                return result;
            }
            function part(item, symbol) { return descendants(item).find(child => child.symbol === symbol); }
            function control(name) {
                const item = descendants(editor).find(child => child.objectName === name);
                verify(item !== undefined, name);
                return item;
            }
            function choose(name) {
                const item = control(name);
                mouseClick(item, item.width / 2, item.height / 2);
                wait(30);
            }
            function init() {
                SettingsStore.clockDisplayMode = "auto";
                SettingsStore.calendarDisplayMode = "auto";
                SettingsStore.clockFormat = "HH:mm";
                SettingsStore.calendarFormat = "ddd, dd MMM";
                SettingsStore.clockLocale = "system";
                SettingsStore.clockLowercase = false;
                first.showDetails = true;
                second.showDetails = true;
                rail.showTime = true;
                rail.showDate = false;
                timeClicks.clear(); dateClicks.clear();
                wait(30);
            }
            function cleanupTestCase() {
                console.log("CLOCK RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed");
            }
            function cleanup() {
                console.log("CLOCK TEST " + qtest_results.functionName + " failed=" + qtest_results.failed);
            }
            function test_styles_and_click_targets() {
                for (const mode of ["auto", "icon", "text", "both"]) {
                    choose("clockDisplayMode-" + mode);
                    choose("calendarDisplayMode-" + mode);
                    for (const details of [false, true]) {
                        first.showDetails = details;
                        wait(30);
                        for (const symbol of ["\\ue8b5", "\\uebcc"]) {
                            const segment = part(first, symbol);
                            compare(segment.showSymbol, mode !== "text");
                            compare(segment.showCaption, mode === "both" || mode === "text" || (mode === "auto" && details));
                            verify(segment.width > 0 && segment.height >= 28);
                            mouseClick(segment, segment.width / 2, segment.height / 2);
                        }
                        compare(weather.showSymbol, true);
                        compare(weather.showCaption, true);
                    }
                }
                compare(timeClicks.count, 8);
                compare(dateClicks.count, 8);
                verify(timeClicks.signalArguments[0][0] >= 0);
                verify(dateClicks.signalArguments[0][0] > timeClicks.signalArguments[0][0]);
            }
            function test_independent_calendar_and_monitors() {
                const weatherWidth = weather.width;
                choose("clockDisplayMode-text");
                choose("calendarDisplayMode-icon");
                choose("clockFormat-Time + full date");
                for (const clock of [first, second]) {
                    compare(part(clock, "\\ue8b5").showSymbol, false);
                    compare(part(clock, "\\uebcc").showSymbol, true);
                    compare(part(clock, "\\uebcc").showCaption, false);
                }
                compare(first.width, second.width);
                compare(weather.width, weatherWidth);
                verify(first.width > 200);
                choose("calendarFormat-Numeric");
                compare(SettingsStore.calendarFormat, "dd/MM/yyyy");
                compare(SettingsStore.clockFormat, "HH:mm dddd, d MMMM yyyy");
            }
            function test_locale_literals_and_validation() {
                const date = new Date(2026, 10, 13, 20, 30, 45);
                SettingsStore.clockLocale = "id_ID";
                SettingsStore.clockLowercase = true;
                compare(SettingsStore.formatClock(date, "HH:mm dddd, d MMMM yyyy"), "20:30 jumat, 13 november 2026");
                SettingsStore.clockLocale = "en_US";
                SettingsStore.clockLowercase = false;
                compare(SettingsStore.formatClock(date, "h:mm AP"), "8:30 PM");
                compare(SettingsStore.formatClock(date, "HH:mm 'on' dddd"), "20:30 on Friday");
                for (const invalid of ["", "   ", "HH:mm\\n", "\\u0000", "x".repeat(121), null, 17, {}]) {
                    verify(!SettingsStore.setClockFormat("clockFormat", invalid));
                    compare(SettingsStore.clockFormat, "HH:mm");
                }
                verify(!SettingsStore.setClockFormat("showWifi", "false"));
                verify(SettingsStore.showWifi);
            }
            function test_seconds_refresh_and_literals() {
                SettingsStore.clockFormat = "HH:mm:ss";
                wait(30);
                const before = part(first, "\\ue8b5").caption;
                tryVerify(() => part(first, "\\ue8b5").caption !== before, 2000);
                SettingsStore.clockFormat = "HH:mm 'seconds'";
                compare(first.usesSeconds, false);
                SettingsStore.calendarFormat = "HH:mm:ss";
                compare(first.usesSeconds, true);
                SettingsStore.calendarDisplayMode = "icon";
                compare(first.usesSeconds, false);
            }
            function test_vertical_formats_fit_rail() {
                SettingsStore.clockDisplayMode = "both";
                SettingsStore.clockFormat = "HH:mm dddd, d MMMM yyyy";
                wait(80);
                verify(rail.width <= Theme.verticalBarWidth - 8, "rail width: " + rail.width);
                verify(rail.height > 50);
                const segment = part(rail, "\\ue8b5");
                verify(segment.showSymbol && segment.showCaption);
                SettingsStore.clockDisplayMode = "text";
                wait(30);
                verify(rail.width <= Theme.verticalBarWidth - 8);
                verify(!segment.showSymbol && segment.showCaption);
            }
            function test_z_custom_edit_and_save() {
                choose("clockDisplayMode-text");
                choose("calendarDisplayMode-both");
                const input = control("clockFormat-input");
                input.forceActiveFocus();
                input.selectAll();
                keyClick(Qt.Key_Backspace);
                verify(!input.acceptableFormat);
                compare(SettingsStore.clockFormat, "HH:mm");
                input.insert(0, "HH:mm dddd, d MMMM yyyy");
                keyClick(Qt.Key_Return);
                compare(SettingsStore.clockFormat, "HH:mm dddd, d MMMM yyyy");
                choose("calendarFormat-Full date");
                SettingsStore.clockLocale = "id_ID";
                SettingsStore.clockLowercase = true;
                SettingsStore.save();
                wait(100);
            }
        }
    }
}
'''


def run_qml(root, env, source):
    (root / "shell.qml").write_text(source)
    result = subprocess.run(["qs", "-p", str(root / "shell.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=25)
    output = result.stdout + result.stderr
    print(output, end="")
    assert result.returncode == 0, result.returncode
    assert not re.search(r"(TypeError|ReferenceError|Binding loop|QML.*Error|Could not load)", output), output
    return output


def main():
    with tempfile.TemporaryDirectory(prefix="rusticq-clock-ui-") as folder:
        root = Path(folder)
        for name in ("components", "config", "services", "assets", "modules"):
            shutil.copytree(ROOT / name, root / name)
        icon_order = ["wifi", "time", "audio", "date", "rusticq", "arch", "launcher", "menu", "workspaces",
                      "weather", "bluetooth", "battery", "notifications", "barToggle", "task", "quickModes",
                      "quickControl", "mic", "down", "up"]
        original = {"showWifi": True, "showAudio": True, "showBattery": True,
                    "barIconVisibilityProfiles": {"compact": {"showWifi": True, "showTime": False}},
                    "barIconOrderByMode": {"compact": icon_order}}
        (root / "user-settings.json").write_text(json.dumps(original))
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="generic",
                   QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=folder)
        output = run_qml(root, env, QML)
        summary = re.search(r"CLOCK RESULTS (\d+) passed, (\d+) failed", output)
        assert summary and int(summary[1]) >= 6 and int(summary[2]) == 0
        saved = json.loads((root / "user-settings.json").read_text())
        for key, value in original.items():
            assert saved[key] == value, key
        expected = {"clockDisplayMode": "text", "calendarDisplayMode": "both",
                    "clockFormat": "HH:mm dddd, d MMMM yyyy", "calendarFormat": "dddd, d MMMM yyyy",
                    "clockLocale": "id_ID", "clockLowercase": True}
        for key, value in expected.items():
            assert saved[key] == value, (key, saved[key])
        checks = "\n".join(f"compare(SettingsStore.{key}, {json.dumps(value)});" for key, value in expected.items())
        reload_qml = '''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot {
    TestCase {
        when: true
        function test_reload() {
            CHECKS
            console.log("CLOCK RELOAD PASS");
        }
    }
}
'''
        assert "CLOCK RELOAD PASS" in run_qml(root, env, reload_qml.replace("CHECKS", checks))
        (root / "user-settings.json").write_text(json.dumps({
            "clockDisplayMode": "invalid", "calendarDisplayMode": False,
            "clockFormat": "", "calendarFormat": ["HH:mm"], "clockLocale": "invalid", "clockLowercase": "true"}))
        defaults = '''compare(SettingsStore.clockDisplayMode, "auto");
            compare(SettingsStore.calendarDisplayMode, "auto");
            compare(SettingsStore.clockFormat, "HH:mm");
            compare(SettingsStore.calendarFormat, "ddd, dd MMM");
            compare(SettingsStore.clockLocale, "system");
            compare(SettingsStore.clockLowercase, false);'''
        assert "CLOCK RELOAD PASS" in run_qml(root, env, reload_qml.replace("CHECKS", defaults))
    print("PASS: clock styles, clicks, locale, seconds, vertical rail, independent instances, settings edit/save/reload and safe defaults")


if __name__ == "__main__":
    main()
