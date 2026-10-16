#!/usr/bin/env python3
"""RusticQ Arch/Omarchy updater. Explicit UI-triggered actions; no shell eval.

Command modes: check, start, run, status.  `start` detaches `run`, so a Quickshell
reload or navigation does not kill the ongoing pacman transaction.
"""
import fcntl
import errno
import pty
import select
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state') / 'rustiq' / 'updater'
STATE = ROOT / 'status.json'
LOG = ROOT / 'pacman.log'
LOCK = ROOT / 'upgrade.lock'
OMARCHY_GUARD = Path('/usr/share/libalpm/hooks/00-omarchy-update-guard.hook')
OMARCHY_LOG = Path('/tmp/omarchy-update.log')
GUARD_HINT = re.compile(r'(OMARCHY_ALLOW_DIRECT_PACMAN|omarchy.update.pacman.guard|omarchy update|Omarchy update entrypoint)', re.I)


def is_omarchy():
    """Prefer Omarchy's supported upgrade workflow when it is installed."""
    return bool(shutil.which('omarchy')) or OMARCHY_GUARD.exists()


def choose_terminal():
    """Use known interactive terminal executors, never a shell command string."""
    omarchy = shutil.which('omarchy')
    if not omarchy:
        return None
    options = (
        ('xdg-terminal-exec', lambda path: [path, '--', omarchy, 'update']),
        ('foot', lambda path: [path, '-e', omarchy, 'update']),
        ('kitty', lambda path: [path, '-e', omarchy, 'update']),
        ('alacritty', lambda path: [path, '-e', omarchy, 'update']),
        ('ghostty', lambda path: [path, '-e', omarchy, 'update']),
        ('wezterm', lambda path: [path, 'start', '--', omarchy, 'update']),
        ('konsole', lambda path: [path, '-e', omarchy, 'update']),
    )
    for executable, make in options:
        path = shutil.which(executable)
        if path:
            return make(path)
    return None


def omarchy_guard_blocked(log_lines):
    """The guard can already have failed in an older RusticQ build."""
    recent = '\n'.join(log_lines[-100:])
    return bool(GUARD_HINT.search(recent) and
                re.search(r'failed|error|w[oó]ah partner|direct pacman', recent, re.I))


def start_omarchy_update():
    """Omarchy needs a real terminal for its interactive confirmations/migrations."""
    if not shutil.which('omarchy'):
        return dict(ok=False, message='Omarchy detected, but command `omarchy` is not on PATH. Open a terminal and run: omarchy update')
    cmd = choose_terminal()
    if not cmd:
        return dict(ok=False, message='No compatible graphical terminal found. Open your terminal and run: omarchy update')
    if status().get('busy'):
        return dict(ok=False, message='An upgrade is already running. Do not launch a second transaction.')
    try:
        proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
    except OSError as exc:
        return dict(ok=False, message='Unable to open Omarchy terminal: ' + str(exc) + '. Run: omarchy update')
    # No success claim: the terminal owns the interactive upgrade.
    write_state(state='external', pid=proc.pid, phase='omarchy', progress=-1,
                progressKind='unknown', item='', details='', completed=0, total=0,
                omarchyStartedAt=time.time(),
                message='Omarchy update opened in a terminal. Answer prompts there. Completion is not confirmed by RusticQ.')
    append_log('[OMARCHY] Opened interactive updater: omarchy update')
    return dict(ok=True, external=True, message='Omarchy update opened in a terminal. Follow its prompts and logs; no bypass applied.')
ANSI = re.compile(r'\x1b\[[0-9;?]*[ -/]*[@-~]')
COUNTER = re.compile(r'\(\s*(\d+)\s*/\s*(\d+)\s*\)')
PERCENT = re.compile(r'(?<!\d)(100|[1-9]?\d)\s*%')



