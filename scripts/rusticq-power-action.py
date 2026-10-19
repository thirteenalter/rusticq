#!/usr/bin/env python3
"""User-invoked session actions for RusticQ's keyboard power menu.

No sudo shell strings; no background power management. Poweroff/reboot require
an extra in-GUI confirmation and systemd-logind/Polkit handles authorization.
"""
import json
import shutil
import subprocess
import sys
import os
import time

ACTIONS = frozenset(('screensaver', 'lock', 'suspend', 'logout', 'reboot', 'shutdown'))


def action_command(name):
    if name not in ACTIONS:
        raise ValueError('Invalid power action')
    if name == 'lock':
        # Native locker is a separate Quickshell process; authentication is PAM.
        if not shutil.which('qs') and not shutil.which('quickshell'):
            raise RuntimeError('Quickshell 0.3.1+ is required for RusticQ Native Lock')
        return [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rusticq-native-lock.py'), 'start']
    if name == 'screensaver':
        # Omarchy Quattro draws its own ASCII art, not a hyprlock/DPMS blank.
        # `force` starts it even if automatic idle screensavers are disabled.
        if not shutil.which('omarchy-launch-screensaver'):
            raise RuntimeError('Omarchy screensaver unavailable: omarchy-launch-screensaver is not installed')
        return ['omarchy-launch-screensaver', 'force']
    if name == 'logout':
        # UWSM must stop its managed session in order, before the compositor.
        if shutil.which('uwsm'):
            active = subprocess.run(['uwsm', 'check', 'is-active', 'Hyprland'],
                                    capture_output=True, text=True, timeout=3,
                                    stdin=subprocess.DEVNULL, check=False)
            if active.returncode == 0:
                return ['uwsm', 'stop']
        if not shutil.which('hyprctl'):
            raise RuntimeError('hyprctl is required to log out of Hyprland')
        return ['hyprctl', 'dispatch', 'hl.dsp.exit()']
    if not shutil.which('systemctl'):
        raise RuntimeError('systemctl is required for suspend/reboot/shutdown')
    return ['systemctl', {'suspend':'suspend','reboot':'reboot','shutdown':'poweroff'}[name]]


def run(name):
    argv = action_command(name)
    if name == 'screensaver':
        # The Omarchy terminal screensaver requires the menu layer to disappear
        # BEFORE startup (otherwise it may flash in a small window and exit).
        subprocess.Popen([sys.executable, os.path.abspath(__file__), '--start-omarchy-screensaver'],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
        return {'ok': True, 'message': 'Omarchy ASCII screensaver starting'}
    if name == 'lock':
        # Validate prerequisites before dismissing the overlay. Do not launch
        # the locker while the full-screen power menu owns keyboard focus.
        helper = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rusticq-native-lock.py')
        prepared = subprocess.run([sys.executable, helper, 'prepare'], capture_output=True,
                                  text=True, timeout=8, stdin=subprocess.DEVNULL, check=False)
        try:
            response = json.loads(prepared.stdout)
        except (ValueError, TypeError):
            response = {'ok': False, 'message': (prepared.stderr or 'Native lock preflight failed')[-300:]}
        if prepared.returncode != 0 or response.get('ok') is not True:
            return {'ok': False, 'message': response.get('message', 'Cannot initialize RusticQ Native Lock')}
        subprocess.Popen([sys.executable, os.path.abspath(__file__), '--start-rusticq-lock'],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
        return {'ok': True, 'message': 'RusticQ Native Lock starts after the Power Menu closes'}
    proc = subprocess.run(argv, capture_output=True, text=True, timeout=12,
                          stdin=subprocess.DEVNULL, check=False)
    if argv == ['hyprctl', 'dispatch', 'hl.dsp.exit()']:
        # Legacy Hyprland rejects Lua expressions before executing anything.
        # Retry only that explicit rejection, never a timeout or socket error.
        if 'invalid dispatcher' in (proc.stdout + proc.stderr).lower():
            proc = subprocess.run(['hyprctl', 'dispatch', 'exit'], capture_output=True,
                                  text=True, timeout=12, stdin=subprocess.DEVNULL,
                                  check=False)
        # Some hyprctl versions report IPC errors on stdout with exit code 0.
        if proc.returncode == 0 and proc.stdout.strip().lower() != 'ok':
            return {'ok': False, 'message': (proc.stderr or proc.stdout or 'Hyprland did not acknowledge logout')[-350:]}
    if proc.returncode != 0:
        return {'ok': False, 'message': (proc.stderr or proc.stdout or 'System service rejected action')[-350:]}
    return {'ok': True, 'message': 'System accepted action: ' + name}


def start_rusticq_lock():
    # The menu's WlrLayer.Overlay and keyboard focus grab must release first.
    time.sleep(.85)
    helper = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rusticq-native-lock.py')
    # Dedicated Quickshell config owns WlSessionLock and PAM authentication.
    result = subprocess.run([sys.executable, helper, 'start'], stdin=subprocess.DEVNULL,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            check=False, timeout=9)
    return result.returncode


def start_native_screensaver():
    # Detached helper outlives Quickshell's LazyLoader and closes its fullscreen
    # overlay before Omarchy creates the ASCII screensaver terminal.
    time.sleep(.9)
    argv = action_command('screensaver')
    subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2:
            raise ValueError('Expected one power action')
        if sys.argv[1] == '--start-omarchy-screensaver':
            start_native_screensaver()
            sys.exit(0)
        if sys.argv[1] == '--start-rusticq-lock':
            sys.exit(start_rusticq_lock())
        print(json.dumps(run(sys.argv[1])))
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({'ok': False, 'message': str(exc)}))
        sys.exit(1)
