#!/usr/bin/env python3
"""Render actual bar geometry with a headless PanelWindow and isolated devices."""
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
import QtTest
import Quickshell
import "config"
import "modules/main"
import "modules/settings/pages"
import "fixtures"
ShellRoot {
    QtObject { id: largeScreen; property int width: 1440; property int height: 980; property string name: "large" }
    QtObject { id: smallScreen; property int width: 900; property int height: 700; property string name: "small" }
    Bar { id: first; screen: largeScreen }
    Bar { id: second; screen: smallScreen }
    Window {
        id: scene; visible: true; width: 1440; height: 1100; color: Theme.background
        BarPaddingEditor { id: editor; x: 220; y: 10; width: 620 }
        TestCase {
            when: true
            property bool previewSaved: false
            readonly property var modes: ["compact", "clean-compact", "separated", "professional", "simple"]
            function descendants(item) {
                let all = [item];
                for (const child of item.children) all = all.concat(descendants(child));
                return all;
            }
            function part(name, view) {
                const item = descendants(view || first.contentItem).find(child => child.objectName === name);
                if (!item) console.error("MISSING BAR CONTROL", name, descendants(view || first.contentItem).map(child => child.objectName).join(","));
                verify(item !== undefined, name); return item;
            }
            function check(value, message) { if (!value) console.error("BAR FAILURE", message); verify(value, message); }
            function eq(value, expected, message) {
                if (value !== expected) console.error("BAR MISMATCH", message, value, expected);
                compare(value, expected, message);
            }
            function zones() { return descendants(first.contentItem).filter(item => item.activeKeys !== undefined); }
            function railChecks() {
                const viewport = part("bar-rail-viewport");
                const top = part("bar-rail-zone-left"), mid = part("bar-rail-zone-center"), bottom = part("bar-rail-zone-right");
                for (const zone of [top, mid, bottom]) {
                    if (!zone.activeKeys.length) continue;
                    check(zone.x >= -.1 && zone.x + zone.width <= viewport.width + .1, "zone stays inside rail");
                    for (const loader of descendants(zone).filter(item => item.objectName.startsWith("bar-rail-item-"))) {
                        const pos = loader.mapToItem(viewport.contentItem, 0, 0);
                        check(pos.x >= -.1 && pos.x + loader.width <= viewport.width + .1, "icon slot fits rail");
                        check(loader.height >= 32, "consistent vertical hit area");
                    }
                }
                if (top.height && mid.height) check(mid.y >= top.y + top.height + 11.9, "top/middle do not overlap");
                if (mid.height && bottom.height) check(bottom.y >= mid.y + mid.height + 11.9, "middle/bottom do not overlap");
                if (top.height && bottom.height) check(bottom.y >= top.y + top.height + 11.9, "top/bottom do not overlap");
                let keys = [];
                for (const zone of zones()) keys = keys.concat(zone.activeKeys);
                eq(new Set(keys).size, keys.length, "no duplicate hidden-orientation widgets");
            }
            function initTestCase() {
                first.contentItem.parent = scene.contentItem; first.contentItem.x = 8;
                second.contentItem.parent = scene.contentItem; second.contentItem.x = 100;
            }
            function init() {
                SettingsStore.barPopupsOnHover = false;
                second.contentItem.visible = true;
                SettingsStore.barIconSize = 16;
                SettingsStore.barVisible = true; SettingsStore.barAutoHide = false;
                SettingsStore.barMode = "compact"; SettingsStore.barPosition = "right";
                SettingsStore.barPaddingOverrides = ({}); SettingsStore.marginOverrides = ({});
                SettingsStore.barIconVisibilityProfiles = ({}); SettingsStore.barSpacingOverrides = ({});
                SettingsStore.barIconPlacementsByMode = ({compact:{time:"center"}});
                SettingsStore.clockDisplayMode = "auto"; SettingsStore.calendarDisplayMode = "auto";
                SettingsStore.quickModesAutoHide = true;
                SettingsStore.showMenuBar = true; SettingsStore.showMenuView = true;
                SettingsStore.showMicrophoneStatus = true; SettingsStore.showDownloadSpeed = true;
                SettingsStore.showUploadSpeed = true;
                largeScreen.height = 980; smallScreen.height = 700;
                first.closeMini(); second.closeMini(); wait(40);
            }
            function cleanup() { console.log("BAR TEST " + qtest_results.functionName + " failed=" + qtest_results.failed); }
            function cleanupTestCase() { console.log("BAR RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
            function test_all_modes_edges_and_duplicate_widgets() {
                const widths = [52,44,60,60,48];
                const heights = [36,36,40,44,38];
                for (let index = 0; index < modes.length; index++) {
                    SettingsStore.barMode = modes[index];
                    for (const edge of ["left","right","top","bottom"]) {
                        SettingsStore.barPosition = edge; wait(30);
                        if (edge === "left" || edge === "right") {
                            eq(first.width, widths[index], "mode rail width");
                            eq(first.width, second.width, "monitor-independent width");
                            railChecks();
                        } else {
                            eq(first.height, heights[index], "original mode height");
                            let keys = [];
                for (const zone of zones()) keys = keys.concat(zone.activeKeys);
                            eq(new Set(keys).size, keys.length, "horizontal widget uniqueness");
                            check(!descendants(first.contentItem).some(item => item.objectName === "bar-rail-viewport"), "inactive rail unloaded");
                        }
                    }
                }
            }
            function test_padding_edges_and_resizing_both_monitors() {
                for (const edge of ["left","right","top","bottom"]) SettingsStore.setBarPadding(edge, 32, false);
                wait(40); eq(first.width, 96, "max sidebar padding"); eq(second.width, 96, "second monitor padding");
                railChecks();
                const viewport = part("bar-rail-viewport");
                const origin = viewport.mapToItem(first.contentItem, 0, 0);
                eq(origin.x, 32, "left inner inset"); eq(origin.y, 32, "top inner inset");
                eq(viewport.width, 32, "padding never squeezes controls");
                SettingsStore.barPosition = "top"; wait(40);
                eq(first.height, 96, "max top/bottom expands horizontal bar");
                eq(second.height, first.height, "horizontal geometry shared");
                check(!SettingsStore.setBarPadding("invalid", 8), "invalid edge rejected");
                check(!SettingsStore.setBarPadding("top", NaN), "invalid value rejected");
            }
            function test_icon_pixel_sizes_all_layouts_and_edges() {
                SettingsStore.animationsEnabled = false;
                for (const size of [12, 24, 32]) {
                    SettingsStore.setBarIconSize(size, false);
                    for (const mode of modes) {
                        SettingsStore.barMode = mode;
                        for (const edge of ["left", "right", "top", "bottom"]) {
                            SettingsStore.barPosition = edge;
                            wait(30);
                            if (edge === "left" || edge === "right") railChecks();
                            const icons = descendants(first.contentItem).filter(item => item.visible
                                && item.icon !== undefined && item.font !== undefined);
                            check(icons.length > 3, "bar contains rendered icons");
                            for (const icon of icons) eq(icon.font.pixelSize, size, "exact pixel size for each bar icon");
                            if (edge === "left" || edge === "right")
                                eq(first.width, second.width, "same rail width across monitors");
                            else eq(first.height, second.height, "same bar height across monitors");
                        }
                    }
                }
                SettingsStore.barIconSize = 16;
                SettingsStore.animationsEnabled = true;
            }
            function test_short_screen_scroll_centering_and_expanded_quick_modes() {
                SettingsStore.quickModesAutoHide = false;
                largeScreen.height = 220; wait(60);
                railChecks();
                const viewport = part("bar-rail-viewport");
                check(viewport.contentHeight > viewport.height, "short rail scrolls");
                const quick = descendants(first.contentItem).find(item => item.buttonWidth !== undefined);
                check(quick.vertical && quick.expanded, "vertical quick modes expanded");
                check(quick.implicitWidth <= 32 && quick.implicitHeight > 32, "quick modes expand vertically");
                viewport.contentY = viewport.contentHeight - viewport.height; wait(30);
                const bottom = part("bar-rail-zone-right");
                const bottomEdge = bottom.mapToItem(viewport, 0, bottom.height);
                check(Math.abs(bottomEdge.y - viewport.height) < 1, "bottom remains reachable");
                SettingsStore.quickModesAutoHide = true;
                largeScreen.height = 1800; wait(50);
                const middle = part("bar-rail-zone-center");
                check(Math.abs(middle.y + middle.height / 2 - viewport.height / 2) < 1, "middle centered when room permits");
            }
            function test_custom_clock_and_popup_coordinates_fit_rail() {
                SettingsStore.clockDisplayMode = "both";
                SettingsStore.clockFormat = "HH:mm dddd, d MMMM yyyy";
                SettingsStore.setBarPadding("left", 3, false); SettingsStore.setBarPadding("right", 27, false);
                wait(60); railChecks();
                const viewport = part("bar-rail-viewport");
                const loader = part("bar-rail-item-wifi");
                viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - viewport.height, loader.mapToItem(viewport.contentItem, 0, 0).y - 20));
                wait(30);
                mouseClick(loader, loader.width / 2, loader.height / 2);
                eq(first.miniKind, "wifi", "popup opens from moved icon");
                check(Math.abs(first.miniAnchorX - (3 + 16)) < 1, "popup tracks asymmetric padding");
                check(first.miniAnchorY >= 8 && first.miniAnchorY <= first.height, "popup y within bar");
            }
            function test_quick_modes_bottom_trigger_stays_in_place() {
                largeScreen.height = 1800; wait(40);
                const quick = descendants(first.contentItem).find(item => item.buttonWidth !== undefined);
                quick.revealed = false; quick.focus = false; wait(30);
                const trigger = part("quick-modes-trigger");
                const before = trigger.mapToItem(first.contentItem,0,0).y;
                quick.reveal(); wait(30);
                check(quick.expandUp, "bottom group expands upward");
                check(Math.abs(trigger.mapToItem(first.contentItem,0,0).y - before) < 1, "trigger remains under pointer");
            }
            function test_editor_per_mode_reset_and_keyboard() {
                const slider = part("bar-padding-left", editor);
                mouseClick(slider, slider.width - 1, slider.height / 2); wait(30);
                eq(SettingsStore.paddingFor("left"), 32, "editor maximum");
                SettingsStore.barMode = "simple"; wait(30);
                eq(SettingsStore.paddingFor("left"), 8, "other layout retains default");
                SettingsStore.setBarPadding("left", 18);
                SettingsStore.barMode = "compact"; wait(30);
                eq(SettingsStore.paddingFor("left"), 32, "layout padding retained");
                const reset = part("bar-padding-reset", editor);
                mouseClick(reset, reset.width / 2, reset.height / 2); wait(30);
                eq(SettingsStore.paddingFor("left"), 10, "reset current mode");
                SettingsStore.barMode = "simple"; eq(SettingsStore.paddingFor("left"), 18, "reset leaves other mode intact");
                slider.forceActiveFocus(); keyClick(Qt.Key_Left);
                eq(SettingsStore.paddingFor("left"), 17, "keyboard step");
            }
            function test_hover_opens_and_leaving_does_not_close() {
                // The two monitor fixtures share one test scene, so keep the
                // second monitor's pixels from covering the first hit target.
                second.contentItem.visible=false;
                SettingsStore.barPosition="top";
                SettingsStore.barMode="professional";
                wait(40);
                const wifi=part("bar-item-wifi");
                mouseMove(scene,1000,1000);
                mouseMove(wifi,wifi.width/2,wifi.height/2);wait(180);
                eq(first.miniKind,"","click mode does not open on hover");
                mouseMove(scene,1000,1000);
                SettingsStore.barPopupsOnHover=true;
                mouseMove(wifi,wifi.width/2,wifi.height/2);wait(180);
                eq(first.miniKind,"wifi","hover opens Wi-Fi");
                mouseMove(scene,1000,1000);wait(180);
                eq(first.miniKind,"wifi","pointer leaving must keep the popup open");
                first.openMini("wifi",100,20);
                eq(first.miniKind,"wifi","hover trigger click does not toggle closed");
                first.closeMini();eq(first.miniKind,"","outside dismissal closes explicitly");
                for(const edge of ["left","right"]) {
                    SettingsStore.barPosition=edge;wait(40);
                    const tile=part("bar-rail-item-wifi");
                    mouseMove(scene,1000,1000);
                    mouseMove(tile,tile.width/2,tile.height/2);wait(180);
                    eq(first.miniKind,"wifi","vertical hover opens Wi-Fi");
                    mouseMove(scene,1000,1000);wait(50);
                    eq(first.miniKind,"wifi","vertical hover stays open");
                    first.closeMini();
                }
            }
            function test_z_save_and_previews() {
                for (let i=0; i<modes.length; i++) {
                    SettingsStore.barMode = modes[i];
                    SettingsStore.setBarPadding("left", i + 9, false);
                    SettingsStore.setBarPadding("right", i + 10, false);
                }
                SettingsStore.barMode = "compact"; SettingsStore.barPopupsOnHover=true; SettingsStore.save();
                largeScreen.height = 980; wait(30);
                first.contentItem.grabToImage(result => { previewSaved = result.saveToFile("/tmp/rusticq-bar-padding-rail.png"); });
                tryVerify(() => previewSaved, 1500);
            }
        }
    }
}
'''


def prepare(root):
    for name in ('config','components','modules','services','assets'):
        shutil.copytree(ROOT/name, root/name)
    (root/'fixtures').mkdir()
    (root/'user-settings.json').write_text('{"showWifi":true}')
    (root/'fixtures/AnchorEdges.qml').write_text('import QtQuick\nQtObject { property bool top: false; property bool bottom: false; property bool left: false; property bool right: false }')
    (root/'fixtures/Insets.qml').write_text('import QtQuick\nQtObject { property real top: 0; property real bottom: 0; property real left: 0; property real right: 0 }')
    (root/'fixtures/PanelWindow.qml').write_text('''import QtQuick
