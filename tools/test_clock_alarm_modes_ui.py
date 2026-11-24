#!/usr/bin/env python3
"""Quickshell clock/alarm and real mode-controller tests with isolated devices."""
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

from test_clock_ui import run_qml

ROOT = Path(__file__).resolve().parents[1]
QML = r'''import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtTest
import Quickshell
import "config"
import "services"
import "fixtures"
import "modules/main"
import "modules/settings"
import "modules/settings/pages"
ShellRoot {
    KeepAwakeSurface { id: awakeSurface }
    SettingsWindow { id: settingsWindow }
    Window {
        id: window
        visible: true; width: 1100; height: 900; color: Theme.background
        Loader { id: first; x: 8; y: 8; width: 350; height: 650; sourceComponent: clock }
        Loader { id: second; x: 370; y: 8; width: 350; height: 650; sourceComponent: clock }
        Component { id: clock; MiniTime {} }
        ClockSoundSettings { id: sound; x: 730; y: 8; width: 350 }
        NightLightSettings { id: night; x: 730; y: 500; width: 350 }
        SignalSpy { id: alarm; target: Store; signalName: "clockAlarmCompleted" }
        SignalSpy { id: soundRequests; target: Store; signalName: "clockSoundRequested" }
        TestCase {
            when: true
            property bool saved: false
            function descendants(item) {
                let all = [item];
                for (const child of item.children) all = all.concat(descendants(child));
                return all;
            }
            function control(name, item) {
                const result = descendants(item || first.item).find(child => child.objectName === name);
                verify(result !== undefined, name);
                return result;
            }
            function check(value, message) { if (!value) console.error("FAILED:", message); verify(value, message); }
            function eq(actual, expected, message) {
                if (actual !== expected) console.error("MISMATCH:", message, actual, expected);
                compare(actual, expected, message);
            }
            function choose(name, parent) {
                const item = control(name, parent);
                const viewport = descendants(parent || first.item).find(child => child.objectName === "clock-timer-viewport");
                if (viewport) viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - viewport.height, item.mapToItem(viewport.contentItem, 0, 0).y - 20));
                wait(20);
                mouseClick(item, item.width / 2, item.height / 2); wait(30);
            }
            function enter(name, value) {
                const item = control(name);
                item.forceActiveFocus(); item.selectAll(); item.text = value;
            }
            function expireAlarm(daily) {
                check(SettingsStore.setClockAlarm(7, 30, daily), "arm alarm");
                SettingsStore.clockAlarmNextAt = Date.now() - 1000;
                Store.updateClockAlarm();
            }
            function init() {
                first.active = true; second.active = true;
                Store.cancelClockAlarm(); Store.dismissClockAlert(); Store.resetClockTimer();
                SettingsStore.clockSoundEnabled = true;
                SettingsStore.clockSoundLoop = true;
                SettingsStore.clockSoundVolume = 125;
                SettingsStore.clockSound = "chime";
                first.item.advancedTimer = false; first.item.alarmView = false;
                second.item.advancedTimer = false; second.item.alarmView = false;
                NotificationCenter.doNotDisturb = false; NotificationCenter.clear();
                PowerProfiles.reject = false; PowerProfiles.profile = 1;
                alarm.clear(); soundRequests.clear();
                wait(70);
            }
            function cleanup() {
                if (qtest_results.functionName !== "test_z_save_settings_and_preview") Store.cancelClockAlarm();
                Store.dismissClockAlert(); Store.resetClockTimer();
                if (QuickModesService.awakeRequested) QuickModesService.toggle("awake");
                settingsWindow.visible = false;
                console.log("FEATURE TEST " + qtest_results.functionName + " failed=" + qtest_results.failed);
            }
            function cleanupTestCase() {
                console.log("FEATURE RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed");
            }
            function test_alarm_editor_shares_schedule_and_validation() {
                choose("clock-alarm-open");
                enter("clock-alarm-hours", "23"); enter("clock-alarm-minutes", "59");
                choose("clock-alarm-daily"); choose("clock-alarm-save");
                eq(SettingsStore.clockAlarmHour, 23, "hours"); eq(SettingsStore.clockAlarmMinute, 59, "minutes");
                check(SettingsStore.clockAlarmEnabled && SettingsStore.clockAlarmDaily, "daily enabled");
                check(SettingsStore.clockAlarmNextAt > Date.now(), "next alarm is in the future");
                choose("clock-alarm-open", second.item);
                eq(control("clock-alarm-hours", second.item).text, "23", "shared hour");
                enter("clock-alarm-hours", ""); check(!control("clock-alarm-save").enabled, "empty input disabled");
                for (const values of [[24, 0, true], [1, 60, false], [-1, 0, true], [1, 1, "daily"]])
                    check(!SettingsStore.setClockAlarm(...values), "invalid alarm rejected");
                choose("clock-alarm-disable", second.item);
                check(!SettingsStore.clockAlarmEnabled, "disabled across popups");
            }
            function test_alarm_midnight_daily_and_late_tick_only_once() {
                SettingsStore.clockAlarmHour = 0; SettingsStore.clockAlarmMinute = 0;
                const before = new Date(2026, 10, 13, 23, 59, 59).getTime();
                eq(SettingsStore.nextClockAlarm(before), new Date(2026, 10, 14, 0, 0).getTime(), "local midnight");
                expireAlarm(true);
                eq(alarm.count, 1, "one alarm");
                check(SettingsStore.clockAlarmEnabled && SettingsStore.clockAlarmNextAt > Date.now(), "daily rearmed");
                Store.updateClockAlarm(); Store.updateClockAlarm(); eq(alarm.count, 1, "no duplicates");
            }
            function test_alarm_closed_popups_notification_and_snooze() {
                NotificationCenter.doNotDisturb = true;
                first.active = false; second.active = false;
                expireAlarm(false);
                eq(alarm.count, 1, "closed alarm completed");
                eq(NotificationCenter.toast, null, "DND suppresses toast");
                eq(NotificationCenter.history[0].tag, "Alarm", "history");
                check(!SettingsStore.clockAlarmEnabled, "once disarmed");
                tryCompare(Store, "clockSoundPlaying", true, 1500);
                const entry = NotificationCenter.history[0];
                NotificationCenter.invokeAction(entry.serial, 1);
                check(Store.clockAlarmSnoozeUntil > Date.now(), "snoozed");
                tryCompare(Store, "clockSoundPlaying", false, 1500);
                Store.clockAlarmSnoozeUntil = Date.now() - 10; Store.updateClockAlarm();
                eq(alarm.count, 2, "snoozed alarm rings again");
                NotificationCenter.invokeAction(entry.serial, 0);
                eq(Store.clockAlertKind, "alarm", "old actions cannot stop new alert");
                NotificationCenter.invokeAction(NotificationCenter.history[0].serial, 0);
                eq(Store.clockAlertKind, "", "stop action");
                tryCompare(Store, "clockSoundPlaying", false, 1500);
            }
            function test_timer_sound_and_stop_survive_popup_unload() {
                Store.setClockTimerDuration(1); Store.startClockTimer();
                first.active = false; second.active = false;
                Store.clockTimerDeadline = Date.now() - 1; Store.updateClockTimer();
                eq(soundRequests.count, 1, "sound requested once");
                tryCompare(Store, "clockSoundPlaying", true, 1500);
                wait(150); check(Store.clockSoundPlaying, "loop stays alive");
                first.active = true; tryCompare(first, "status", Loader.Ready);
                choose("clock-alert-stop");
                tryCompare(Store, "clockSoundPlaying", false, 1500);
            }
            function test_sound_settings_choices_volume_cap_and_no_popup_settings() {
                choose("clock-timer-advanced");
                check(!descendants(first.item).some(item => item.objectName === "clock-sound-volume"), "sound settings are outside Advanced");
                choose("clock-sound-bell", sound); eq(SettingsStore.clockSound, "bell", "bell selected");
                const slider = control("clock-sound-volume", sound);
                mouseClick(slider, slider.width - 1, slider.height / 2);
                eq(SettingsStore.clockSoundVolume, 125, "125 percent limit");
                check(!SettingsStore.setClockSoundVolume(126), "above max rejected");
                check(!SettingsStore.setClockSoundVolume(-1), "negative rejected");
                choose("clock-sound-test", sound); tryCompare(Store, "clockSoundPlaying", true, 1500);
                choose("clock-sound-loop", sound); check(!SettingsStore.clockSoundLoop, "one shot chosen");
                SettingsStore.setClockSoundVolume(90);
                Store.clockSoundStopped(); tryCompare(Store, "clockSoundPlaying", false, 1500);
                wait(100); check(!Store.clockSoundPlaying, "stop cancels queued restarts");
                check(SettingsStore.setClockSound("custom", "/tmp/My clock tone.wav"), "local file accepted");
                check(!SettingsStore.setClockSound("custom", "https://example.com/tone.wav"), "remote file rejected");
                check(!SettingsStore.setClockSound("custom", "/tmp/tone.txt"), "non audio rejected");
                choose("clock-sound-test", sound); tryCompare(Store, "clockSoundPlaying", true, 1500);
                wait(80); Store.clockSoundStopped(); tryCompare(Store, "clockSoundPlaying", false, 1500);
                choose("clock-sound-toggle", sound); eq(SettingsStore.clockSoundEnabled, false, "sound muted");
                expireAlarm(false); eq(soundRequests.count, 2, "muted alarm has no additional sound");
                eq(Store.clockAlertKind, "alarm", "visual alarm remains");
            }
            function test_sound_rapid_changes_then_stop_do_not_restart() {
                Store.clockSoundRequested(false);
                SettingsStore.setClockSoundVolume(110);
                SettingsStore.setClockSound("digital", "");
                Store.clockSoundStopped();
                wait(250);
                check(!Store.clockSoundPlaying && !NotificationCenter.clockSoundActive, "rapid start/change/stop cleaned up");
            }
            function test_system_clock_navigation() {
                settingsWindow.navigate("system");
                check(settingsWindow.navigationPages.some(page => page.key === "clock"), "Clock in System");
                settingsWindow.navigate("clock"); eq(settingsWindow.settingsGroup, "system", "clock group");
                wait(100);
                check(descendants(settingsWindow.contentItem).some(item => item.objectName === "clock-sound-volume"), "clock page sound section loads");
            }
            function test_native_silent_and_microphone() {
                check(QuickModesService.available("silent"), "native silent available");
                QuickModesService.toggle("silent"); check(NotificationCenter.doNotDisturb, "native DND on");
                NotificationCenter.previewNotification(); eq(NotificationCenter.toast, null, "silent suppresses toast");
                QuickModesService.toggle("silent"); check(!NotificationCenter.doNotDisturb, "native DND off");
                QuickModesService.toggle("mic"); check(QuickModesService.active("mic"), "mic muted");
                QuickModesService.toggle("mic"); check(!QuickModesService.active("mic"), "mic unmuted");
            }
            function test_keep_awake_survives_hidden_bar_and_releases() {
                QuickModesService.toggle("awake"); tryCompare(QuickModesService, "keepAwake", true, 1500);
                tryCompare(awakeSurface, "visible", true, 1500);
                SettingsStore.setBarVisibilityMode("hidden"); wait(80);
                check(awakeSurface.visible && QuickModesService.keepAwake, "inhibitor survives hidden bar");
                QuickModesService.toggle("awake"); tryCompare(QuickModesService, "keepAwake", false, 1500);
                tryCompare(awakeSurface, "visible", false, 1500);
                wait(100); eq(QuickModesService.error, "", "clean inhibitor release");
            }
            function test_gaming_profile_restore_and_failure_readback() {
                QuickModesService.toggle("gaming"); eq(PowerProfiles.profile, 2, "performance selected");
                wait(950); QuickModesService.toggle("gaming"); eq(PowerProfiles.profile, 1, "previous restored");
                wait(950); PowerProfiles.reject = true; QuickModesService.toggle("gaming"); wait(950);
                check(QuickModesService.error.indexOf("did not apply") >= 0, "failed profile surfaced");
                PowerProfiles.reject = false; PowerProfiles.hasPerformanceProfile = false;
                check(!QuickModesService.available("gaming"), "unsupported profile unavailable");
                PowerProfiles.hasPerformanceProfile = true;
            }
            function test_night_temperature_queue_and_off_preference() {
                tryVerify(() => QuickModesService.available("night") && !QuickModesService.busy, 2000);
                if (!QuickModesService.active("night")) QuickModesService.toggle("night");
                tryVerify(() => QuickModesService.active("night") && !QuickModesService.busy, 2000);
                QuickModesService.setNightLightTemperature(3000);
                QuickModesService.setNightLightTemperature(5000);
                QuickModesService.setNightLightTemperature(3400);
                tryVerify(() => !QuickModesService.busy && QuickModesService.states.night.temperature === 3400, 3000);
                QuickModesService.toggle("night");
                QuickModesService.setNightLightTemperature(3500);
                tryVerify(() => !QuickModesService.busy && !QuickModesService.active("night"), 3000);
                eq(SettingsStore.nightLightTemperature, 3500, "saved while off");
                choose("night-light-preset-3000", night);
                eq(SettingsStore.nightLightTemperature, 3000, "preset saved");
                check(!QuickModesService.active("night"), "preset does not turn on");
            }
            function test_z_save_settings_and_preview() {
                SettingsStore.setClockSound("digital", ""); SettingsStore.setClockSoundVolume(125);
                SettingsStore.clockSoundLoop = true; SettingsStore.clockSoundEnabled = true;
                SettingsStore.setClockAlarm(6, 45, true);
                SettingsStore.setNightLightTemperature(3200); SettingsStore.save();
                sound.grabToImage(result => { saved = result.saveToFile("/tmp/rusticq-clock-sound-settings.png"); });
                tryVerify(() => saved, 1500);
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-clock-modes-') as folder:
        root = Path(folder)
        root.chmod(0o700)
        for name in ('components', 'config', 'services', 'assets', 'modules'):
            shutil.copytree(ROOT / name, root / name)
        (root / 'user-settings.json').write_text('{"showWifi":true}')
        for name in ('scripts', 'bin', 'home', 'fixtures'):
            (root / name).mkdir()
        (root / 'scripts/rustiq-notification-doctor.py').write_text('print(\'{"state":"free"}\')')
        (root / 'scripts/rustiq-settings-float.py').write_text('pass')
        (root / 'scripts/quick_modes.py').write_text('''import json, sys, time
