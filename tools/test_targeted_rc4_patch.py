import json, os, pathlib, subprocess, tempfile, shutil
PATCH=pathlib.Path(__file__).resolve().parents[1] / 'scripts/rustiq-desktop-integration.py'
with tempfile.TemporaryDirectory() as d:
    p=pathlib.Path(d); home=p/'home'; home.mkdir()
    prog=p/'quickshell'; (prog/'scripts').mkdir(parents=True); (prog/'shell.qml').write_text('Item {}\n')
    shutil.copy2(PATCH,prog/'scripts/rustiq-desktop-integration.py')
    config=home/'.config/hypr'; config.mkdir(parents=True)
    (config/'hyprland.lua').write_text('-- main\nrequire("default.hypr.omarchy")\nrequire("hypr.bindings")\n')
    original_keys='-- custom\no.bind("SUPER + N", "Terminal", "foot")\n'
    (config/'bindings.lua').write_text(original_keys)
    root=p/'omarchy/default/hypr'; root.mkdir(parents=True)
    (root/'autostart.lua').write_text('hl.on("hyprland.start", function()\n hl.exec_cmd("omarchy-launch-shell")\n hl.exec_cmd("other-app")\nend)\n')
    (root/'bindings.lua').write_text('o.bind("SUPER + SPACE", "Launcher", "omarchy-launch")\no.bind("SUPER + G", "Browser", "firefox")\n')
    env={**os.environ,'HOME':str(home),'XDG_CONFIG_HOME':str(home/'.config'),'XDG_STATE_HOME':str(home/'.local/state'),'XDG_DATA_HOME':str(home/'.local/share'),'OMARCHY_PATH':str(p/'omarchy')}
    env.pop('HYPRLAND_INSTANCE_SIGNATURE',None)
    def cli(*args, ok=True):
        a=subprocess.run(['python3',str(prog/'scripts/rustiq-desktop-integration.py'),*map(str,args)],env=env,capture_output=True,text=True)
        try: output=json.loads(a.stdout)
        except Exception as e: raise AssertionError((a.stdout,a.stderr)) from e
        assert (a.returncode==0)==ok,(args,a.returncode,output,a.stderr)
        return output
    assert cli('status')['compatibility']['omarchy_detected']
    c=cli('bindings')['bindings']; assert len(c)>=3,c
    terminal=next(i for i in c if i['label']=='Terminal')
    launcher=next(i for i in c if i['label']=='Launcher')
    assert terminal['line']==2
    assert cli('backup-omarchy')['created']
    assert cli('backup-omarchy')['created'] is False
    assert (home/'.local/state/rusticq/integration/backup/omarchy-default-hypr/bindings.lua').is_file()
    res=cli('remap','--file',terminal['file'],'--line',terminal['line'],'--hash',terminal['source_hash'],'--key','SUPER + ALT + M')
    remap1=res['remap_id']; assert original_keys in (config/'bindings.lua').read_text()
    assert 'o.rebind("SUPER + ALT + M", "Terminal", "foot")' in (config/'bindings.lua').read_text()
    cli('remap','--file',launcher['file'],'--line',launcher['line'],'--hash',launcher['source_hash'],'--key','SUPER + CTRL + L')
    assert 'SUPER + CTRL + L' in (config/'bindings.lua').read_text()
    cli('shortcut','--key','SUPER + ALT + H','--action','settings')
    cli('shortcut','--key','SUPER + SHIFT + Q','--action','launcher')
    assert cli('status')['shortcuts']['launcher']=='SUPER + SHIFT + Q'
    assert len(cli('status')['remaps'])==2
    cli('shortcut-revert','--action','settings')
    assert 'RusticQ Settings' not in (config/'bindings.lua').read_text()
    assert 'RusticQ App Launcher' in (config/'bindings.lua').read_text()
    cli('remap-revert','--id',remap1)
    assert 'SUPER + ALT + M' not in (config/'bindings.lua').read_text()
    assert 'SUPER + CTRL + L' in (config/'bindings.lua').read_text()
    assert original_keys in (config/'bindings.lua').read_text()
    assert len(cli('status')['remaps'])==1
    cli('enable','--confirm','ENABLE RUSTICQ')
    assert cli('status')['permanent']
    assert 'shell' in (config/'bindings.lua').read_text()
    assert 'RusticQ App Launcher' in (config/'bindings.lua').read_text()
    assert (root/'autostart.lua').read_text().count('omarchy-launch-shell')==1
    assert 'default.hypr.autostart' in (config/'hyprland.lua').read_text()
    cli('revert','--confirm','RESTORE OMARCHY')
    assert not cli('status')['permanent']
    assert 'RusticQ App Launcher' in (config/'bindings.lua').read_text(), 'Integration revert should NOT destroy shortcuts'
    assert 'SUPER + CTRL + L' in (config/'bindings.lua').read_text()
    cli('shortcut-revert','--action','launcher')
    remap_id=next(iter(cli('status')['remaps']))
    cli('remap-revert','--id',remap_id)
    assert (config/'bindings.lua').read_text().rstrip()==original_keys.rstrip(),repr((config/'bindings.lua').read_text())
    assert (config/'hyprland.lua').read_text()=='-- main\nrequire("default.hypr.omarchy")\nrequire("hypr.bindings")\n'
    assert cli('remap','--file',launcher['file'],'--line',launcher['line'],'--hash','wrong','--key','SUPER + P',ok=False)['ok'] is False
    sensitive = cli('remap','--file',launcher['file'],'--line',launcher['line'],'--hash',launcher['source_hash'],'--key','SUPER + ESCAPE')
    assert sensitive['ok']
    cli('remap-revert','--id', sensitive['remap_id'])
    print('RC4 patch all CLI scenarios pass')
