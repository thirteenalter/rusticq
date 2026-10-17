"""RC4 v3 regression checks: action catalogue, generated bindings and QML routing.

No live Hyprland/Quickshell is available in this fixture. This intentionally
cannot prove compositor behavior on a real dual-monitor session.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
HELPER = PROJECT / 'scripts/rustiq-desktop-integration.py'

shell = (PROJECT / 'shell.qml').read_text()
bar = (PROJECT / 'modules/main/Bar.qml').read_text()
settings = (PROJECT / 'modules/settings/SettingsWindow.qml').read_text()
page = (PROJECT / 'modules/settings/pages/SettingsShortcutsPage.qml').read_text()
store = (PROJECT / 'config/Store.qml').read_text()

assert 'Hyprland.focusedMonitor' in shell
assert 'focused.name' in shell
assert 'Quickshell.screens[i].name === name' in shell
assert 'toggleLauncher(Quickshell.screens[0])' not in shell
assert 'Store.toggleLauncher(screen)' in shell
assert 'Store.toggleQuick(screen)' in shell
assert 'Store.toggleAi(screen)' in shell
assert 'Store.shortcutBarRequested(popup, screenName)' in shell
assert 'onShortcutBarRequested(kind, screenName)' in bar
assert 'barWindow.screen.name !== screenName' in bar
assert 'signal shortcutBarRequested(string kind, string screenName)' in store
assert 'screen: Store.settingsScreen' in settings
assert 'onTextEdited: root.actionFilter = text' in page
assert 'root.matchingActions.slice(0, 80)' in page
assert 'heading: "Top bar button shortcuts"' in page
assert 'root.barActions' in page
assert 'kind === "menu-default"' in bar
assert 'kind === "quick-modes"' in bar
assert 'WifiService.ethernetConnected ? "ethernet" : "wifi"' in shell

with tempfile.TemporaryDirectory() as folder:
    root = Path(folder)
    home = root / 'user'; home.mkdir()
    source = root / 'quickshell'
    (source / 'scripts').mkdir(parents=True)
    (source / 'shell.qml').write_text('ShellRoot {}\n')
    shutil.copy2(HELPER, source / 'scripts/rustiq-desktop-integration.py')
    hypr = home / '.config/hypr'; hypr.mkdir(parents=True)
    original = '-- personal\no.bind("SUPER + A", "An app", "a-command")\n'
    (hypr / 'bindings.lua').write_text(original)
    env = {**os.environ, 'HOME': str(home), 'XDG_CONFIG_HOME': str(home / '.config'),
           'XDG_STATE_HOME': str(home / '.state'), 'XDG_DATA_HOME': str(home / '.data'),
           'OMARCHY_PATH': str(root / 'empty')}
    env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)

    def run(*args, success=True):
        call = subprocess.run(['python3', str(source / 'scripts/rustiq-desktop-integration.py'),
                               *args], text=True, capture_output=True, env=env)
        result = json.loads(call.stdout)
        assert (call.returncode == 0) == success, (args, result, call.stderr)
        return result

    result = run('actions')
    registry = result['actions']
    keys = [a['key'] for a in registry]
    assert len(keys) == len(set(keys)) == 77
    for action in ('launcher', 'quick', 'ai', 'popup-wifi', 'popup-bluetooth', 'popup-weather',
                   'popup-task', 'menu-tools', 'bar-network', 'bar-menu', 'bar-quick-modes', 'item-file-downloads', 'item-view-clean-compact',
                   'item-share-start-screen', 'mode-mic', 'settings-shortcuts', 'workspace-2'):
        assert action in keys, action
    bar = {key: set() for key in ("rusticq", "arch", "launcher", "menu", "workspaces", "weather", "time", "date", "bluetooth", "wifi", "battery", "audio", "task", "quickModes", "quickControl", "mic")}
    for record in registry:
        for icon in record.get('bar_keys', []):
            assert icon in bar, icon
            bar[icon].add(record['key'])
    assert all(bar.values()), bar
    assert not any('bar_keys' in r and ('down' in r['bar_keys'] or 'up' in r['bar_keys']) for r in registry)
    for action in keys:
        if action.startswith('settings-'):
            tab = action.removeprefix('settings-')
            assert f'key:"{tab}"' in settings, action
        if action.startswith('menu-'):
            assert action.removeprefix('menu-') in ('file','edit','view','share','shell','tools')

    # Multiple distinct action families, and one-at-a-time revert.
    for action, combo in [('popup-wifi', 'SUPER + ALT + W'),
                          ('settings-shortcuts', 'SUPER + ALT + S'),
                          ('item-view-clean-compact', 'SUPER + ALT + C'),
                          ('workspace-2', 'SUPER + CTRL + 2')]:
        run('shortcut', '--key', combo, '--action', action)
    content = (hypr / 'bindings.lua').read_text()
    assert original in content
    for action in ('popup-wifi', 'settings-shortcuts', 'item-view-clean-compact', 'workspace-2'):
        assert 'call rusticq dispatch ' + action in content
    assert len(run('status')['shortcuts']) == 4
    run('shortcut-revert', '--action', 'popup-wifi')
    content = (hypr / 'bindings.lua').read_text()
    assert 'call rusticq dispatch popup-wifi' not in content
    assert 'call rusticq dispatch workspace-2' in content
    assert original in content
    run('shortcut-revert', '--all')
    assert (hypr / 'bindings.lua').read_text() == original
    assert run('status')['shortcuts'] == {}

    # A duplicated destination must fail rather than silently change a different action.
    run('shortcut', '--key', 'SUPER + ALT + Z', '--action', 'launcher')
    run('shortcut', '--key', 'SUPER + ALT + Z', '--action', 'popup-audio', success=False)
    assert run('status')['shortcuts'] == {'launcher': 'SUPER + ALT + Z'}
    run('shortcut-revert', '--action', 'launcher')
    assert (hypr / 'bindings.lua').read_text() == original

print('PASS: 77 registered actions, focus routing contracts, per-action backups / restores')
