#!/usr/bin/env python3
"""Read-only diagnostics for the current Freedesktop notification bus owner.

Used by RusticQ's Notification Center. It deliberately never stops another
notification daemon, rewrites a system unit, or claims a D-Bus name itself.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

DBUS_NAME = 'org.freedesktop.Notifications'


def get_status(self_pid=None, output=None, returncode=None):
    if output is None:
        try:
            result = subprocess.run(['busctl', '--user', '--no-pager', 'status', DBUS_NAME],
                                    text=True, capture_output=True, timeout=4)
        except (OSError, subprocess.TimeoutExpired) as exc:
            return dict(state='error', owner='Unavailable', pid=None, suggestion=f'Cannot query session D-Bus: {exc}')
        output = result.stdout + '\n' + result.stderr
        returncode = result.returncode
    if returncode != 0:
        no_owner = re.search(r'not provided|not found|no such|has no owner|name .+ not owned|is not owned', output, re.I)
        if no_owner:
            return dict(state='free', owner='No notification server yet', pid=None,
                        suggestion='No owner found. RusticQ can register as the notification server.')
        return dict(state='error', owner='Unknown', pid=None,
                    suggestion='Could not query notification owner; check session D-Bus and busctl.')

    # busctl status prints "PID=1234", sometimes with trailing owner metadata.
    match = re.search(r'\bPID\s*[=:]\s*(\d+)', output)
    owner_pid = int(match.group(1)) if match else None
    name = ''
    if owner_pid:
        try:
            name = (Path('/proc') / str(owner_pid) / 'comm').read_text().strip()
        except OSError:
            pass
    if not name:
        match = re.search(r'\b(?:Comm|Name)\s*[=:]\s*(\S+)', output)
        if match:
            name = match.group(1)
    name = name or 'Existing notification service'

    if self_pid and owner_pid == self_pid:
        return dict(state='owned', owner='RusticQ (this Quickshell process)', pid=owner_pid,
                    suggestion='RusticQ owns org.freedesktop.Notifications. Send a test notification to verify the toast and history.')

    lower = (name + ' ' + output).lower()
    if 'omarchy' in lower or 'omarchy-shell' in lower:
        suggestion = ('Omarchy is handling notifications. For Omarchy Quattro, disable the '
                      'omarchy.notifications plugin and restart Omarchy shell ONLY if you wish '
                      'to replace its notification system with RusticQ. Verify your Omarchy version first.')
    elif 'mako' in lower:
        suggestion = 'Mako owns notifications. Stop its service/autostart first if you want RusticQ to receive them.'
    elif 'dunst' in lower:
        suggestion = 'Dunst owns notifications. Stop Dunst through its service/autostart first if you want RusticQ to receive them.'
    elif 'swaync' in lower:
        suggestion = 'SwayNC owns notifications. Stop its service/autostart first if you want RusticQ to receive them.'
    elif 'quickshell' in lower:
        suggestion = 'Another Quickshell instance may own notifications. Check pgrep -af quickshell and any Omarchy notification plugin.'
    else:
        suggestion = 'Another service owns the notification D-Bus name. Inspect busctl --user status org.freedesktop.Notifications.'
    return dict(state='conflict', owner=name, pid=owner_pid, suggestion=suggestion)


def main():
    self_pid = 0
    if len(sys.argv) > 1:
        try:
            self_pid = int(sys.argv[1])
        except (ValueError, OverflowError):
            pass
    print(json.dumps(get_status(self_pid)))


if __name__ == '__main__':
    main()
