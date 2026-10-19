#!/usr/bin/env python3
"""Launch RusticQ's standalone WlSessionLock/PAM session locker.

No password handling here. Fail closed: NEVER try another locker after a native
locker might have requested ext-session-lock-v1. Explicit 'legacy' is available
for emergency use before native lock starts.
"""
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
LOCK_SOURCE = ROOT / 'lockscreen.qml'
VERSION = re.compile(r'(\d+)\.(\d+)\.(\d+)')


def secure_dir():
    root = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid())))
    if not root.is_dir() or root.is_symlink() or root.stat().st_uid != os.getuid():
        raise RuntimeError('A valid private XDG_RUNTIME_DIR is required for secure locking')
    folder = root / 'rusticq-native-lock'
    if folder.is_symlink():
        raise RuntimeError('Refusing symlinked lock runtime directory')
    folder.mkdir(mode=0o700, exist_ok=True)
    if folder.stat().st_uid != os.getuid():
        raise RuntimeError('Invalid lock runtime directory owner')
    folder.chmod(0o700)
    return folder


def quickshell_binary():
    return shutil.which('qs') or shutil.which('quickshell')


def preflight():
    qs = quickshell_binary()
    if not qs:
        raise RuntimeError('Quickshell executable (qs) not found')
    if not LOCK_SOURCE.is_file():
        raise RuntimeError('The standalone RusticQ locker source is missing')
    if not os.environ.get('WAYLAND_DISPLAY'):
        raise RuntimeError('No Wayland session detected')
    service = Path('/etc/pam.d/login')
    if not service.is_file():
        raise RuntimeError('PAM login service missing: /etc/pam.d/login')
    result = subprocess.run([qs, '--version'], capture_output=True, text=True, timeout=4)
    if result.returncode != 0:
        raise RuntimeError('Cannot determine Quickshell version')
    match = VERSION.search(result.stdout + result.stderr)
    if not match or tuple(map(int, match.groups())) < (0, 3, 1):
        raise RuntimeError('Quickshell 0.3.1 or newer is required for native lock')
    return qs


def start():
    qs = preflight()
    runtime = secure_dir()
    lockfile = runtime / 'single-instance.lock'
    if lockfile.is_symlink():
        raise RuntimeError('Invalid native lock coordination file')
    fd = os.open(lockfile, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return dict(ok=False, message='A RusticQ native locker is already running')
        log_path = runtime / 'native-lock.log'
        if log_path.is_symlink():
            raise RuntimeError('Invalid native lock log path')
        logfd = os.open(log_path, os.O_CREAT | os.O_APPEND | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
        try:
            # Child inherits only the flock FD, so a second native locker cannot
            # race the first one, even after the launcher exits.
            proc = subprocess.Popen([qs, '-p', str(LOCK_SOURCE)],
                                    stdin=subprocess.DEVNULL, stdout=logfd, stderr=logfd,
                                    pass_fds=(fd,), start_new_session=True, close_fds=True)
        finally:
            os.close(logfd)
        time.sleep(0.55)
        rc = proc.poll()
        if rc is not None:
            return dict(ok=False, message='Native lock process exited (code ' + str(rc) + '). Check ' + str(log_path) + ' BEFORE retrying; the compositor may still be locked.')
        return dict(ok=True, message='RusticQ native WlSessionLock/PAM starting', pid=proc.pid)
    finally:
        os.close(fd)


def status():
    qs = quickshell_binary()
    return dict(ok=True, backend='Quickshell WlSessionLock + PAM',
                installed=bool(qs and LOCK_SOURCE.is_file()),
                wayland=bool(os.environ.get('WAYLAND_DISPLAY')),
                pam_login=Path('/etc/pam.d/login').is_file(),
                fallback='Hyprlock available by explicit legacy command only')


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ('status', 'prepare', 'start', 'legacy'):
        raise ValueError('Usage: rusticq-native-lock.py status|prepare|start|legacy')
    command = sys.argv[1]
    if command == 'status':
        return status()
    if command == 'prepare':
        preflight()
        return dict(ok=True, message='Quickshell, Wayland and PAM preflight passed (NOT locked)')
    if command == 'legacy':
        fallback = ROOT / 'scripts' / 'rusticq-lockscreen.py'
        result = subprocess.run([sys.executable, str(fallback), 'lock'],
                                capture_output=True, text=True, timeout=8)
        try:
            return json.loads(result.stdout)
        except (ValueError, TypeError):
            raise RuntimeError('Legacy locker failed: ' + (result.stderr or 'no response')[-220:])
    return start()


if __name__ == '__main__':
    try:
        response = main()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        response = dict(ok=False, message=str(error))
    print(json.dumps(response, ensure_ascii=False))
    raise SystemExit(0 if response.get('ok') else 1)