QtObject {
    id: root
    default property alias data: content.data
    property bool visible: true
    property int exclusionMode: 0
    property color color: "transparent"
    property var screen: null
    property real implicitWidth: 0
    property real implicitHeight: 0
    property AnchorEdges anchors: AnchorEdges {}
    property Insets margins: Insets {}
    readonly property real width: content.width
    readonly property real height: content.height
    function mapFromItem(item,x,y) { return content.mapFromItem(item,x,y); }
    readonly property Item contentItem: Item {
        id: content
        width: root.anchors.left && root.anchors.right ? root.screen.width - root.margins.left - root.margins.right : root.implicitWidth
        height: root.anchors.top && root.anchors.bottom ? root.screen.height - root.margins.top - root.margins.bottom : root.implicitHeight
    }
}
''')
    bar=root/'modules/main/Bar.qml'
    bar.write_text(bar.read_text().replace('import QtQuick\n','import QtQuick\nimport "../../fixtures" as Headless\n',1).replace('PanelWindow {','Headless.PanelWindow {',1).replace('    WlrLayershell.namespace: "rusticq-bar"\n', ''))
    bar.write_text(re.sub(r'^    WlrLayershell.keyboardFocus:.*\n', '', bar.read_text(), flags=re.M))
    (root/'modules/main/BarAutoHide.qml').write_text('''import QtQuick