class PacmanProgress:
    """Per-item, observed PTY progress only. Never extrapolate total transaction %."""
    def __init__(self):
        self.phase = 'authorization'
        self.progress = -1
        self.kind = 'unknown'
        self.item = ''
        self.completed = 0
        self.total = 0
        self.details = ''
        self.message = 'Waiting for graphical authorization…'

    def observe(self, raw):
        line = ANSI.sub('', raw).replace('\x08', '').replace('\x00', '').strip()
        if not line:
            return False
        old = (self.phase, self.progress, self.kind, self.item, self.completed,
               self.total, self.details, self.message)
        lower = line.lower()
        if 'retrieving packages' in lower or 'downloading' in lower or 'download size' in lower:
            self.phase = 'downloading'
            self.kind = 'unknown'
            self.progress = -1
        elif 'synchronizing package databases' in lower:
            self.phase = 'syncing'
            self.kind = 'unknown'
            self.progress = -1
        elif any(x in lower for x in ('checking keys in keyring', 'checking package integrity',
                                      'loading package files', 'checking for file conflicts',
                                      'checking available disk space')):
            self.phase = 'verifying'
            self.kind = 'unknown'
            self.progress = -1
        elif 'processing package changes' in lower or 'upgrading ' in lower or 'installing ' in lower:
            if self.phase != 'installing':
                self.progress = -1
                self.kind = 'unknown'
            self.phase = 'installing'
        elif 'running post-transaction hooks' in lower or 'running pre-transaction hooks' in lower:
            self.phase = 'hooks'
            self.progress = -1
            self.kind = 'unknown'
        elif 'resolving dependencies' in lower or 'looking for conflicting packages' in lower:
            self.phase = 'resolving'
        match = COUNTER.search(line)
        if match:
            n, total = int(match.group(1)), int(match.group(2))
            if 0 <= n <= total and total > 0:
                self.completed, self.total = n, total
                if self.phase not in ('downloading', 'syncing', 'verifying'):
                    self.phase = 'hooks' if 'hook' in lower else 'installing'
                self.progress = -1
                self.kind = 'counter'
        percentages = PERCENT.findall(line)
        # Pacman's bars are per-package / per-download, NOT a transaction total.
        if percentages and self.phase in ('downloading', 'syncing', 'verifying', 'installing', 'hooks'):
            self.progress = int(percentages[-1])
            self.kind = 'item'
            if 'kib' in lower or 'mib' in lower or 'gib' in lower or '/s' in lower:
                self.details = line[-190:]
                if self.phase in ('syncing', 'downloading'):
                    self.phase = 'downloading'
        if self.phase in ('downloading', 'installing'):
            if match:
                self.item = line[match.end():].strip()[:110]
            elif percentages:
                self.item = PERCENT.sub('', line).strip()[:110]
        self.message = line[:190]
        return old != (self.phase, self.progress, self.kind, self.item,
                       self.completed, self.total, self.details, self.message)

    def snapshot(self):
        return dict(phase=self.phase, progress=self.progress, progressKind=self.kind,
                    item=self.item, completed=self.completed, total=self.total,
                    details=self.details, message=self.message)


def stream_pacman(proc, master_fd, progress):
    """Read real pacman CR/NL updates from PTY, preserving the last full log."""
    buffer = bytearray()
    last_write = 0.0
    last_logged = ('', -1)
    while True:
        ready, _, _ = select.select([master_fd], [], [], 0.18)
        if ready:
            try:
                data = os.read(master_fd, 4096)
            except OSError as exc:
                if exc.errno == errno.EIO:  # PTY slave closed
                    data = b''
                else:
                    raise
            if data:
                for byte in data:
                    if byte in (10, 13):
                        if not buffer:
                            continue
                        line = buffer.decode('utf8', errors='replace')
                        buffer.clear()
                        clean = ANSI.sub('', line).strip()
                        progress.observe(clean)
                        now = time.monotonic()
                        # Throttle redraws in file, but keep distinct pacman events.
                        bucket = progress.progress // 5 if progress.progress >= 0 else -1
                        signature = (progress.phase + ':' + progress.item, bucket)
                        if not (progress.kind == 'item' and signature == last_logged and now - last_write < 1.5):
                            append_log(clean)
                            last_logged = signature
                        if now - last_write >= 0.22 or (progress.progress == 100 and progress.kind == 'item'):
                            write_state(state='running', pid=os.getpid(), **progress.snapshot())
                            last_write = now
                    elif len(buffer) < 8192:
                        buffer.append(byte)
                continue
            # master reached EOF; avoid spinning
            if proc.poll() is not None:
                break
        if proc.poll() is not None:
            # Drain possible PTY remainder before terminating.
            if not ready:
                break
    if buffer:
        clean = ANSI.sub('', buffer.decode('utf8', errors='replace')).strip()
        if clean:
            progress.observe(clean)
            append_log(clean)
    write_state(state='running', pid=os.getpid(), **progress.snapshot())


