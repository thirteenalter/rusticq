#!/usr/bin/env python3
"""Brief real Wayland RAGE preview and scoped session IPC test.

Requires explicit --run and access to the user's compositor. Creates no config
files, changes no global blur or device state, and always disables its own rules.
Never presents a real auth dialog or locks the session.
"""
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from test_clock_ui import run_qml
from test_glassmorphism_ui import fixture

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "components"
import "services"
import "modules/main"
import "modules/bar"
import "modules/power"
import "modules/ai"
import "modules/settings"
ShellRoot {
    Window {
        id: contrast
        visible:true;width:740;height:180;color:"#f3ead8"
        BarSurfacePreview { id:contrastPreview;anchors.fill:parent;showBackdrop:false }
    }
    PanelWindow {
        id: host
        screen: Quickshell.screens[0]
        anchors { top: true; right: true }
        margins { top: 72; right: 16 }
        implicitWidth: 400; implicitHeight: 48
        property int barHeight: 48
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        GlassSurface { id: sample; anchors.fill: parent
            Text { anchors.centerIn: parent; text: "RAGE · native preview"; color: Theme.foreground }
        }
    }
    IndicatorPopup { id: popup; hostWindow: host; onDismissed: kind="" }
    NotificationToasts { id: toast; screen: host.screen }
    SystemOsd { id: osd; screen: host.screen }
    SettingsWindow { id: settings }
    RusticDock { id: dock; screen: host.screen }
    DesktopWidgetWindow { id: widget; screen: host.screen; kind: "clock" }
    MotionLoader { id: sidebar; shown: Store.sidebarVisible; BarWrapper { screen: host.screen } }
    MotionLoader { id: power; shown: Store.powerMenuVisible; PowerMenu { screen: host.screen } }
    MotionLoader { id: launcher; shown: Store.launcherVisible; LauncherOverlay { screen: host.screen } }
    MotionLoader { id: ai; shown: Store.aiVisible; AiWrapper { screen: host.screen } }
    TestCase {
        name: "RageNative"
        when: true
        function cleanupTestCase() { console.log("RAGE NATIVE RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
        function test_native_surfaces_toggle_without_recreation() {
            SettingsStore.animationsEnabled=false;
            SettingsStore.showDock=true; SettingsStore.dockRunningApps=false;
            SettingsStore.desktopClock=true;
            Store.settingsScreen=host.screen; Store.settingsVisible=true;
            const original=settings;
            tryCompare(settings,"visible",true);
            for (const style of ["frosted","crystal","tinted"]) {
                SettingsStore.glassmorphismEnabled=true;
                SettingsStore.setGlassPreset(style);
                Store.glassBlurActive=ACTUAL_BLUR_ACTIVE;
                verify(sample.color.a < 1); compare(sample.opacity,1);
                compare(settings,original);
                compare(settings.color,Theme.glassWindow);
                verify(dock.visible); verify(widget.visible);
                popup.kind="ethernet";
                tryCompare(popup,"visible",true);
                for (const entry of [{key:"sidebarVisible",loader:sidebar},{key:"powerMenuVisible",loader:power},
                                     {key:"launcherVisible",loader:launcher},{key:"aiVisible",loader:ai}]) {
                    Store[entry.key]=true; tryVerify(() => entry.loader.item !== null);
                    tryCompare(entry.loader.item,"visible",true); wait(65);
                    Store[entry.key]=false; tryCompare(entry.loader,"item",null);
                }
                SettingsStore.glassmorphismEnabled=false;
                compare(sample.color,Theme.background); compare(settings.color,Theme.background);
                compare(settings,original);
                popup.kind="";
            }
            NotificationCenter.toast={app:"RusticQ",tag:"RAGE",glyph:"\\ue7f4",when:"Now",
                title:"Adaptive glass",body:"Temporary native preview",actions:[]};
            SettingsStore.glassmorphismEnabled=true;
            tryCompare(toast,"visible",true);
            Store.osdScreen=host.screen; Store.osdLabel="RAGE preview"; Store.osdPercent=60; Store.osdVisible=true;
            tryCompare(osd,"visible",true); wait(150);
            NotificationCenter.toast=null; Store.osdVisible=false; Store.settingsVisible=false;
            SettingsStore.showDock=false; SettingsStore.desktopClock=false;
            SettingsStore.glassmorphismEnabled=false;
            tryCompare(findChild(sample,"glassSurfaceEffects"),"item",null);
            SettingsStore.glassmorphismEnabled=true;
            SettingsStore.barMode="separated";
            SettingsStore.setBarSurfacePreset("floating");SettingsStore.barSegmentRadius=16;
            waitForRendering(contrastPreview);
            grabImage(contrast.contentItem).save("/tmp/rusticq-rage-native-light.png");
            contrast.color="#101114";
            waitForRendering(contrastPreview);
            grabImage(contrast.contentItem).save("/tmp/rusticq-rage-native-dark.png");
            SettingsStore.glassmorphismEnabled=false;
            GlassService.initialize();
            tryCompare(Store,"glassBackend","hyprland");
            verify(Store.glassBlurSupported);
            tryVerify(() => Store.glassCompositorStatus.indexOf("disabled") >= 0);
            SettingsStore.glassmorphismEnabled=true;
            tryVerify(() => Store.glassCompositorStatus.indexOf("disabled") < 0);
            compare(Store.glassBlurActive, ACTUAL_BLUR_ACTIVE);
            SettingsStore.glassPerformanceMode=true;
            tryVerify(() => Store.glassCompositorStatus.indexOf("disabled") >= 0);
            compare(Store.glassBlurActive,false);
            SettingsStore.glassmorphismEnabled=false;
            wait(350);
        }
    }
}
'''


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true', required=True)
    parser.parse_args()
    assert os.environ.get('WAYLAND_DISPLAY'), 'Wayland session required'
    spec = importlib.util.spec_from_file_location('rage_native', ROOT / 'scripts/rusticq-glass.py')
    backend = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(backend)
    status = backend.capabilities()
    print('Actual capabilities:', json.dumps(status))
    assert status['supported'], 'This native test requires the audited Hyprland Lua adapter'
    options = ['decoration:blur:enabled', 'decoration:blur:size', 'decoration:blur:passes']
    before = {key: backend.run(['hyprctl', '-j', 'getoption', key]) for key in options}
    owner = 'rage-native-' + str(os.getpid())
    request = dict(enabled=True, blur=True, performance=False, lowMemory=False, owner=owner)
    try:
        applied = backend.apply(request)
        print('Session apply:', json.dumps(applied))
        assert applied.get('rulesEnabled') is True and applied['ok']
        assert backend.run(['hyprctl','eval','assert(_G.__rusticq_rage_active == true)']) == 'ok'
        assert backend.apply(dict(request,barBlur=False))['ok']
        assert backend.run(['hyprctl','eval','assert(_G.__rusticq_rage_bar_blur == false)']) == 'ok'
        # Old service destruction cannot disable a replacement generation.
        backend.apply(dict(request, enabled=False, owner='stale-generation'), cleanup=True)
        assert backend.run(['hyprctl','eval','assert(_G.__rusticq_rage_active == true)']) == 'ok'
        with tempfile.TemporaryDirectory(prefix='rq-rage-native-') as folder:
            root = fixture(folder)
            env = dict(os.environ, QT_QPA_PLATFORM='wayland', QT_QPA_PLATFORMTHEME='generic',
                       QT_QUICK_BACKEND='software', XDG_STATE_HOME=str(root/'state'), XDG_CACHE_HOME=str(root/'cache'))
            output = run_qml(root, env, QML.replace('ACTUAL_BLUR_ACTIVE', json.dumps(applied['active'])))
            match = re.search(r'RAGE NATIVE RESULTS (\d+) passed, (\d+) failed', output)
            assert match and int(match[2]) == 0, output
            # Compile/start the real entry point in an isolated tree. Stub only
            # external ownership/actions which would conflict with the running
            # desktop, not the visual modules or the RAGE adapter.
            (root/'modules/main/NativePolkitAgent.qml').write_text('import QtQuick\nItem {}\n')
            (root/'scripts/rusticq-wallpaper.py').write_text('print(\'{"ok":true}\')\n')
            (root/'scripts/rusticq-wifi-advanced.py').write_text('print(\'{"ok":true}\')\n')
            source = (ROOT/'shell.qml').read_text()
            source = source[:source.rfind('}')] + '''
    Timer { interval: 950; running: true; onTriggered: SettingsStore.glassmorphismEnabled=false }
    Timer { interval: 1800; running: true; onTriggered: Qt.quit() }
}
'''
            (root/'user-settings.json').write_text('{"glassmorphismEnabled":true,"animationsEnabled":false}')
            output = run_qml(root, env, source)
            assert 'Configuration Loaded' in output
            log = re.search(r'Saving logs to "([^"]+)"', output)
            assert log
            decoded = subprocess.check_output(['qs','log',log[1],'--no-color'], text=True)
            assert not re.search(r'(TypeError|ReferenceError|Binding loop|Could not load)', decoded)
            print('PASS: isolated real shell.qml startup and qs log inspection')
        print('PASS: real Wayland native surfaces/presets, popup lifecycle, secure generation cleanup')
    finally:
        disabled = backend.apply(dict(request, enabled=False), cleanup=True)
        assert disabled['ok']
        after = {key: backend.run(['hyprctl', '-j', 'getoption', key]) for key in options}
        assert before == after, 'Global blur settings changed'
        assert backend.run(['hyprctl','eval','assert(_G.__rusticq_rage_active == false)']) == 'ok'
        assert backend.run(['hyprctl','configerrors']).lower() in ('', 'ok', 'no errors', '[]')
        print('PASS: cleanup complete; global blur enabled/size/passes unchanged; no config errors')


if __name__ == '__main__':
    main()
