#!/usr/bin/env python3
"""RAGE capability probe and reversible, named, session-only blur rules.

No compositor configuration files, global blur options, sudo, reload or restart.
The existing compositor studio retains ownership of persistent config edits.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

LAYER_NAMES = ('bar', 'dock', 'quick-control', 'launcher', 'notifications',
               'desktop-widgets', 'osd', 'ai', 'power', 'wifi-qr', 'recovery', 'popups', 'launcher-backdrop')
NAMESPACE = '^rusticq-(' + '|'.join(LAYER_NAMES) + ')$'
TITLES = '^RusticQ · (Settings|Device settings|System Monitor|Task View|Package Confirmation|Shortcut Backup Confirmation)$'
RULE_NAMES = ('rusticq-rage-layers', 'rusticq-rage-bar', 'rusticq-rage-windows',
              'rusticq-rage-launcher', 'rusticq-rage-launcher-backdrop', 'rusticq-launcher-presentation')


def run(args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise ValueError('Compositor IPC is unavailable')
    return result.stdout.strip()


def backend():
    spec = importlib.util.spec_from_file_location('rage_compositor', Path(__file__).with_name('rusticq-compositor-config.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.compositor()


def capabilities():
    result = dict(ok=True, backend=backend(), supported=False, active=False,
                  independentStrength=False, persistentChanges=False,
                  message='Compositor backdrop blur is unavailable; readable tinted surfaces are used.')
    if result['backend'] == 'niri':
        version = run(['niri', '--version']) if shutil.which('niri') else ''
        result.update(version=version, message='Niri: RAGE uses a tinted fallback. Quickshell 0.3.1 cannot request ext-background-effect and RAGE does not rewrite Niri configuration.')
        return result
    if result['backend'] != 'hyprland' or not shutil.which('hyprctl'):
        return result
    try:
        info = json.loads(run(['hyprctl', '-j', 'version']))
        version = str(info.get('version') or info.get('tag') or '')
        result['version'] = version
        match = re.search(r'(\d+)\.(\d+)\.(\d+)', version)
        # Audited Lua named-rule API. Unknown future/legacy APIs fail closed.
        if not match or not ((0, 55, 0) <= tuple(map(int, match.groups())) < (0, 58, 0)):
            result['message'] = 'This Hyprland version has no audited named Lua rule adapter; tinted fallback is active.'
            return result
        answer = run(['hyprctl', 'eval', 'assert(type(hl.layer_rule) == "function" and type(hl.window_rule) == "function")'])
        if answer != 'ok':
            raise ValueError('Named Lua rule API unavailable')
        value = json.loads(run(['hyprctl', '-j', 'getoption', 'decoration:blur:enabled']))
        # Hyprland 0.56 reports typed booleans; older builds used int 0/1.
        # Missing/malformed values must not masquerade as a verified setting.
        state = value.get('bool', value.get('int'))
        if type(state) not in (bool, int) or state not in (False, True, 0, 1):
            raise ValueError('Unrecognized global blur option')
        result.update(supported=True, globalBlur=bool(state),
                      message='Hyprland named session rules are supported. Blur strength follows your compositor; RAGE never changes its global blur options.')
        if not result['globalBlur']:
            result['message'] = 'Global compositor blur is off. RAGE leaves it off and uses a readable tinted fallback.'
    except (OSError, ValueError, subprocess.SubprocessError):
        result['message'] = 'Could not verify compositor capabilities. Readable tinted fallback is active.'
    return result


def validate(request):
    if not isinstance(request, dict) or set(request) - {'enabled', 'blur', 'performance', 'lowMemory', 'owner', 'barBlur', 'launcherBlur', 'launcherBackdropBlur', 'settingsPresentation', 'settingsBlur', 'hyprSettingsBlur', 'settingsRadius', 'hyprSettingsRadius', 'surfaceBlurFlags'}:
        raise ValueError('Invalid glass session request')
    for key in ('enabled', 'blur', 'performance', 'lowMemory'):
        if type(request.get(key)) is not bool:
            raise ValueError(key + ' must be a boolean')
    for key in ('settingsPresentation','settingsBlur','hyprSettingsBlur'):
        if type(request.get(key,False)) is not bool: raise ValueError(key+' must be a boolean')
    for key in ('settingsRadius','hyprSettingsRadius'):
        value=request.get(key,16)
        if type(value) not in (int,float) or not 0 <= value <= 28: raise ValueError('Invalid settings radius')
    flags=request.get('surfaceBlurFlags',{})
    if not isinstance(flags,dict) or set(flags)-{'dock','notifications','widgets','popovers','dialogs'} or any(type(v) is not bool for v in flags.values()): raise ValueError('Invalid surface blur overrides')
    owner = request.get('owner', '')
    for key, default in (('barBlur', True), ('launcherBlur', True), ('launcherBackdropBlur', False)):
        if type(request.get(key, default)) is not bool:
            raise ValueError(key + ' must be a boolean')
    if not isinstance(owner, str) or (owner and not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', owner)):
        raise ValueError('Invalid RAGE owner')
    return request['enabled'] and request['blur'] and not request['performance'] and not request['lowMemory']


def _material_program(enabled, owner='', cleanup=False, bar_blur=True):
    # Only fixed literals enter Lua. No SSID, path, user text or arbitrary code.
    if not enabled:
        guard = ('_G.__rusticq_rage_owner == ' + json.dumps(owner)) if cleanup and owner else 'true'
        return '''if GUARD then
if _G.__rusticq_rage_created then
hl.layer_rule({name="rusticq-rage-layers", enabled=false})
hl.layer_rule({name="rusticq-rage-bar", enabled=false})
hl.window_rule({name="rusticq-rage-windows", enabled=false})
_G.__rusticq_rage_active=false
end
_G.__rusticq_rage_owner=OWNER
end'''.replace('GUARD', guard).replace('OWNER', json.dumps(owner))
    namespace = '^rusticq-(' + '|'.join(n for n in LAYER_NAMES if n not in ('bar', 'launcher', 'launcher-backdrop')) + ')$'
    return '''local previous = _G.__rusticq_rage_active == true
local previous_bar = _G.__rusticq_rage_bar_blur ~= false
local ok, reason = pcall(function()
hl.layer_rule({name="rusticq-rage-layers", enabled=true,
match={namespace=NAMESPACE}, blur=true, blur_popups=true, ignore_alpha=0.02, xray=false})
_G.__rusticq_rage_created=true
hl.layer_rule({name="rusticq-rage-bar", enabled=true,
match={namespace="^rusticq-bar$"}, blur=BAR_BLUR, blur_popups=true, ignore_alpha=0.02, xray=false})
hl.window_rule({name="rusticq-rage-windows", enabled=true,
match={class="^org[.]quickshell$", title=TITLES}, no_blur=false})
_G.__rusticq_rage_active=true
_G.__rusticq_rage_bar_blur=BAR_BLUR
_G.__rusticq_rage_owner=OWNER
end)
if not ok then
if _G.__rusticq_rage_created then
hl.layer_rule({name="rusticq-rage-layers", enabled=previous})
hl.layer_rule({name="rusticq-rage-bar", enabled=previous, blur=previous_bar})
hl.window_rule({name="rusticq-rage-windows", enabled=previous})
end
_G.__rusticq_rage_active=previous
error(reason)
end'''.replace('NAMESPACE', json.dumps(namespace)).replace('BAR_BLUR', 'true' if bar_blur else 'false').replace('TITLES', json.dumps(TITLES, ensure_ascii=False)).replace('OWNER', json.dumps(owner))


def program(enabled, owner='', cleanup=False, bar_blur=True, launcher_blur=True, backdrop_blur=False):
    # The launcher canvas and optional fullscreen backdrop have independent rules.
    # None never has a fullscreen surface or a backdrop rule enabled.
    core = _material_program(enabled, owner, False, bar_blur)
    guard = '_G.__rusticq_rage_owner == ' + json.dumps(owner) if cleanup and owner else 'true'
    launcher = enabled and launcher_blur
    extra = """
