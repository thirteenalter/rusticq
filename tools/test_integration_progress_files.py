#!/usr/bin/env python3
"""Offline integration progress and on-disk changed-path reporting regression."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/rustiq-desktop-integration.py'


def command(env, *args):
    out = subprocess.run(['python3', str(SCRIPT), *args], env=env,
                         capture_output=True, text=True, timeout=45)
    assert out.stdout, out.stderr
    return out.returncode, json.loads(out.stdout)


def fixture(root):
    home = root / 'home'
    user_hypr = home / '.config/hypr'
    user_hypr.mkdir(parents=True)
    (user_hypr / 'hyprland.lua').write_text('require("default.hypr.omarchy")\nrequire("hypr.bindings")\n')
    (user_hypr / 'bindings.lua').write_text('-- Existing custom shortcuts\n')
    omarchy = root / 'omarchy/default/hypr'
    omarchy.mkdir(parents=True)
    (omarchy / 'autostart.lua').write_text('hl.exec_cmd("omarchy-launch-shell")\n')
    (omarchy / 'bindings.lua').write_text('o.bind("SUPER + T", "Terminal", "foot")\n')
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
               XDG_STATE_HOME=str(home / '.local/state'),
               XDG_DATA_HOME=str(home / '.local/share'), OMARCHY_PATH=str(root / 'omarchy'))
    env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    return home, user_hypr, omarchy, env


def run():
    with tempfile.TemporaryDirectory() as tmp:
        home, hypr, original, env = fixture(Path(tmp))
        rc, before = command(env, 'integration-progress')
        assert rc == 0 and before['percent'] == 0 and before['state'] == 'not_installed', before
        rc, enabled = command(env, 'enable', '--confirm', 'ENABLE RUSTICQ')
        assert rc == 0 and enabled['integration']['percent'] == 100, enabled
        assert enabled['integration']['state'] == 'installed'
        assert enabled['integration']['next_login'] and enabled['integration']['session_active'] == 'unverified'
        assert (original / 'autostart.lua').read_text() == 'hl.exec_cmd("omarchy-launch-shell")\n'
        rc, report = command(env, 'status')
        assert rc == 0 and report['integration']['percent'] == 100, report
        inventory = {x['path']: x for x in report['integration']['changes']}
        assert inventory[str(hypr / 'hyprland.lua')]['action'] == 'Modified'
        assert inventory[str(original / 'autostart.lua')]['action'] == 'Read only'
        installed = home / '.local/share/rusticq/shell'
        assert inventory[str(installed)]['action'] == 'Copied'
        assert inventory[str(home / '.local/state/rusticq/integration/manifest.json')]['action'] == 'Created'
        # Old completed installations without a progress file still report real status.
        checkpoint = home / '.local/state/rusticq/integration/permanent-install-progress.json'
        assert json.loads(checkpoint.read_text())['percent'] == 100
        checkpoint.unlink()
        rc, legacy = command(env, 'integration-progress')
        assert rc == 0 and legacy['percent'] == 100 and legacy['state'] == 'installed'
        # Missing generated file makes the installation incomplete, never fake 100%.
        shim = home / '.local/state/rusticq/integration/autostart.lua'
        saved = shim.read_bytes()
        shim.unlink()
        rc, broken = command(env, 'integration-progress')
        assert rc == 0 and broken['state'] == 'incomplete' and broken['percent'] < 100, broken
        shim.write_bytes(saved)
        rc, restored = command(env, 'revert', '--confirm', 'RESTORE OMARCHY')
        assert rc == 0 and restored['integration']['state'] == 'restored' and restored['integration']['percent'] == 100, restored
        assert not (home / '.local/state/rusticq/integration/manifest.json').exists()
        assert (home / '.local/state/rusticq/integration/backup').exists()
        assert (original / 'autostart.lua').read_text() == 'hl.exec_cmd("omarchy-launch-shell")\n'
        rc, report = command(env, 'integration-progress')
        assert rc == 0 and report['state'] == 'restored'
        assert any(x['action'] == 'Restored' for x in report['changes'])
        print('OK: initial 0%, completed 100%, paths, old install, incomplete, revert 100%, source untouched')


if __name__ == '__main__':
    run()