def prepare():
    ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)


def write_state(**new):
    prepare()
    state = current_state()
    state.update(new)
    tmp = ROOT / f'.status-{os.getpid()}.tmp'
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w', encoding='utf8') as f:
        json.dump(state, f)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, STATE)


def current_state():
    try:
        data = json.loads(STATE.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def append_log(message):
    prepare()
    message = ANSI.sub('', str(message)).replace('\x00', '')[:800]
    fd = os.open(LOG, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    with os.fdopen(fd, 'a', encoding='utf8') as f:
        f.write(message.rstrip() + '\n')


def running_pid(pid):
    if not isinstance(pid, int) or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def status():
    state = current_state()
    busy = state.get('state') in ('running', 'external')
    pid = state.get('pid')
    if busy and not running_pid(pid):
        busy = False
        if state.get('state') == 'running':
            state['state'] = 'interrupted'
            state['message'] = 'Updater process stopped unexpectedly. Check pacman.log and complete any unfinished transaction before more package operations.'
        # A graphical terminal may daemonize. Never infer whether the external
        # Omarchy update succeeded simply from its launcher PID exiting.
    try:
        with LOG.open(encoding='utf8', errors='replace') as f:
            # Limit log view to last 180 lines; file remains fully available on disk.
            from collections import deque
            lines = list(deque(f, maxlen=180))
    except OSError:
        lines = []
    guarded = omarchy_guard_blocked(lines)
    # The old pacman transaction may have failed before this patch was installed.
    message = state.get('message', 'No updates started')
    if guarded and state.get('state') == 'failed':
        message = 'Omarchy blocked direct pacman. Use omarchy update; do not bypass its hooks.'
    result = dict(ok=True, state=state.get('state', 'idle'), busy=busy,
                updaterMode='omarchy' if is_omarchy() else 'arch',
                omarchyGuard=guarded, recommendedCommand='omarchy update' if (guarded or is_omarchy()) else 'pacman -Syu',
                message=message,
                phase=state.get('phase', ''), progress=state.get('progress', -1),
                progressKind=state.get('progressKind', 'unknown'),
                item=state.get('item', ''), completed=state.get('completed', 0),
                total=state.get('total', 0), details=state.get('details', ''),
                count=state.get('count', 0), lines=[line.rstrip('\n') for line in lines],
                logPath=str(LOG))
    # Omarchy owns the interactive transcript, not RusticQ. Only display logs
    # belonging to a user-launched Omarchy session, and never pretend success.
    if state.get('state') == 'external' and state.get('omarchyStartedAt'):
        try:
            if OMARCHY_LOG.stat().st_mtime >= float(state['omarchyStartedAt']) - 2:
                from collections import deque
                with OMARCHY_LOG.open(encoding='utf8', errors='replace') as f:
                    result['lines'] = [ANSI.sub('', s.rstrip('\n')) for s in deque(f, maxlen=180)]
                result['logPath'] = str(OMARCHY_LOG)
        except (OSError, ValueError):
            pass
    return result


def check_updates():
    if not shutil.which('pacman'):
        return dict(ok=False, message='pacman is unavailable: this updater requires Arch Linux.')
    if not shutil.which('checkupdates'):
        return dict(ok=False, message='Install pacman-contrib to check updates safely: sudo pacman -S pacman-contrib')
    try:
        result = subprocess.run(['checkupdates', '--nocolor'], capture_output=True, text=True,
                                timeout=110, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return dict(ok=False, message='Update check failed: ' + str(exc))
    if result.returncode not in (0, 2):
        return dict(ok=False, message=(result.stderr.strip() or 'checkupdates failed')[:700])
    entries = []
    if result.returncode == 0:
        for line in result.stdout.splitlines()[:1000]:
            match = re.match(r'^(\S+)\s+(\S+)\s+->\s+(\S+)', line.strip())
            if match:
                entries.append(dict(name=match.group(1), installed=match.group(2), new=match.group(3)))
    return dict(ok=True, count=len(entries), packages=entries,
                message='No repository updates available' if not entries else f'{len(entries)} repository package updates available',
                warning='AUR packages are excluded. News and .pacnew files may require manual attention.')


def run_upgrade():
    # Even an internal/stale 'run' command must not bypass Omarchy's update pipeline.
    if is_omarchy():
        append_log('[BLOCKED] Direct pacman invocation is not supported on Omarchy. Run: omarchy update')
        write_state(state='failed', phase='setup', progress=-1, progressKind='unknown',
                    message='Direct pacman updater disabled on Omarchy. Use omarchy update.')
        return 4
    prepare()
    with LOCK.open('a+') as lock_file:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 3
        if not shutil.which('pkexec') or not Path('/usr/bin/pacman').exists():
            write_state(state='failed', pid=os.getpid(), phase='setup',
                        message='pkexec or /usr/bin/pacman is missing. Install a graphical polkit agent before upgrading.')
            append_log('[ERROR] pkexec or pacman executable not found')
            return 2
        fd = os.open(LOG, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, 'w', encoding='utf8') as log_file:
            log_file.write('RusticQ Arch Updater — full repository upgrade\nCommand: pkexec /usr/bin/pacman -Syu --noconfirm --color never\nProgress: observed current item only, not whole transaction\n\n')
        progress = PacmanProgress()
        write_state(state='running', pid=os.getpid(), **progress.snapshot())
        args = ['/usr/bin/pkexec', '/usr/bin/pacman', '-Syu', '--noconfirm', '--color', 'never']
        # A PTY makes pacman emit its actual CR-based progress instead of hiding
        # it when stdout is a pipe. Fixed arguments; no shell, no user input.
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=slave,
                                    stderr=slave, close_fds=True, env=dict(os.environ, TERM='xterm'))
            os.close(slave)
            slave = -1
            stream_pacman(proc, master, progress)
            code = proc.wait()
            if code == 0:
                append_log('[DONE] Full system update completed successfully')
                write_state(state='completed', pid=os.getpid(), phase='done', progress=100,
                            progressKind='completed', item='', details='',
                            message='System update finished. Review pacman.log for .pacnew files or restart requirements.')
            else:
                append_log(f'[FAILED] pacman/pkexec exited with code {code}')
                write_state(state='failed', pid=os.getpid(), phase='error', progress=-1,
                            progressKind='unknown', item='', details='',
                            message=f'Update failed or authorization was cancelled (exit {code}). See terminal log.')
            return code
        except (OSError, subprocess.SubprocessError) as exc:
            append_log('[ERROR] ' + str(exc))
            write_state(state='failed', phase='error', progress=-1,
                        progressKind='unknown', message=str(exc))
            return 1
        finally:
            if slave >= 0:
                os.close(slave)
            os.close(master)


def start_upgrade():
    if is_omarchy():
        return start_omarchy_update()
    if not shutil.which('pacman') or not shutil.which('pkexec'):
        return dict(ok=False, message='Arch pacman or PolicyKit (pkexec) is unavailable.')
    if status()['busy']:
        return dict(ok=False, message='An update is already running.')
    prepare()
    # Launch independently of Quickshell's lifetime: a reload must not kill pacman.
    proc = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'run'],
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
    # Mark pending immediately, avoiding a transient double-start window.
    write_state(state='running', pid=proc.pid, phase='starting', progress=-1, progressKind='unknown', item='', completed=0, total=0, details='',
                message='Starting graphical authorization…')
    return dict(ok=True, message='System update started. See progress in Settings → Arch Updater.', pid=proc.pid)


def main():
    action = sys.argv[1] if len(sys.argv) == 2 else ''
    if action == 'check':
        print(json.dumps(check_updates()))
    elif action == 'status':
        print(json.dumps(status()))
    elif action == 'start':
        print(json.dumps(start_upgrade()))
    elif action == 'run':
        return run_upgrade()
    else:
        print(json.dumps(dict(ok=False, message='Expected check, status, start or run')))
        return 2
    return 0

if __name__ == '__main__':
    sys.exit(main())
