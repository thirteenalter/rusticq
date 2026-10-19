#!/usr/bin/env python3
"""Validate safe reinstall after restore, including crashed stale installation."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import os

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'scripts/rustiq-desktop-integration.py'


def run():
    with tempfile.TemporaryDirectory() as d:
        root=Path(d); home=root/'home'; home.mkdir()
        config=home/'.config/hypr'; config.mkdir(parents=True)
        (config/'hyprland.lua').write_text('require("default.hypr.omarchy")\nrequire("hypr.bindings")\n')
        (config/'bindings.lua').write_text('-- original\n')
        omarchy=root/'omarchy/default/hypr'; omarchy.mkdir(parents=True)
        (omarchy/'autostart.lua').write_text('hl.exec_cmd("omarchy-launch-shell")\n')
        (omarchy/'bindings.lua').write_text('-- default\n')
        env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_STATE_HOME=str(home/'.local/state'),XDG_DATA_HOME=str(home/'.local/share'),OMARCHY_PATH=str(root/'omarchy'))
        env.pop('HYPRLAND_INSTANCE_SIGNATURE',None)
        def command(*args):
            p=subprocess.run([sys.executable,str(SCRIPT),*args],env=env,capture_output=True,text=True,timeout=45)
            assert p.stdout, (p.stderr,p.returncode)
            result=json.loads(p.stdout)
            assert result.get('ok'), result
            return result
        a=command('enable','--confirm','ENABLE RUSTICQ')
        assert a['integration']['state']=='installed'
        command('revert','--confirm','RESTORE OMARCHY')
        # Simulate recovery of interrupted revert leaving stale launcher.
        state=home/'.local/state/rusticq/integration'
        (state/'autostart.lua').write_text('hl.exec_cmd("RusticQ old shim")\n')
        (state/'start-rusticq.sh').write_text('#!/bin/sh\nexec quickshell -p /old\n')
        data=home/'.local/share/rusticq/shell'
        data.mkdir(parents=True)
        (data/'shell.qml').write_text('old shell')
        (data/'scripts').mkdir();(data/'scripts/rustiq-desktop-integration.py').write_text('old helper')
        a=command('enable','--confirm','ENABLE RUSTICQ')
        assert a['recovered_files'] and len(a['recovered_files'])==3,a
        assert a['integration']['state']=='installed'
        assert all(Path(x).exists() for x in a['recovered_files'])
        command('revert','--confirm','RESTORE OMARCHY')
        command('enable','--confirm','ENABLE RUSTICQ')
        assert (omarchy/'autostart.lua').read_text()=='hl.exec_cmd("omarchy-launch-shell")\n'
        print('OK reinstall, revert, recover stale files, reinstall again, backups preserved')

if __name__=='__main__':run()