from pathlib import Path
path = Path(__file__).with_name('night.json')
value = json.loads(path.read_text()) if path.exists() else 6500
if sys.argv[1] == 'set':
    time.sleep(.08)
    value = int(sys.argv[-1]) if sys.argv[3] == 'on' else 6500
    path.write_text(json.dumps(value))
print(json.dumps({'ok':True,'states':{'night':{'available':True,'active':value < 6500,'temperature':value,'detail':str(value)}}}))
''')
        (root / 'scripts/rusticq-clock-sound.py').write_text('''import json, signal, sys, time
from pathlib import Path
log = Path(__file__).with_name('sound.jsonl')
with log.open('a') as f: f.write(json.dumps(sys.argv[1:])+'\\n')
def stop(*args): raise SystemExit(0)
signal.signal(signal.SIGTERM,stop)
while True: time.sleep(.05)
''')
        (root / 'bin/systemd-inhibit').write_text('''#!/usr/bin/env python3
import sys
sys.stdin.buffer.read()
''')
        (root / 'bin/systemd-inhibit').chmod(0o755)
        fixtures = {
            'PowerProfile': 'enum Values { PowerSaver, Balanced, Performance }',
            'PowerProfiles': 'property int profile: 1; property bool hasPerformanceProfile: true; property bool reject: false; onProfileChanged: if (reject && profile !== 1) profile = 1',
            'Pipewire': 'property var defaultAudioSource: QtObject { property var audio: QtObject { property bool muted: false } }',
        }
        qmldir = []
        for name, body in fixtures.items():
            (root / 'fixtures' / (name + '.qml')).write_text('pragma Singleton\nimport QtQuick\nQtObject { ' + body + ' }')
            qmldir.append(f'singleton {name} 1.0 {name}.qml')
        (root / 'fixtures/PwObjectTracker.qml').write_text('import QtQuick\nQtObject { property var objects: [] }')
        qmldir.append('PwObjectTracker 1.0 PwObjectTracker.qml')
        (root / 'fixtures/qmldir').write_text('\n'.join(qmldir))
        service = root / 'services/QuickModesService.qml'
        service.write_text(service.read_text().replace('import Quickshell.Services.UPower', 'import "../fixtures"').replace('import Quickshell.Services.Pipewire', ''))
        # Offscreen has no layer-shell backend; model only its visibility while
        # exercising the real controller and inhibitor pipe. Verify Wayland separately.
        surface = root / 'modules/main/KeepAwakeSurface.qml'
        surface.write_text('''import QtQuick
