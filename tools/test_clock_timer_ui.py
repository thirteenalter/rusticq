#!/usr/bin/env python3
"""Native countdown interactions, popup lifetime and notifications in isolated QML."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from test_clock_ui import run_qml

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "services"
import "modules/main"

ShellRoot {
    FloatingWindow {
        id: popupHost
        visible: false
        implicitWidth: 780
        implicitHeight: 34
        property int barHeight: 34
    }
    IndicatorPopup { id: nativePopup; hostWindow: popupHost }
    Window {
        id: testWindow
        visible: true
        width: 780
        height: 760
        color: Theme.background
        Loader {
            id: first
            x: 8; y: 8; width: 352
            height: item ? item.implicitHeight : 500
            sourceComponent: timerPopup
        }
        Loader {
            id: second
            x: 400; y: 8; width: 352
            height: item ? item.implicitHeight : 500
            sourceComponent: timerPopup
        }
        Component { id: timerPopup; MiniTime {} }
        SignalSpy { id: completed; target: Store; signalName: "clockTimerCompleted" }
        TestCase {
            name: "ClockTimer"
            when: true
            property bool previewSaved: false
            function descendants(item) {
                let result = [item];
                for (const child of item.children) result = result.concat(descendants(child));
                return result;
            }
            function control(name, view) {
                const item = descendants(view || first.item).find(child => child.objectName === name);
                verify(item !== undefined, name);
                return item;
            }
            function choose(name, view) {
                const item = control(name, view);
                mouseClick(item, item.width / 2, item.height / 2);
                wait(30);
            }
            function input(name, value) {
                const item = control("clock-timer-" + name);
                testWindow.requestActivate();
                item.forceActiveFocus();
                wait(20);
                item.selectAll();
                keyClick(Qt.Key_Backspace);
                item.insert(0, value);
                wait(20);
            }
            function equal(actual, expected, message) {
                if (actual !== expected) console.error("TIMER MISMATCH", message, "actual:", actual, "expected:", expected);
                compare(actual, expected, message);
            }
            function init() {
                SettingsStore.clockSoundEnabled = false;
                first.active = true;
                first.height = Qt.binding(() => first.item ? first.item.implicitHeight : 500);
                Store.resetClockTimer();
                Store.setClockTimerDuration(300);
                first.item.advancedTimer = true;
                second.item.advancedTimer = true;
                first.item.syncDurationFields();
                second.item.syncDurationFields();
                NotificationCenter.doNotDisturb = false;
                NotificationCenter.clear();
                completed.clear();
                wait(50);
            }
            function cleanup() {
                nativePopup.kind = "";
                popupHost.visible = false;
                Store.resetClockTimer();
                NotificationCenter.doNotDisturb = false;
                console.log("TIMER TEST " + qtest_results.functionName + " failed=" + qtest_results.failed);
            }
            function cleanupTestCase() {
                console.log("TIMER RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed");
            }
            function test_duration_inputs_and_presets() {
                equal(first.item.draftSeconds, 300, "Initial duration");
                verify(control("clock-timer-start").enabled);
                for (const seconds of [60, 300, 900, 1500]) {
                    choose("clock-timer-preset-" + seconds);
                    equal(first.item.draftSeconds, seconds, "Preset input");
                    equal(second.item.draftSeconds, seconds, "Shared preset");
                    equal(Store.clockTimerDurationSeconds, seconds, "Stored preset");
                }
                input("hours", "23"); input("minutes", "59"); input("seconds", "59");
                equal(first.item.draftSeconds, 86399, "Custom hours/minutes/seconds");
                choose("clock-timer-start");
                equal(Store.clockTimerDurationSeconds, 86399, "Custom duration started");
                equal(Store.clockTimerState, "running", "Custom timer state");
                equal(control("clock-timer-start", second.item).label, "Pause", "Shared start action");
                equal(Store.formatClockTimer(86399), "23:59:59", "Duration display");
            }
            function test_zero_and_invalid_durations_do_not_start() {
                input("hours", "00"); input("minutes", "00"); input("seconds", "00");
                compare(first.item.draftSeconds, 0);
                verify(!control("clock-timer-start").enabled);
                choose("clock-timer-start");
                compare(Store.clockTimerState, "idle");
                for (const invalid of [0, -1, 86400, 1.5, NaN, Infinity, "1", null]) {
                    verify(!Store.setClockTimerDuration(invalid));
                    compare(Store.clockTimerDurationSeconds, 300);
                }
                choose("clock-timer-preset-300");
                compare(first.item.draftSeconds, 300);
                verify(control("clock-timer-start").enabled);
            }
            function test_pause_resume_and_cross_popup_reset() {
                Store.setClockTimerDuration(3);
                choose("clock-timer-start");
                wait(350);
                choose("clock-timer-start", second.item);
                compare(Store.clockTimerState, "paused");
                const remaining = Store.clockTimerRemainingMs;
                verify(remaining > 0 && remaining < 3000);
                wait(400);
                compare(Store.clockTimerRemainingMs, remaining);
                choose("clock-timer-start");
                compare(Store.clockTimerState, "running");
                verify(Math.abs(Store.clockTimerDeadline - Date.now() - remaining) < 150);
                choose("clock-timer-reset", second.item);
                compare(Store.clockTimerState, "idle");
                compare(Store.clockTimerRemainingSeconds, 3);
                compare(completed.count, 0);
            }
            function test_closed_popup_finishes_once_and_reopens_with_shared_state() {
                Store.setClockTimerDuration(1);
                choose("clock-timer-start");
                first.active = false;
                tryCompare(Store, "clockTimerState", "finished", 2000);
                compare(Store.clockTimerRemainingSeconds, 0);
                compare(completed.count, 1);
                compare(NotificationCenter.history.length, 1);
                compare(NotificationCenter.toast.title, "Timer finished");
                compare(NotificationCenter.toast.tag, "Timer");
                first.active = true;
                tryCompare(first, "status", Loader.Ready);
                compare(first.item.advancedTimer, false);
                choose("clock-timer-advanced");
                compare(control("clock-timer-start").label, "Start again");
                compare(control("clock-timer-remaining", second.item).text, "00:00:00");
                Store.updateClockTimer(); Store.updateClockTimer();
                compare(completed.count, 1);
                compare(NotificationCenter.history.length, 1);
                choose("clock-timer-start");
                compare(Store.clockTimerState, "running");
                compare(Store.clockTimerRemainingSeconds, 1);
            }
            function test_deadline_catches_up_and_honors_do_not_disturb() {
                NotificationCenter.doNotDisturb = true;
                Store.setClockTimerDuration(25);
                Store.startClockTimer();
                Store.clockTimerDeadline = Date.now() - 10000;
                Store.updateClockTimer();
                compare(Store.clockTimerState, "finished");
                compare(Store.clockTimerRemainingMs, 0);
                compare(completed.count, 1);
                compare(NotificationCenter.history.length, 1);
                compare(NotificationCenter.history[0].body, "Your 00:00:25 timer is complete.");
                compare(NotificationCenter.toast, null);
                Store.updateClockTimer();
                compare(completed.count, 1);
            }
            function test_reset_cancels_completion() {
                Store.setClockTimerDuration(1);
                choose("clock-timer-start");
                choose("clock-timer-reset");
                wait(1250);
                compare(Store.clockTimerState, "idle");
                compare(Store.clockTimerRemainingSeconds, 1);
                compare(completed.count, 0);
                compare(NotificationCenter.history.length, 0);
            }
            function test_popup_height_follows_content_and_screen_limits() {
                popupHost.visible = true;
                nativePopup.kind = "time";
                wait(100);
                verify(nativePopup.visible);
                const widget = control("clock-popup-widget", nativePopup.contentItem);
                compare(widget.advancedTimer, false);
                widget.advancedTimer = true;
                wait(30);
                const available = Math.max(180, popupHost.screen.height - 95);
                compare(nativePopup.implicitHeight, Math.min(available, Math.max(198, widget.implicitHeight + 16)));
                const expanded = nativePopup.implicitHeight;
                widget.advancedTimer = false;
                wait(50);
                verify(nativePopup.implicitHeight < expanded);
                for (const edge of ["top", "bottom", "left", "right"]) {
                    nativePopup.barPosition = edge;
                    wait(20);
                    verify(nativePopup.visible);
                }
            }
            function test_advanced_back_scrolling_and_live_clock() {
                const expandedHeight = first.item.implicitHeight;
                choose("clock-timer-back");
                verify(!first.item.advancedTimer);
                verify(control("clock-live-time").visible);
                verify(first.item.implicitHeight < expandedHeight);
                choose("clock-timer-advanced");
                verify(first.item.advancedTimer);
                verify(!control("clock-live-time").visible);
                first.height = 180;
                const viewport = control("clock-timer-viewport");
                verify(viewport.contentHeight > viewport.height);
                const button = control("clock-timer-start");
                viewport.contentY = Math.max(0, button.mapToItem(viewport.contentItem, 0, 0).y - 20);
                wait(30);
                const position = button.mapToItem(viewport, 0, 0);
                verify(position.y >= 0 && position.y + button.height <= viewport.height + 1);
                const before = control("clock-live-time").text;
                tryVerify(() => control("clock-live-time").text !== before, 1500);
            }
            function test_z_preview() {
                first.item.grabToImage(function(result) {
                    previewSaved = result.saveToFile("/tmp/rusticq-clock-timer.png");
                });
                tryVerify(() => previewSaved, 1500);
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-clock-timer-') as folder:
        root = Path(folder)
        root.chmod(0o700)
        for name in ('config', 'components', 'services', 'assets', 'modules'):
            shutil.copytree(ROOT / name, root / name)
        (root / 'user-settings.json').write_text('{}')
        (root / 'scripts').mkdir()
        (root / 'scripts/rustiq-notification-doctor.py').write_text(
            'import json\nprint(json.dumps({"state":"free","owner":"isolated test"}))\n')
        home = root / 'home'
        home.mkdir()
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder, HOME=str(home),
                   XDG_STATE_HOME=str(root / 'state'), XDG_DATA_HOME=str(root / 'data'),
                   XDG_CACHE_HOME=str(root / 'cache'),
                   DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(root / 'missing-session-bus'))
        try:
            output = run_qml(root, env, QML)
        except subprocess.TimeoutExpired as exc:
            print((exc.stdout or b'').decode(errors='replace'))
            print((exc.stderr or b'').decode(errors='replace'))
            raise
        summary = re.search(r'TIMER RESULTS (\d+) passed, (\d+) failed', output)
        assert summary and int(summary[1]) >= 8 and int(summary[2]) == 0, output
        assert json.loads((root / 'user-settings.json').read_text()) == {}
    print('PASS: timer input, presets, pause/resume/reset, deadline catch-up, popup lifetime, shared state, notifications, DND and small-height scrolling')


if __name__ == '__main__':
    main()
