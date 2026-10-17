#!/usr/bin/env python3
"""Local Wayland recording helper. No shell interpolation and no network access."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'rusticq-recorder'
STATE = RUNTIME / 'active.json'
VIDEOS = Path(os.environ.get('XDG_VIDEOS_DIR', str(Path.home() / 'Videos'))).expanduser() / 'RusticQ'


def reply(ok, message, **data):
    print(json.dumps({'ok': ok, 'message': message, **data}, ensure_ascii=False))
    return 0 if ok else 1


def running():
    try:
        data = json.loads(STATE.read_text())
        pid = int(data['pid'])
        if pid <= 1:
            return None
        # Ensure a stale pid can never stop an unrelated process.
        cmdline = Path(f'/proc/{pid}/cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace')
        if 'wf-recorder' not in cmdline or str(data.get('file', '')) not in cmdline:
            return None
        os.kill(pid, 0)
        return data
    except (OSError, ValueError, KeyError, json.JSONDecodeError, PermissionError):
        return None


def notify(title, message):
    if shutil.which('notify-send'):
        subprocess.Popen(['notify-send', '-a', 'RusticQ', title, message],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def select_geometry(mode):
    if not shutil.which('slurp'):
        raise RuntimeError('Install slurp to select a screen or region.')
    selection = subprocess.run(['slurp', '-o'] if mode in ('start-screen', 'start-audio') else ['slurp'],
                               capture_output=True, text=True, timeout=120, check=False)
    if selection.returncode != 0 or not selection.stdout.strip():
        raise RuntimeError('Selection cancelled; no recording started.')
    return selection.stdout.strip()


def start(mode):
    if running():
        return reply(False, 'A RusticQ recording is already running.')
    if not shutil.which('wf-recorder'):
        notify('RusticQ Recorder', 'wf-recorder is not installed. Install it first.')
        return reply(False, 'wf-recorder is not installed. Install it first.')
    try:
        geom = select_geometry(mode)
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        if 'cancelled' not in str(exc):
            notify('RusticQ Recorder', str(exc))
        return reply(False, str(exc))
    VIDEOS.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    filename = VIDEOS / ('rusticq-' + time.strftime('%Y%m%d-%H%M%S') + '-' + str(os.getpid()) + '.mp4')
    cmd = ['wf-recorder', '-g', geom, '-f', str(filename), '-r', '30']
    if mode == 'start-audio':
        cmd.append('--audio')
    log = RUNTIME / 'recorder.log'
    with log.open('ab') as stream:
        proc = subprocess.Popen(cmd, stdout=stream, stderr=stream, stdin=subprocess.DEVNULL,
                                start_new_session=True, close_fds=True)
    time.sleep(0.5)
    if proc.poll() is not None:
        notify('RusticQ Recorder', 'Recorder failed to start. Check ' + str(log))
        return reply(False, 'Recorder exited immediately. Check ' + str(log))
    STATE.write_text(json.dumps({'pid': proc.pid, 'file': str(filename), 'started': time.time()}))
    notify('Screen recording started', 'Select Stop recording in RusticQ → Share when finished.')
    return reply(True, 'Recording started.', active=True, file=str(filename))


def stop():
    data = running()
    if not data:
        STATE.unlink(missing_ok=True)
        return reply(False, 'No active recording.')
    try:
        os.kill(int(data['pid']), signal.SIGINT)
    except ProcessLookupError:
        pass
    STATE.unlink(missing_ok=True)
    notify('Screen recording stopping', 'Saving recording to ' + data['file'])
    return reply(True, 'Recorder stop requested. MP4 is being finalized.', active=False, file=data['file'])


def status():
    data = running()
    if not data:
        STATE.unlink(missing_ok=True)
    return reply(True, 'Recording in progress' if data else 'Not recording',
                 active=bool(data), file=data['file'] if data else '')


def portal_check():
    states = {}
    for service in ('xdg-desktop-portal.service', 'xdg-desktop-portal-hyprland.service'):
        try:
            result = subprocess.run(['systemctl', '--user', 'is-active', service],
                                    capture_output=True, text=True, timeout=3)
            states[service] = result.stdout.strip() or 'unknown'
        except (OSError, subprocess.TimeoutExpired):
            states[service] = 'unavailable'
    good = all(x == 'active' for x in states.values())
    msg = ('ScreenCast portal ready. The requesting application will trigger the Hyprland selector.'
           if good else 'Check xdg-desktop-portal-hyprland and xdg-desktop-portal user services.')
    notify('RusticQ Screen Sharing', msg)
    return reply(True, msg, portal=states, ready=good)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ''
    if mode in ('start-screen', 'start-region', 'start-audio'):
        return start(mode)
    if mode == 'stop':
        return stop()
    if mode == 'status':
        return status()
    if mode == 'folder':
        VIDEOS.mkdir(parents=True, exist_ok=True)
        if shutil.which('xdg-open'):
            subprocess.Popen(['xdg-open', str(VIDEOS)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return reply(True, str(VIDEOS))
    if mode == 'portal-check':
        return portal_check()
    return reply(False, 'Usage: rustiq-record.py start-screen|start-region|start-audio|stop|status|folder|portal-check')


if __name__ == '__main__':
    sys.exit(main())