import "../../services"
QtObject { property bool visible: QuickModesService.keepAwake }
''')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic', QT_QUICK_BACKEND='software',
                   XDG_RUNTIME_DIR=folder, HOME=str(root / 'home'), XDG_STATE_HOME=str(root / 'state'),
                   XDG_CACHE_HOME=str(root / 'cache'), XDG_DATA_HOME=str(root / 'data'),
                   DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(root / 'missing-bus'),
                   PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'])
        output = run_qml(root, env, QML)
        result = re.search(r'FEATURE RESULTS (\d+) passed, (\d+) failed', output)
        assert result and int(result[1]) >= 11 and int(result[2]) == 0, output
        saved = json.loads((root / 'user-settings.json').read_text())
        assert saved['showWifi'] is True
        assert saved['clockSound'] == 'digital' and saved['clockSoundVolume'] == 125
        assert saved['nightLightTemperature'] == 3200 and saved['clockSoundLoop'] is True
        events = [json.loads(line) for line in (root / 'scripts/sound.jsonl').read_text().splitlines()]
        assert any('--loop' in event and event[event.index('--volume') + 1] == '125' for event in events)
        assert any('--file' in event and '/tmp/My clock tone.wav' in event for event in events)
        reload_source = '''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot { TestCase { when: true; function test_reload() {
    compare(SettingsStore.clockSound, "digital"); compare(SettingsStore.clockSoundVolume, 125);
    compare(SettingsStore.clockSoundLoop, true); compare(SettingsStore.nightLightTemperature, 3200);
    compare(SettingsStore.clockAlarmHour, 6); compare(SettingsStore.clockAlarmMinute, 45);
    compare(SettingsStore.clockAlarmDaily, true); compare(SettingsStore.clockAlarmEnabled, true);
    verify(SettingsStore.clockAlarmNextAt > Date.now()); console.log("FEATURE RELOAD PASS");
} } }
'''
        assert 'FEATURE RELOAD PASS' in run_qml(root, env, reload_source)
        (root / 'user-settings.json').write_text(json.dumps({
            'clockSoundVolume': 200, 'clockSoundLoop': 'yes', 'clockSound': 'custom',
            'clockSoundFile': 'https://example.com/tone.wav', 'clockAlarmHour': 24,
            'clockAlarmMinute': -1, 'clockAlarmEnabled': True, 'clockAlarmNextAt': 'invalid',
            'nightLightTemperature': 9000,
        }))
        defaults = '''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot { TestCase { when: true; function test_safe_defaults() {
    compare(SettingsStore.clockSoundVolume, 125); compare(SettingsStore.clockSoundLoop, true);
    compare(SettingsStore.clockSound, "chime"); compare(SettingsStore.clockSoundFile, "");
    compare(SettingsStore.clockAlarmHour, 7); compare(SettingsStore.clockAlarmMinute, 0);
    compare(SettingsStore.clockAlarmEnabled, false); compare(SettingsStore.nightLightTemperature, 4000);
    console.log("FEATURE DEFAULTS PASS");
} } }
'''
        assert 'FEATURE DEFAULTS PASS' in run_qml(root, env, defaults)
    print('PASS: alarm, snooze, DND, loop/stop, custom sound, 125% cap, System Clock navigation, native modes, queued warmth and persistence')


if __name__ == '__main__':
    main()