QtObject { property bool enabled: false; property string position: "top"; property var screen; property bool hovered: false; property bool heldOpen: false; readonly property bool shown: true }
''')
    (root/'modules/main/IndicatorPopup.qml').write_text('''import QtQuick
QtObject { property var hostWindow; property string kind: ""; property real targetX: 0; property real targetY: 0; property string barPosition; property string menuSection; readonly property bool visible: kind !== ""; signal menuSectionNavigated(string sectionKey); signal dismissed() }
''')
    fixtures = {
        'Hyprland': 'property var focusedWorkspace: ({id:3}); property bool usingLua: true; property string lastDispatch: ""; function dispatch(command) { lastDispatch=command; }',
        'Pipewire': 'property var defaultAudioSink: null',
    }
    entries=['PanelWindow 1.0 PanelWindow.qml','AnchorEdges 1.0 AnchorEdges.qml','Insets 1.0 Insets.qml']
    for name,body in fixtures.items():
        (root/'fixtures'/f'{name}.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {'+body+'}')
        entries.append(f'singleton {name} 1.0 {name}.qml')
    (root/'fixtures/PwObjectTracker.qml').write_text('import QtQuick\nQtObject { property var objects: [] }')
    entries.append('PwObjectTracker 1.0 PwObjectTracker.qml')
    (root/'fixtures/qmldir').write_text('\n'.join(entries))
    for name in ('BarZone','Workspaces'):
        file=root/'components'/f'{name}.qml'
        file.write_text(file.read_text().replace('import Quickshell.Hyprland','import "../fixtures"'))
    file=root/'components/Audio.qml'
    file.write_text(file.read_text().replace('import Quickshell.Services.Pipewire','import "../fixtures"'))
    services={
        'WifiService': 'property bool ethernetConnected: false; property bool connected: true; property bool enabled: true; property string icon: "\\ue63e"; property string ssid: "Wi-Fi"; property int strength: 80',
        'BluetoothService': 'property bool connected: true; property bool enabled: true; property string icon: "\\ue1a7"; property string deviceName: "Headphones"',
        'BatteryService': 'property bool available: true; property bool charging: false; property int percentage: 80; property string icon: "\\uf304"',
        'WeatherService': 'property string temperature: "27°"; property string icon: "\\ue430"',
        'NotificationCenter': 'property bool doNotDisturb: false; property int unread: 1',
        'QuickModesService': 'property bool busy: false; property bool gamingPending: false; property bool anyActive: false; property string error: ""; function refresh() {} function active(key) { return false; } function available(key) { return true; } function detail(key) { return key; } function toggle(key) {}',
        'SystemMetrics': 'property real rxPerSec: 0; property real txPerSec: 0; function speed(value) { return "0 K/s"; }',
    }
    for name,body in services.items():
        (root/'services'/f'{name}.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {'+body+'}')


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-padding-ui-') as folder:
        root=Path(folder); root.chmod(0o700); prepare(root)
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic', QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder,
                 XDG_STATE_HOME=str(root/'state'), XDG_CACHE_HOME=str(root/'cache'), DBUS_SESSION_BUS_ADDRESS='unix:path='+str(root/'missing-bus'))
        output=run_qml(root,env,QML)
        summary=re.search(r'BAR RESULTS (\d+) passed, (\d+) failed',output)
        assert summary and int(summary[1])>=10 and int(summary[2])==0,output
        saved=json.loads((root/'user-settings.json').read_text())
        for i,mode in enumerate(('compact','clean-compact','separated','professional','simple')):
            assert saved['barPaddingOverrides'][mode]=={'left':i+9,'right':i+10}
        assert saved['showWifi'] is True
        assert saved['barPopupsOnHover'] is True
        source='''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot { TestCase { when: true; function test_reload() {
    compare(SettingsStore.barPopupsOnHover,true);
    for (let i=0;i<SettingsStore.spacingModes.length;i++) {
        SettingsStore.barMode=SettingsStore.spacingModes[i];
        compare(SettingsStore.paddingFor("left"),i+9); compare(SettingsStore.paddingFor("right"),i+10);
    }
    console.log("PADDING RELOAD PASS");
} } }
'''
        assert 'PADDING RELOAD PASS' in run_qml(root,env,source)
    print('PASS: five modes × four edges, per-mode padding, two screen sizes, narrow rails, scroll, quick modes, popup anchors, save/reload')


if __name__=='__main__':
    main()