if PRESENTATION or _G.__rusticq_rage_presentation_created then
hl.layer_rule({name="rusticq-launcher-presentation",enabled=PRESENTATION,
match={namespace="^rusticq-(launcher(-backdrop)?|dock)$"},no_anim=true})
_G.__rusticq_rage_presentation_created=true
_G.__rusticq_rage_presentation_active=PRESENTATION
end
if ENABLED or _G.__rusticq_rage_launcher_created then
hl.layer_rule({name="rusticq-rage-launcher",enabled=LAUNCHER,
match={namespace="^rusticq-launcher$"},blur=LAUNCHER,blur_popups=true,ignore_alpha=0.02,xray=false})
_G.__rusticq_rage_launcher_created=true
_G.__rusticq_rage_launcher_active=LAUNCHER
end
if BACKDROP or _G.__rusticq_rage_backdrop_created then
hl.layer_rule({name="rusticq-rage-launcher-backdrop",enabled=BACKDROP,
match={namespace="^rusticq-launcher-backdrop$"},blur=true,ignore_alpha=0,xray=false})
_G.__rusticq_rage_backdrop_created=true
_G.__rusticq_rage_backdrop_active=BACKDROP
end
""".replace('PRESENTATION', 'false' if cleanup else 'true').replace('ENABLED', 'true' if enabled else 'false').replace('LAUNCHER', 'true' if launcher else 'false').replace('BACKDROP', 'true' if backdrop_blur else 'false')
    # Restore all previously active owned rules on an API failure. Global user
    # options and unrelated rules are never part of this transaction.
    return """if GUARD then
