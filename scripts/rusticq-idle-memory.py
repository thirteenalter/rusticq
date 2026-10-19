#!/usr/bin/env python3
"""Read-only desktop RAM report; optional baseline snapshot for comparisons.

The default 'free-used' metric matches free(1) approximately, rather than
claiming MemTotal-MemAvailable is the same as free's used column. Process PSS
is provided only when permitted by the kernel. This tool cannot certify idleness.
"""
import argparse
import json
import os
from pathlib import Path
import sys
import tempfile
import time

TARGET_KIB = 2 * 1024 * 1024
PROCESSES = {'quickshell', 'Hyprland', 'swaybg', 'hyprpaper', 'swww-daemon', 'awww-daemon',
             'mariadbd', 'postgres', 'ghostty', 'xdm-app', 'valkey-server'}


def meminfo():
    result = {}
    for line in Path('/proc/meminfo').read_text().splitlines():
        key, _, rest = line.partition(':')
        try:
            result[key] = int(rest.strip().split()[0])
        except (IndexError, ValueError):
            continue
    return result


def free_used_kib(mem):
    reclaimable = mem.get('KReclaimable', mem.get('SReclaimable', 0))
    cache = mem.get('Cached', 0) + mem.get('Buffers', 0) + reclaimable - mem.get('Shmem', 0)
    return max(0, mem['MemTotal'] - mem['MemFree'] - max(0, cache))


def pss_kib(pid):
    try:
        for line in (Path('/proc') / str(pid) / 'smaps_rollup').read_text().splitlines():
            if line.startswith('Pss:'):
                return int(line.split()[1])
    except (OSError, ValueError):
        return None
    return None


def rss_kib(pid):
    try:
        for line in (Path('/proc') / str(pid) / 'status').read_text().splitlines():
            if line.startswith('VmRSS:'):
                return int(line.split()[1])
    except (OSError, ValueError):
        return None
    return None


def baseline_path():
    parent = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'rusticq'
    if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
        raise RuntimeError('Unsafe memory report directory')
    parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if parent.stat().st_uid != os.getuid():
        raise RuntimeError('Memory report directory ownership mismatch')
    return parent / 'wallpaper-memory-baseline.json'


def report():
    mem = meminfo()
    used = free_used_kib(mem)
    working = max(0, mem['MemTotal'] - mem['MemAvailable'])
    matching = []
    for proc in Path('/proc').iterdir():
        if not proc.name.isdecimal():
            continue
        try:
            name = (proc / 'comm').read_text().strip()
            if name in PROCESSES:
                pss = pss_kib(proc.name)
                rss = rss_kib(proc.name)
                matching.append({'pid': int(proc.name), 'name': name,
                                 'rss_mib': round(rss / 1024, 1) if rss is not None else None,
                                 'pss_mib': round(pss / 1024, 1) if pss is not None else None})
        except (OSError, ValueError):
            continue
    matching.sort(key=lambda x: x['rss_mib'] if x['rss_mib'] is not None else -1, reverse=True)
    result = {'ok': True, 'system_used_mib': round(used / 1024, 1),
              'system_working_set_mib': round(working / 1024, 1),
              'system_available_mib': round(mem['MemAvailable'] / 1024, 1),
              'target_mib': 2048, 'under_target': used < TARGET_KIB,
              'processes': matching, 'method': 'free(1)-style used RAM estimate; per-process PSS/RSS when readable',
              'note': 'Single snapshot with all running applications/services. Not an idle benchmark.'}
    return result


def compare_baseline(data, save=False):
    path = baseline_path()
    if path.is_symlink():
        raise RuntimeError('Unsafe memory baseline file')
    if save:
        fd, temp = tempfile.mkstemp(prefix='.memory-', dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as out:
                os.fchmod(out.fileno(), 0o600)
                json.dump({'version': 1, 'used_mib': data['system_used_mib'],
                           'timestamp': int(time.time())}, out)
                out.flush(); os.fsync(out.fileno())
            os.replace(temp, path)
        finally:
            if os.path.exists(temp): os.unlink(temp)
        data['baseline_saved'] = True
    elif path.is_file():
        baseline = json.loads(path.read_text())
        if baseline.get('version') == 1:
            data['baseline_mib'] = baseline['used_mib']
            data['change_from_baseline_mib'] = round(data['system_used_mib'] - baseline['used_mib'], 1)
    return data


if __name__ == '__main__':
    try:
        parser = argparse.ArgumentParser()
        parser.add_argument('--save-baseline', action='store_true', help='Save current RAM as comparison point')
        args = parser.parse_args()
        print(json.dumps(compare_baseline(report(), args.save_baseline)))
    except (OSError, ValueError, KeyError, RuntimeError) as exc:
        print(json.dumps({'ok': False, 'message': str(exc)}))
        sys.exit(1)
