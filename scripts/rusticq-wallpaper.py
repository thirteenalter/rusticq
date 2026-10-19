#!/usr/bin/env python3
"""RusticQ wallpaper backend, including a single managed swaybg process.

No shell command strings, no automatic package installation, no system-level edits.
Unmanaged wallpaper processes are never stopped without --replace-conflicts.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ALLOWED_SUFFIXES = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'}
WALLPAPER_PROCESS_NAMES = {'swaybg', 'hyprpaper', 'swww-daemon', 'awww-daemon'}
BACKENDS = ('swaybg', 'hyprpaper', 'awww', 'swww')


def emit(ok, message, backend='', **additional):
    print(json.dumps({'ok': ok, 'message': message, 'backend': backend, **additional}))
    return 0 if ok else 1


def runtime_dir():
    candidate = os.environ.get('XDG_RUNTIME_DIR')
    if candidate and Path(candidate).is_dir() and not Path(candidate).is_symlink() and Path(candidate).stat().st_uid == os.getuid():
        base = Path(candidate)
    else:
        base = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state')))
    folder = base / 'rusticq-wallpaper'
    if folder.is_symlink() or (folder.exists() and not folder.is_dir()):
        raise ValueError('Unsafe wallpaper state directory')
    folder.mkdir(parents=True, mode=0o700, exist_ok=True)
    if folder.stat().st_uid != os.getuid():
        raise ValueError('Wallpaper state directory owner mismatch')
    folder.chmod(0o700)
    return folder


def proc_start(pid):
    try:
        content = (Path('/proc') / str(pid) / 'stat').read_text()
        return content.rsplit(')', 1)[1].strip().split()[19]  # field 22
    except (OSError, IndexError, ValueError):
        return None


def is_our_swaybg(pid, start):
    try:
        proc = Path('/proc') / str(pid)
        return (pid > 0 and proc.stat().st_uid == os.getuid()
                and proc_start(pid) == str(start)
                and (proc / 'comm').read_text().strip() == 'swaybg')
    except (OSError, ValueError):
        return False


def matches_wayland_session(pid):
    """Only manage wallpaper daemons launched on this same Wayland display."""
    current = os.environ.get('WAYLAND_DISPLAY')
    if not current:
        return False
    try:
        env = (Path('/proc') / str(pid) / 'environ').read_bytes().split(b'\0')
        return (b'WAYLAND_DISPLAY=' + os.fsencode(current)) in env
    except (OSError, ValueError):
        return False


def live_wallpaper_processes():
    entries = []
    for p in Path('/proc').iterdir():
        if not p.name.isdecimal():
            continue
        try:
            if p.stat().st_uid != os.getuid():
                continue
            name = (p / 'comm').read_text().strip()
            if name in WALLPAPER_PROCESS_NAMES:
                entries.append({'pid': int(p.name), 'name': name, 'start': proc_start(int(p.name))})
        except (OSError, ValueError):
            continue
    return entries


def read_state(folder):
    path = folder / 'managed.json'
    if path.is_symlink():
        raise ValueError('Unsafe managed wallpaper state')
    try:
        item = json.loads(path.read_text())
        if item.get('backend') == 'swaybg' and isinstance(item.get('pid'), int):
            return item
    except (OSError, ValueError, AttributeError):
        pass
    return {}


def write_state(folder, data):
    fd, temp = tempfile.mkstemp(prefix='.managed-', dir=folder)
    try:
        with os.fdopen(fd, 'w') as handle:
            os.fchmod(handle.fileno(), 0o600)
            json.dump(data, handle)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, folder / 'managed.json')
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def stop_owned(pid, start):
    if not is_our_swaybg(pid, start):
        return False
    os.kill(pid, signal.SIGTERM)
    for _ in range(12):
        if not is_our_swaybg(pid, start):
            return True
        time.sleep(.05)
    # No SIGKILL or termination based on PID alone.
    raise RuntimeError('Previously managed swaybg did not exit; review it before retrying')


def validate_image(path):
    image = Path(path).expanduser().resolve(strict=True)
    image.relative_to(Path.home().resolve())
    if not image.is_file() or image.suffix.lower() not in ALLOWED_SUFFIXES:
        raise ValueError('Choose a PNG, JPEG, WebP or BMP image from your home directory.')
    if image.stat().st_size > 70 * 1024 * 1024:
        raise ValueError('Image exceeds 70 MiB.')
    return image


def run(argv):
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=12,
                                stdin=subprocess.DEVNULL)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    return result.returncode == 0, (result.stderr or result.stdout).strip()[-260:]


def apply_swaybg(image, mode='fill', output='*', replace_conflicts=False):
    if not shutil.which('swaybg'):
        raise RuntimeError('swaybg is not installed. Install optional package swaybg in Settings → Integration.')
    if not os.environ.get('WAYLAND_DISPLAY'):
        raise RuntimeError('Wayland session not detected (WAYLAND_DISPLAY missing).')
    if mode not in ('fill', 'fit', 'stretch', 'center', 'tile'):
        raise ValueError('Invalid wallpaper scaling mode.')
    if output != '*' and (not output or len(output) > 80 or any(c not in 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.:' for c in output)):
        raise ValueError('Invalid output name.')
    folder = runtime_dir()
    with (folder / 'lock').open('a+') as lockfile:
        fcntl.flock(lockfile, fcntl.LOCK_EX)
        previous = read_state(folder)
        owned_pid = previous.get('pid', -1)
        is_owned = is_our_swaybg(owned_pid, previous.get('start', ''))
        running = live_wallpaper_processes()
        conflicts = [entry for entry in running if not (is_owned and entry['pid'] == owned_pid)]
        # Never terminate a process from a different Wayland session.
        if is_owned and not conflicts and previous.get('image') == str(image) and previous.get('mode') == mode and previous.get('output') == output:
            return {'ok': True, 'message': 'Low Memory wallpaper already active; no extra daemon started.',
                    'backend': 'swaybg', 'pid': owned_pid, 'reused': True}
        if conflicts and replace_conflicts and any(not matches_wayland_session(x['pid']) for x in conflicts):
            raise RuntimeError('Wallpaper processes on another Wayland session cannot be replaced safely.')
        if conflicts and not replace_conflicts:
            names = ', '.join(sorted(set(x['name'] for x in conflicts)))
            raise RuntimeError('Another wallpaper backend is running (' + names + '). Enable "Replace wallpaper process" in Settings to switch explicitly; RusticQ will not stop it silently.')
        argv = ['swaybg', '-o', output, '-i', str(image), '-m', mode]
        process = subprocess.Popen(argv, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   start_new_session=True, close_fds=True)
        try:
            time.sleep(.35)
            if process.poll() is not None:
                raise RuntimeError('swaybg exited immediately; check Wayland session or wallpaper format.')
            start = proc_start(process.pid)
            if not start:
                raise RuntimeError('Could not verify the new wallpaper process.')
            # Persist first, then retire old wallpaper providers, so a state
            # write failure never leaves the session without the old background.
            write_state(folder, {'backend': 'swaybg', 'pid': process.pid, 'start': start,
                                 'image': str(image), 'mode': mode, 'output': output})
            try:
                if is_owned:
                    stop_owned(owned_pid, previous['start'])
            except (RuntimeError, OSError):
                if previous:
                    write_state(folder, previous)
                else:
                    (folder / 'managed.json').unlink(missing_ok=True)
                raise
            stopped = []
            if replace_conflicts:
                for conflict in conflicts:
                    p = Path('/proc') / str(conflict['pid'])
                    try:
                        if (conflict.get('start') and proc_start(conflict['pid']) == conflict['start']
                                and p.stat().st_uid == os.getuid()
                                and (p / 'comm').read_text().strip() == conflict['name']):
                            os.kill(conflict['pid'], signal.SIGTERM)
                            stopped.append(conflict['name'])
                    except (OSError, ProcessLookupError):
                        pass
            return {'ok': True, 'message': 'Low Memory wallpaper applied using one managed swaybg process.' +
                    (' Previous wallpaper process stopped: ' + ', '.join(stopped) + '.' if stopped else ''),
                    'backend': 'swaybg', 'pid': process.pid, 'reused': False, 'stopped': stopped}
        except Exception:
            if process.poll() is None:
                process.terminate()
            raise


def status():
    """Read-only diagnostics for Settings; never touches other wallpaper daemons."""
    folder = runtime_dir()
    state = read_state(folder)
    pid = state.get('pid', -1)
    owned = is_our_swaybg(pid, state.get('start', ''))
    return {'ok': True, 'backend': state.get('backend', '') if owned else '',
            'managed_active': owned, 'managed_pid': pid if owned else None,
            'running': live_wallpaper_processes(),
            'installed': {name: bool(shutil.which(name)) for name in BACKENDS},
            'message': 'Wallpaper process inventory (current Wayland session only).'}


def apply(path, backend, mode='fill', output='*', replace_conflicts=False):
    try:
        image = validate_image(path)
        candidates = ['swaybg', 'awww', 'hyprpaper', 'swww'] if backend == 'auto' else [backend]
        for b in candidates:
            if b == 'swaybg':
                if backend == 'auto' and not shutil.which('swaybg'):
                    continue
                return emit(**apply_swaybg(image, mode, output, replace_conflicts))
            if b not in BACKENDS or not shutil.which(b):
                if backend != 'auto':
                    return emit(False, b + ' is not installed', b)
                continue
            if b == 'swww':
                success, info = run(['swww', 'img', str(image), '--transition-type', 'fade', '--transition-duration', '0.6'])
            elif b == 'awww':
                success, info = run(['awww', 'img', str(image), '--transition-type', 'fade'])
            else:
                success, info = run(['hyprctl', 'hyprpaper', 'preload', str(image)]) if shutil.which('hyprctl') else (False, 'hyprctl is missing')
                if success:
                    success, info = run(['hyprctl', 'hyprpaper', 'wallpaper', f',{image}'])
            if success:
                # A previous swaybg started by RusticQ is retired only after
                # the selected external backend confirmed its new wallpaper.
                state_folder = runtime_dir()
                with (state_folder / 'lock').open('a+') as lockfile:
                    fcntl.flock(lockfile, fcntl.LOCK_EX)
                    previous = read_state(state_folder)
                    if is_our_swaybg(previous.get('pid', -1), previous.get('start', '')):
                        stop_owned(previous['pid'], previous['start'])
                        (state_folder / 'managed.json').unlink(missing_ok=True)
                return emit(True, 'Wallpaper applied using ' + b + '. Aether palette unchanged.', b)
            if backend != 'auto':
                return emit(False, info or b + ' is unavailable', b)
        return emit(False, 'No wallpaper backend available. Install swaybg from Settings → Integration.')
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        return emit(False, str(exc), backend)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('path', nargs='?')
    parser.add_argument('--status', action='store_true', help='Read-only wallpaper backend diagnostics')
    parser.add_argument('--backend', choices=['auto', *BACKENDS], default='swaybg')
    parser.add_argument('--mode', choices=['fill', 'fit', 'stretch', 'center', 'tile'], default='fill')
    parser.add_argument('--output', default='*')
    parser.add_argument('--replace-conflicts', action='store_true', help='Explicitly stop other user-owned wallpaper processes after swaybg starts')
    args = parser.parse_args()
    if args.status:
        try:
            print(json.dumps(status()))
            return 0
        except (OSError, RuntimeError, ValueError) as exc:
            return emit(False, str(exc))
    if not args.path:
        return emit(False, 'Choose a wallpaper image before applying.')
    return apply(args.path, args.backend, args.mode, args.output, args.replace_conflicts)


if __name__ == '__main__':
    sys.exit(main())