local previous_active=_G.__rusticq_rage_active==true
local previous_bar=_G.__rusticq_rage_bar_blur~=false
local previous_launcher=_G.__rusticq_rage_launcher_active==true
local previous_backdrop=_G.__rusticq_rage_backdrop_active==true
local previous_presentation=_G.__rusticq_rage_presentation_active==true
local previous_owner=_G.__rusticq_rage_owner
local ok,reason=pcall(function()
CORE
EXTRA
end)
if not ok then
if _G.__rusticq_rage_created then
hl.layer_rule({name="rusticq-rage-layers",enabled=previous_active})
hl.layer_rule({name="rusticq-rage-bar",enabled=previous_active,blur=previous_bar})
hl.window_rule({name="rusticq-rage-windows",enabled=previous_active})
end
if _G.__rusticq_rage_launcher_created then hl.layer_rule({name="rusticq-rage-launcher",enabled=previous_launcher,blur=previous_launcher}) end
if _G.__rusticq_rage_backdrop_created then hl.layer_rule({name="rusticq-rage-launcher-backdrop",enabled=previous_backdrop}) end
if _G.__rusticq_rage_presentation_created then hl.layer_rule({name="rusticq-launcher-presentation",enabled=previous_presentation}) end
_G.__rusticq_rage_active=previous_active
_G.__rusticq_rage_bar_blur=previous_bar
_G.__rusticq_rage_launcher_active=previous_launcher
_G.__rusticq_rage_backdrop_active=previous_backdrop
_G.__rusticq_rage_presentation_active=previous_presentation
_G.__rusticq_rage_owner=previous_owner
error(reason)
end
end""".replace('GUARD', guard).replace('CORE', core).replace('EXTRA', extra)



def settings_program(core, request, cleanup=False):
    if not request.get('settingsPresentation') and not cleanup:
        return core
    guard=('_G.__rusticq_rage_owner == '+json.dumps(request.get('owner',''))) if cleanup else 'true'
    lines=[]
    for app,title,key in [('settings','RusticQ · Settings','settings'),('hyprsettings','RusticQ Hyprland Settings','hyprSettings')]:
        enabled=not cleanup and request.get('settingsPresentation',False)
        blur=enabled and request.get(key+'Blur',False) and not request['performance'] and not request['lowMemory']
        radius=request.get(key+'Radius',16)
        name='rusticq-design-'+app
        flag='_G.__rusticq_design_'+app
        lines.append('local previous_'+app+' = '+flag+' == true')
        # Lua does not accept JSON's ASCII \uXXXX escapes. Preserve UTF-8 in
        # the fixed title literal (the middle dot is part of Settings' title).
        command='hl.window_rule({name='+json.dumps(name)+', enabled='+str(enabled).lower()+', match={class="^org[.]quickshell$",title='+json.dumps('^'+title+'$',ensure_ascii=False)+'}, no_blur='+str(not blur).lower()+', rounding='+str(radius)+', border_size=0})'
        lines.append('local function set_'+app+'() '+command+'; '+flag+'='+str(enabled).lower()+' end')
    extras=[]
    for name,namespace in [('dock','dock'),('notifications','notifications'),('widgets','desktop-widgets'),('popovers','popups')]:
        flags=request.get('surfaceBlurFlags',{});enabled=not cleanup and name in flags
        extras.append('hl.layer_rule({name='+json.dumps('rusticq-surface-'+name)+',enabled='+str(enabled).lower()+',match={namespace='+json.dumps('^rusticq-'+namespace+'$')+'},blur='+str(flags.get(name,False)).lower()+',blur_popups='+str(flags.get(name,False)).lower()+'})')
    flags=request.get('surfaceBlurFlags',{})
    extras.append('hl.window_rule({name="rusticq-surface-dialogs",enabled='+str(not cleanup and 'dialogs' in flags).lower()+',match={class="^org[.]quickshell$",title="^RusticQ · (Package Confirmation|Shortcut Backup Confirmation)$"},no_blur='+str(not flags.get('dialogs',False)).lower()+'})')
    return ('if '+guard+' then\n'+'\n'.join(lines)+'\nlocal ok,reason=pcall(function()\nset_settings()\nset_hyprsettings()\n'+core+'\n'+'\n'.join(extras)+'\nend)\nif not ok then\nhl.window_rule({name="rusticq-design-settings",enabled=previous_settings})\nhl.window_rule({name="rusticq-design-hyprsettings",enabled=previous_hyprsettings})\nerror(reason)\nend\nend')


def apply(request, cleanup=False):
    enabled = validate(request)
    backdrop = request.get("launcherBackdropBlur", False) and not request["performance"] and not request["lowMemory"]
    result = capabilities()
    if not result['supported']:
        return result
    # Verify a clean baseline, then use only runtime rules. Existing unrelated
    # config errors are never "fixed" by this presentation layer.
    errors = run(['hyprctl', 'configerrors'])
    if errors and errors.lower() not in ('ok', 'no errors', '[]'):
        result.update(message='Existing compositor config errors prevent a safe blur update; tinted fallback is active.')
        if not enabled:
            run(['hyprctl', 'eval', settings_program(program(False, request.get('owner', ''), cleanup),request,cleanup)])
        return result
    expression=program(enabled, request.get('owner', ''), cleanup, request.get('barBlur', True), request.get('launcherBlur', True), backdrop)
    response = run(['hyprctl', 'eval', settings_program(expression,request,cleanup)])
    if response != 'ok':
        result.update(ok=False, message='RAGE session rules could not be updated; tinted fallback is active.')
        return result
    result['active'] = enabled and result.get('globalBlur', False)
    result['launcherActive'] = result['active'] and request.get('launcherBlur', True)
    result['backdropActive'] = backdrop and result.get('globalBlur', False)
    result['settingsActive']=request.get('settingsPresentation',False) and request.get('settingsBlur',False) and result.get('globalBlur',False) and not request['performance'] and not request['lowMemory']
    result['hyprSettingsActive']=request.get('settingsPresentation',False) and request.get('hyprSettingsBlur',False) and result.get('globalBlur',False) and not request['performance'] and not request['lowMemory']
    result['rulesEnabled'] = enabled or backdrop or request.get('settingsPresentation',False)
    if not enabled and not backdrop and (result['settingsActive'] or result['hyprSettingsActive']):
        result['message']='Settings backdrop blur is active independently; global RAGE material remains disabled.'
    elif not enabled and not backdrop:
        result['message'] = 'RAGE blur rules are disabled. User compositor blur settings are unchanged.'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('status', 'apply', 'disable'))
    parser.add_argument('--owner', default='')
    args = parser.parse_args()
    try:
        if args.action == 'status':
            result = capabilities()
        elif args.action == 'disable':
            result = apply(dict(enabled=False, blur=False, performance=False, lowMemory=False, owner=args.owner), cleanup=True)
        else:
            payload = sys.stdin.readline(8193)
            if len(payload) > 8192:
                raise ValueError('Request too large')
            result = apply(json.loads(payload))
    except (ValueError, OSError, subprocess.SubprocessError):
        result = dict(ok=False, supported=False, active=False, independentStrength=False,
                      message='Unable to update RAGE session rules; readable tinted fallback is active.')
    print(json.dumps(result))
    return 0 if result.get('ok') else 1


if __name__ == '__main__':
    raise SystemExit(main())
