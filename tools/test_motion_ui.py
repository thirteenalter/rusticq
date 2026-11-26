#!/usr/bin/env python3
"""Offscreen motion lifecycle, loader retention, instant mode and persistence."""
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

from test_clock_ui import run_qml

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "components"
import "modules/settings/pages"

ShellRoot {
    id: suite
    property bool desired: false
    MotionLoader {
        id: lazy
        shown: suite.desired
        Item {
            readonly property bool presented: childMotion.presented
            SurfaceMotion { id: childMotion; shown: suite.desired; target: parent }
        }
    }
    Window {
        id: window
        visible: true
        width: 720; height: 720
        color: Theme.background
        Rectangle { id: surface; width: 120; height: 32; color: Theme.accent }
        SurfaceMotion { id: motion; target: surface; edge: "left" }
        Loader {
            id: appearance
            x: 12; y: 60; width: 696
            sourceComponent: SettingsAppearancePage {}
        }
        Loader {
            id: iconEditor
            x: 12; y: 60; width: 696
            active: false
            sourceComponent: BarIconSizeEditor {}
        }
        TestCase {
            id: motionTests
            name: "MotionLifecycle"
            when: true
            property bool enteredBetweenFrames: false
            property bool enteredWhileAnimating: false
            property bool enteredFromLeft: false
            property bool exitedBetweenFrames: false
            Connections {
                target: motion
                function onProgressChanged() {
                    if (motion.progress <= 0 || motion.progress >= 1) return;
                    if (motion.shown) {
                        motionTests.enteredBetweenFrames = true;
                        motionTests.enteredWhileAnimating = motion.animating;
                        motionTests.enteredFromLeft = motion.offsetX < 0;
                    } else motionTests.exitedBetweenFrames = true;
                }
            }
            function init() {
                SettingsStore.animationsEnabled = false;
                motion.shown = false;
                suite.desired = false;
                lazy.keepLoaded = false;
                tryCompare(lazy, "item", null);
                SettingsStore.animationsEnabled = true;
                SettingsStore.animationStyle = "float";
                SettingsStore.barAnimationStyle = "float";
                SettingsStore.barIconSize = 16;
                iconEditor.active = false;
                appearance.visible = true;
                motion.edge = "left";
                motion.startReady = true;
                enteredBetweenFrames=false; enteredWhileAnimating=false;
                enteredFromLeft=false; exitedBetweenFrames=false;
                wait(20);
            }
            function cleanup() { console.log("MOTION TEST " + qtest_results.functionName + " failed=" + qtest_results.failed + " stage=" + motionStage); }
            function cleanupTestCase() { console.log("MOTION RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
            property string motionStage: ""
            function test_entry_exit_and_no_input_during_close() {
                motionStage="initial";
                compare(motion.presented, false);
                motion.shown = true;
                motionStage="enter presented";
                verify(motion.presented);
                motionStage="enter intermediate";
                // Observe actual frame changes; polling can miss all intermediate
                // values when another UI fixture blocks the event loop briefly.
                tryVerify(() => enteredBetweenFrames);
                motionStage="enter animation";
                verify(enteredWhileAnimating);
                verify(enteredFromLeft);
                tryCompare(surface, "enabled", true);
                motionStage="enter settled";
                tryCompare(motion, "progress", 1);
                motionStage="surface settled";
                // Binding targets settle after the progress notification.
                tryCompare(surface, "opacity", 1);
                tryCompare(surface, "scale", 1);
                tryCompare(motion, "offsetX", 0);
                motionStage="exit presented";
                motion.shown = false;
                verify(motion.presented);
                tryCompare(surface, "enabled", false);
                tryVerify(() => exitedBetweenFrames);
                motionStage="exit settled";
                tryCompare(motion, "presented", false);
                tryCompare(surface, "opacity", 0);
                compare(motion.animating, false);
            }
            function test_reopening_reverses_from_current_frame() {
                motion.shown = true;
                tryCompare(motion, "progress", 1);
                motion.shown = false;
                wait(40);
                const before = motion.progress;
                verify(before > 0 && before < 1);
                motion.shown = true;
                fuzzyCompare(motion.progress, before, 0.001);
                tryCompare(motion, "progress", 1);
                compare(surface.enabled, true);
            }
            function test_entry_waits_for_the_first_native_frame() {
                motion.startReady = false;
                motion.shown = true;
                wait(60);
                compare(motion.progress, 0);
                verify(motion.presented);
                motion.startReady = true;
                tryVerify(() => enteredBetweenFrames);
                tryCompare(motion, "progress", 1);
                motion.shown = false;
                SettingsStore.animationsEnabled = false;
                motion.startReady = false;
                motion.shown = true;
                tryCompare(motion, "progress", 1);
            }
            function test_off_settles_active_transitions_immediately() {
                motion.shown = true;
                tryVerify(() => motion.progress > 0 && motion.progress < 1);
                SettingsStore.animationsEnabled = false;
                tryCompare(motion, "progress", 1, 100);
                compare(motion.animating, false);
                compare(Theme.motionEnterDuration, 0);
                motion.shown = false;
                compare(motion.progress, 0);
                compare(motion.presented, false);
                motion.shown = true;
                compare(motion.progress, 1);
                compare(motion.animating, false);
                SettingsStore.animationsEnabled = true;
                motion.shown = false;
                wait(30);
                SettingsStore.animationsEnabled = false;
                compare(motion.progress, 0);
                compare(motion.presented, false);
            }
            function test_loader_survives_close_and_quick_reopen() {
                suite.desired = true;
                tryVerify(() => lazy.item !== null);
                const original = lazy.item;
                wait(250);
                suite.desired = false;
                compare(lazy.item, original);
                verify(lazy.active);
                wait(30);
                suite.desired = true;
                compare(lazy.item, original);
                wait(250);
                suite.desired = false;
                tryCompare(lazy, "item", null);
                suite.desired = true;
                tryVerify(() => lazy.item !== null);
                SettingsStore.animationsEnabled = false;
                suite.desired = false;
                tryCompare(lazy, "item", null, 100);
                lazy.keepLoaded = true;
                tryVerify(() => lazy.item !== null);
                const preserved = lazy.item;
                suite.desired = true;
                suite.desired = false;
                compare(lazy.item, preserved);
                lazy.keepLoaded = false;
                tryCompare(lazy, "item", null, 100);
            }
            function test_directions_and_replay() {
                SettingsStore.animationsEnabled = false;
                for (const edge of ["top", "bottom", "left", "right", "center"]) {
                    motion.edge = edge;
                    motion.shown = false;
                    compare(motion.offsetX < 0, edge === "left");
                    compare(motion.offsetX > 0, edge === "right");
                    compare(motion.offsetY < 0, edge === "top");
                    compare(motion.offsetY > 0, edge === "bottom" || edge === "center");
                }
                motion.shown = true;
                motion.replay();
                compare(motion.progress, 1);
                SettingsStore.animationsEnabled = true;
                motion.replay();
                verify(motion.progress < 1);
                tryCompare(motion, "progress", 1);
            }
            function test_motion_styles_are_distinct_and_validated() {
                SettingsStore.animationsEnabled = false;
                motion.shown = false;
                for (const style of SettingsStore.animationStyles) {
                    verify(SettingsStore.setAnimationStyle("animationStyle", style));
                    compare(motion.style, style);
                    compare(motion.offsetX !== 0, ["float", "slide", "spring"].includes(style));
                    compare(motion.surfaceScale !== 1, ["float", "zoom", "spring"].includes(style));
                    motion.shown = true;
                    compare(motion.surfaceScale, 1);
                    compare(motion.surfaceOpacity, 1);
                    motion.shown = false;
                    compare(motion.surfaceOpacity, 0);
                }
                verify(!SettingsStore.setAnimationStyle("barIconSize", "fade"));
                verify(!SettingsStore.setAnimationStyle("barAnimationStyle", "unknown"));
                SettingsStore.animationsEnabled = true;
                SettingsStore.setAnimationStyle("animationStyle", "spring");
                motion.shown = true;
                tryCompare(motion, "animating", false);
                compare(motion.progress, 1);
                motion.shown = false;
                tryCompare(motion, "presented", false);
                const fade = findChild(appearance, "animationStyle-fade");
                verify(fade !== null);
                waitForRendering(appearance);
                mouseClick(fade);
                compare(SettingsStore.animationStyle, "fade");
            }
            function test_icon_size_exact_pixels_limits_and_editor() {
                appearance.visible = false;
                iconEditor.active = true;
                tryVerify(() => iconEditor.item !== null);
                const input = findChild(iconEditor.item, "barIconSizeInput");
                const slider = findChild(iconEditor.item, "barIconSizeSlider");
                window.requestActivate();
                input.forceActiveFocus();
                input.selectAll();
                keyClick(Qt.Key_Backspace);
                input.insert(0, "27");
                keyClick(Qt.Key_Return);
                compare(SettingsStore.barIconSize, 27);
                compare(Theme.barSymbolSize, 27);
                SettingsStore.uiFontScale = 1.2;
                compare(Theme.barSymbolSize, 27);
                SettingsStore.uiFontScale = 1;
                verify(Theme.barIconSlotSize >= 27);
                verify(Theme.barRailItemSize >= 39);
                mouseClick(slider, 9, slider.height / 2);
                compare(SettingsStore.barIconSize, 12);
                mouseClick(slider, slider.width - 9, slider.height / 2);
                compare(SettingsStore.barIconSize, 32);
                verify(!SettingsStore.setBarIconSize(NaN));
                verify(!SettingsStore.setBarIconSize(Infinity));
                SettingsStore.setBarIconSize(-20);
                compare(SettingsStore.barIconSize, 12);
                SettingsStore.setBarIconSize(100);
                compare(SettingsStore.barIconSize, 32);
                mouseClick(findChild(iconEditor.item, "barIconSizeReset"));
                compare(SettingsStore.barIconSize, 16);
            }
            function test_z_appearance_toggle_keyboard_and_save() {
                const toggle = findChild(appearance, "interfaceAnimationsToggle");
                verify(toggle !== null);
                compare(toggle.checked, true);
                waitForRendering(appearance);
                mouseClick(toggle);
                compare(SettingsStore.animationsEnabled, false);
                compare(toggle.checked, false);
                window.requestActivate();
                toggle.forceActiveFocus();
                tryCompare(toggle, "activeFocus", true);
                keyClick(Qt.Key_Space);
                compare(SettingsStore.animationsEnabled, true);
                mouseClick(toggle);
                compare(SettingsStore.animationsEnabled, false);
                SettingsStore.save();
                SettingsStore.setBarIconSize(24);
                SettingsStore.setAnimationStyle("barAnimationStyle", "spring");
                wait(100);
                grabImage(window.contentItem).save("/tmp/rusticq-motion-settings.png");
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-motion-ui-') as folder:
        root = Path(folder)
        for name in ('config', 'components', 'services', 'assets', 'modules'):
            shutil.copytree(ROOT / name, root / name)
        (root / 'user-settings.json').write_text('{"showWifi":true}')
        (root / 'scripts').mkdir()
        (root / 'scripts/rusticq-appearance.py').write_text(
            'import json\nprint(json.dumps({"ok":True,"fonts":["Poppins"]}))\n')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder)
        output = run_qml(root, env, QML)
        summary = re.search(r'MOTION RESULTS (\d+) passed, (\d+) failed', output)
        assert summary and int(summary[1]) >= 9 and int(summary[2]) == 0, output
        saved = json.loads((root / 'user-settings.json').read_text())
        assert saved['animationsEnabled'] is False and saved['showWifi'] is True, saved
        assert saved['barIconSize'] == 24 and saved['barAnimationStyle'] == 'spring', saved
        reload_qml = '''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot {
    TestCase {
        when: true
        function test_reload() {
            compare(SettingsStore.animationsEnabled, false);
            compare(Theme.motionFastDuration, 0);
            compare(SettingsStore.showWifi, true);
            compare(SettingsStore.barIconSize, 24);
            compare(Theme.barSymbolSize, 24);
            compare(SettingsStore.barAnimationStyle, "spring");
            console.log("MOTION RELOAD PASS");
        }
    }
}
'''
        assert 'MOTION RELOAD PASS' in run_qml(root, env, reload_qml)
    print('PASS: surface entry/exit, interrupted motion, instant mode, loader retention, directions and setting save/reload')


def native_smoke():
    """Briefly show native Wayland surfaces; never invoke device/power actions."""
    if not os.environ.get('WAYLAND_DISPLAY'):
        raise SystemExit('A Wayland session is required')
    source = '''import QtQuick
import QtTest
import Quickshell
import "config"
import "components"
import "services"
import "modules/main"
import "modules/bar"
import "modules/power"
import "modules/ai"
ShellRoot {
    PanelWindow {
        id: host
        screen: Quickshell.screens[0]
        anchors { top: true; right: true }
        margins { top: 72; right: 16 }
        implicitWidth: 400; implicitHeight: 32
        property int barHeight: 32
        exclusionMode: ExclusionMode.Ignore
        color: Theme.background
        Text { anchors.centerIn: parent; text: "RusticQ animation preview"; color: Theme.foreground }
    }
    IndicatorPopup { id: popup; hostWindow: host; onDismissed: kind = "" }
    NotificationToasts { id: toast; screen: host.screen }
    SystemOsd { id: osd; screen: host.screen }
    MotionLoader { id: sidebar; shown: Store.sidebarVisible; BarWrapper { screen: host.screen } }
    MotionLoader { id: power; shown: Store.powerMenuVisible; PowerMenu { screen: host.screen } }
    MotionLoader { id: launcher; shown: Store.launcherVisible; LauncherOverlay { screen: host.screen } }
    MotionLoader { id: ai; shown: Store.aiVisible; keepLoaded: !SettingsStore.lowMemoryShellMode; AiWrapper { screen: host.screen } }
    TestCase {
        name: "NativeMotion"
        when: true
        function init() {
            SettingsStore.animationsEnabled = true;
            SettingsStore.barAnimationStyle = "float";
            Store.sidebarVisible = false;
            Store.powerMenuVisible = false;
            Store.launcherVisible = false;
            Store.aiVisible = false;
            SettingsStore.lowMemoryShellMode = true;
            Store.osdVisible = false;
            NotificationCenter.toast = null;
            popup.kind = "";
            wait(250);
        }
        function cleanup() { console.log("NATIVE MOTION TEST " + qtest_results.functionName + " failed=" + qtest_results.failed); }
        function cleanupTestCase() { console.log("NATIVE MOTION RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
        function test_popup_all_styles_and_retained_content() {
            for (const style of SettingsStore.animationStyles) {
                SettingsStore.barAnimationStyle = style;
                popup.kind = "ethernet";
                tryCompare(popup, "visible", true);
                wait(250);
                popup.kind = "";
                verify(popup.presented);
                compare(popup.grabFocus, false);
                compare(popup.contentKind, "ethernet");
                tryCompare(popup, "visible", false);
            }
        }
        function test_ai_persists_hidden_and_low_memory_unloads() {
            SettingsStore.lowMemoryShellMode = false;
            Store.aiVisible = true;
            tryVerify(() => ai.item !== null);
            wait(300);
            verify(ai.item.visible);
            const panel = ai.item;
            Store.aiVisible = false;
            tryCompare(panel, "visible", false);
            compare(ai.item, panel);
            SettingsStore.lowMemoryShellMode = true;
            tryCompare(ai, "item", null);
        }
        function test_popup_reopen_and_instant_off() {
            popup.kind = "ethernet";
            wait(250);
            popup.kind = "";
            wait(30);
            popup.kind = "ethernet";
            verify(popup.presented);
            wait(250);
            popup.kind = "";
            SettingsStore.animationsEnabled = false;
            tryCompare(popup, "visible", false, 100);
            popup.kind = "ethernet";
            tryCompare(popup, "visible", true, 100);
            popup.kind = "";
            tryCompare(popup, "visible", false, 100);
        }
        function test_layers_release_and_unload() {
            for (const entry of [{key:"sidebarVisible", loader:sidebar},
                                 {key:"powerMenuVisible", loader:power},
                                 {key:"launcherVisible", loader:launcher}]) {
                Store[entry.key] = true;
                tryVerify(() => entry.loader.item !== null);
                wait(300);
                verify(entry.loader.item.visible);
                const window = entry.loader.item;
                Store[entry.key] = false;
                compare(window.focusable, false);
                verify(entry.loader.active);
                tryCompare(entry.loader, "item", null);
            }
        }
        function test_notification_and_osd_close_frames() {
            NotificationCenter.toast = {app:"RusticQ", tag:"Preview", glyph:"\\ue7f4", when:"Now",
                title:"Smooth transitions", body:"Temporary animation preview", actions:[]};
            tryCompare(toast, "visible", true);
            wait(250);
            NotificationCenter.toast = null;
            verify(toast.visible);
            verify(toast.notice !== null);
            tryCompare(toast, "visible", false);
            compare(toast.notice, null);
            Store.osdScreen = host.screen;
            Store.osdLabel = "Animation preview";
            Store.osdPercent = 50;
            Store.osdVisible = true;
            tryCompare(osd, "visible", true);
            wait(250);
            Store.osdVisible = false;
            verify(osd.visible);
            tryCompare(osd, "visible", false);
        }
    }
}
'''
    with tempfile.TemporaryDirectory(prefix='rq-motion-native-') as folder:
        root = Path(folder)
        for name in ('config', 'components', 'services', 'assets', 'modules'):
            shutil.copytree(ROOT / name, root / name)
        (root / 'user-settings.json').write_text('{"animationsEnabled":true,"showNotifications":true}')
        (root / 'app-usage.json').write_text('{}')
        # Keep previews local; never claim or replace the real notification bus.
        (root / 'services/NotificationCenter.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property var toast: null
    property var history: []
    property var displayHistory: []
    property var expandedApps: ({})
    property int unread: 0
    property bool receivesSystemNotifications: true
    property bool doNotDisturb: false
    property bool groupByApp: false
    property string serverState: "owned"
    property string serverOwner: "Preview"
    property string serverAdvice: ""
    function markRead() {}
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM='wayland', QT_QPA_PLATFORMTHEME='generic',
                   XDG_STATE_HOME=str(root / 'state'), XDG_DATA_HOME=str(root / 'data'),
                   XDG_CACHE_HOME=str(root / 'cache'))
        output = run_qml(root, env, source)
        summary = re.search(r'NATIVE MOTION RESULTS (\d+) passed, (\d+) failed', output)
        assert summary and int(summary[1]) >= 6 and int(summary[2]) == 0, output
    print('PASS: native Wayland popup styles, quick reopen, focus release, layer unload, toast retention and OSD')


if __name__ == '__main__':
    native_smoke() if '--native-smoke' in sys.argv[1:] else main()
