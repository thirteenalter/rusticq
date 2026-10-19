#!/usr/bin/env python3
"""RusticQ user CLI. Read-only by default; destructive operations need exact confirmation.

Usage: rusticq status | doctor | config status|backup|list|restore | ipc action | watchdog status|install
Running `rusticq` without a subcommand continues launching the normal Quickshell desktop.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts'


def import_from(filename, name):
    spec = importlib.util.spec_from_file_location(name, SCRIPT / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def execute(argv):
    value = subprocess.run(argv, capture_output=True, text=True, check=False, timeout=12)
    if value.returncode != 0:
        raise RuntimeError((value.stderr or value.stdout).strip()[:600] or 'Command failed')
    return value


def config_action(action, kind='settings', snapshot_id='', confirm=''):
    # Delegate to the guard's *locked* CLI; importing Guard directly would skip
    # flock and could race with backups initiated from the Settings window.
    allowed = {'status', 'backup', 'list', 'restore'}
    if action not in allowed or kind not in ('settings', 'usage'):
        raise ValueError('Unrecognized config action or kind')
    cmd = [sys.executable, str(SCRIPT / 'rusticq-config-guard.py'), action,
           '--kind', kind]
    if action == 'restore':
        cmd += ['--id', snapshot_id, '--confirm', confirm]
    data = json.loads(execute(cmd).stdout)
    if data.get('ok') is not True:
        raise RuntimeError(data.get('error', 'Config guard failed'))
    return data['data']


def ipc_action(action):
    # Retrieve the live source catalogue, do not accept raw Hyprland/JS commands.
    parsed = json.loads(execute([sys.executable, str(SCRIPT / 'rustiq-desktop-integration.py'), 'actions']).stdout)
    allowed = {a['key'] for a in parsed.get('actions', [])}
    if action not in allowed:
        raise ValueError('Unsupported IPC action: ' + action)
    result = execute(['quickshell', 'ipc', '-p', str(ROOT), 'call', 'rusticq', 'dispatch', action])
    return {'action': action, 'output': result.stdout.strip()}


def watchdog_action(action, confirm=''):
    helper = SCRIPT / 'rusticq-watchdog.py'
    if action == 'status':
        result = execute([sys.executable, str(helper), 'status', '--json'])
    elif action == 'install':
        if confirm != 'INSTALL WATCHDOG':
            raise ValueError('Installing watchdog unit requires --confirm "INSTALL WATCHDOG"')
        result = execute([sys.executable, str(helper), 'install', '--confirm', confirm, '--json'])
    else:
        raise ValueError('Invalid watchdog action')
    return json.loads(result.stdout)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', action='store_true', dest='json_flag')
    subs = parser.add_subparsers(dest='command', required=True)
    subs.add_parser('status')
    subs.add_parser('doctor')
    c = subs.add_parser('config')
    c.add_argument('action', choices=['status', 'list', 'backup', 'restore'])
    c.add_argument('kind', nargs='?', choices=['settings', 'usage'], default='settings')
    c.add_argument('snapshot_id', nargs='?', default='')
    c.add_argument('--confirm', default='')
    i = subs.add_parser('ipc')
    i.add_argument('action')
    n = subs.add_parser('notes', help='Local private Notes/Kanban')
    n.add_argument('action', choices=['list', 'add', 'move', 'toggle', 'delete'])
    n.add_argument('value', nargs='?', default='')
    n.add_argument('stage', nargs='?', default='')
    w = subs.add_parser('watchdog')
    w.add_argument('action', choices=['status', 'install'])
    w.add_argument('--confirm', default='')
    args = parser.parse_args(argv)
    try:
        if args.command == 'status':
            doctor = import_from('rusticq-doctor.py', 'rusticq_doctor_cli')
            result = {'shell_path': str(ROOT), 'doctor': doctor.doctor()['totals'],
                      'config': config_action('status'), 'watchdog': watchdog_action('status')}
        elif args.command == 'doctor':
            result = import_from('rusticq-doctor.py', 'rusticq_doctor_cli').doctor()
        elif args.command == 'config':
            result = config_action(args.action, args.kind, args.snapshot_id, args.confirm)
        elif args.command == 'ipc':
            result = ipc_action(args.action)
        elif args.command == 'notes':
            note_command = [sys.executable, str(SCRIPT / 'rusticq-notes.py'),
                            args.action, args.value]
            if args.action == 'move':
                note_command.append(args.stage)
            payload = json.loads(execute(note_command).stdout)
            if payload.get('ok') is not True:
                raise RuntimeError(payload.get('message', 'Notes backend failed'))
            result = payload['result']
        else:
            result = watchdog_action(args.action, args.confirm)
        print(json.dumps({'ok': True, 'result': result}, indent=2, ensure_ascii=False)
              if args.json_flag or args.command in ('status', 'doctor')
              else json.dumps({'ok': True, 'result': result}, ensure_ascii=False))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
