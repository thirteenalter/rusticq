import json
import os
import subprocess
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
SCRIPT = PROJECT / 'scripts/rustiq-desktop-integration.py'


def cli(env, *args):
    proc = subprocess.run(['python3', str(SCRIPT), *args], env=env, capture_output=True, text=True)
    assert proc.stdout.strip(), proc.stderr
    return proc.returncode, json.loads(proc.stdout)


def test_integration_cycle():
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        home = root/'home'; home.mkdir()
        config = home/'.config/hypr'; config.mkdir(parents=True)
        omarchy = root/'omarchy/default/hypr'; omarchy.mkdir(parents=True)
        autostart = omarchy/'autostart.lua'
        old_default = 'hl.on("hyprland.start", function()\n  hl.exec_cmd("omarchy-launch-shell")\n  hl.exec_cmd("omarchy-powerprofiles-init")\nend)\n'
        autostart.write_text(old_default)
        main = config/'hyprland.lua'
        original_main = '-- existing user configuration\nrequire("default.hypr.omarchy")\nrequire("hypr.bindings")\n'
        main.write_text(original_main)
        keys = config/'bindings.lua'
        keys.write_text('-- custom shortcuts\no.bind("SUPER + N", "Terminal", "foot")\n')
        env = os.environ.copy()
        env.update({'HOME':str(home),'XDG_CONFIG_HOME':str(home/'.config'), 'XDG_STATE_HOME':str(home/'.local/state'), 'XDG_DATA_HOME':str(home/'.local/share'), 'OMARCHY_PATH':str(root/'omarchy')})
        env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)

        before = {x: x.read_bytes() for x in (main, keys, autostart)}
        rc, res = cli(env, 'status'); assert rc == 0 and res['ok'] and not res['permanent']
        assert all(x.read_bytes() == b for x,b in before.items())
        rc, res = cli(env, 'shortcut', '--key', 'SUPER + SPACE', '--action', 'settings')
        assert rc == 0, res
        assert 'o.bind("SUPER + SPACE"' in keys.read_text()
        assert keys.read_text().count('RUSTICQ MANAGED RC4') == 2
        assert 'o.bind("SUPER + N"' in keys.read_text()
        rc, res = cli(env, 'shortcut', '--key', 'SUPER + T', '--action', 'launcher'); assert rc == 0, res
        assert keys.read_text().count('RUSTICQ MANAGED RC4') == 2
        assert 'o.bind("SUPER + T"' in keys.read_text()
        assert 'o.bind("SUPER + SPACE"' in keys.read_text()
        rc, res = cli(env, 'bindings'); assert rc == 0 and any(i['key'] == 'SUPER + N' for i in res['bindings'])
        rc, res = cli(env, 'status'); assert res['shortcuts'] == {'settings': 'SUPER + SPACE', 'launcher': 'SUPER + T'}
        rc, res = cli(env, 'shortcut', '--key', 'SUPER + T\nquit()', '--action', 'launcher'); assert rc != 0
        rc, res = cli(env, 'shortcut-revert', '--all'); assert rc == 0
        assert keys.read_bytes() == before[keys], (repr(keys.read_text()), repr(before[keys].decode()))
        rc, res = cli(env, 'shortcut', '--key', 'SUPER + SHIFT + R', '--action', 'settings'); assert rc == 0, res
        assert str(PROJECT) in keys.read_text()
        rc, res = cli(env, 'enable', '--confirm', 'wrong'); assert rc != 0
        assert main.read_bytes() == before[main]
        rc, res = cli(env, 'enable', '--confirm', 'ENABLE RUSTICQ'); assert rc == 0, res
        assert main.read_text().count('RUSTICQ MANAGED RC4') == 2
        assert str(home/'.local/share/rusticq/shell') in keys.read_text()
        assert 'package.preload["default.hypr.autostart"]' in main.read_text()
        assert 'hl.exec_cmd("omarchy-powerprofiles-init")' in (home/'.local/state/rusticq/integration/autostart.lua').read_text()
        assert 'omarchy-launch-shell' not in (home/'.local/state/rusticq/integration/autostart.lua').read_text()
        assert autostart.read_bytes() == before[autostart]
        assert (home/'.local/share/rusticq/shell/shell.qml').is_file()
        assert (home/'.local/state/rusticq/integration/backup/omarchy_autostart.original').read_bytes() == before[autostart]
        rc, res = cli(env, 'enable', '--confirm', 'ENABLE RUSTICQ'); assert rc != 0
        rc, res = cli(env, 'status'); assert rc == 0 and res['permanent']
        rc, res = cli(env, 'revert', '--confirm', 'wrong'); assert rc != 0
        rc, res = cli(env, 'revert', '--confirm', 'RESTORE OMARCHY'); assert rc == 0, res
        assert main.read_bytes() == before[main]
        # Permanent-shell revert deliberately retains independent key overrides.
        assert 'o.bind("SUPER + SHIFT + R"' in keys.read_text()
        rc, res = cli(env, 'shortcut-revert', '--action', 'settings'); assert rc == 0, res
        assert keys.read_bytes() == before[keys]
        assert not (home/'.local/state/rusticq/integration/manifest.json').exists()
        assert (home/'.local/share/rusticq/shell-previous/shell.qml').exists()
        assert autostart.read_bytes() == before[autostart]


def test_unknown_omarchy_fails_closed():
    with tempfile.TemporaryDirectory() as d:
        p=Path(d); home=p/'home';home.mkdir(); h=home/'.config/hypr';h.mkdir(parents=True)
        main=h/'hyprland.lua';main.write_text('require("default.hypr.omarchy")\n')
        o=p/'omarchy/default/hypr';o.mkdir(parents=True)
        (o/'autostart.lua').write_text('hl.exec_cmd("some-other-launcher")\n')
        env={**os.environ,'HOME':str(home),'OMARCHY_PATH':str(p/'omarchy')}
        env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        rc, result = cli(env, 'enable', '--confirm', 'ENABLE RUSTICQ')
        assert rc != 0 and not result['ok']
        assert main.read_text() == 'require("default.hypr.omarchy")\n'
        assert not (home/'.local/share/rusticq/shell').exists()


if __name__ == '__main__':
    test_integration_cycle()
    test_unknown_omarchy_fails_closed()
    print('RC4 integration tests passed')
