#!/usr/bin/env python3
"""Read-only diagnostics for RusticQ Alpha 4 RC1. No shell evaluation or privileges."""
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys


def command(args, timeout=5):
    if not shutil.which(args[0]):
        return ''
    try:
        res = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
        return res.stdout.strip() if res.returncode == 0 else ''
    except (OSError, subprocess.TimeoutExpired):
        return ''


def read(path):
    try:
        return Path(path).read_text(errors='replace').strip()
    except (OSError, PermissionError):
        return ''


def labels_from_os_release():
    values = {}
    for line in read('/etc/os-release').splitlines():
        if '=' in line and not line.startswith('#'):
            k, v = line.split('=', 1)
            values[k] = v.strip().strip('"')
    return values


def os_info():
    osr = labels_from_os_release()
    uptime_sec = 0
    try:
        uptime_sec = int(float(read('/proc/uptime').split()[0]))
    except (ValueError, IndexError):
        pass
    return dict(
        headline=osr.get('PRETTY_NAME', 'Linux'),
        subtitle='Operating system and desktop session',
        facts=[
            ['Distribution', osr.get('PRETTY_NAME', 'Linux')],
            ['Kernel', platform.release()],
            ['Architecture', platform.machine()],
            ['Hostname', platform.node()],
            ['Desktop', os.environ.get('XDG_CURRENT_DESKTOP', 'Unknown')],
            ['Session', os.environ.get('XDG_SESSION_TYPE', 'Unknown')],
            ['Locale', os.environ.get('LANG', 'Unknown')],
            ['Uptime', f'{uptime_sec // 86400}d {(uptime_sec % 86400) // 3600}h {(uptime_sec % 3600) // 60}m'],
            ['Boot ID', read('/proc/sys/kernel/random/boot_id') or 'Unavailable'],
            ['Package manager', 'pacman' if shutil.which('pacman') else 'Not detected'],
        ],
        notes=['System details are read-only. Hostname and boot ID are displayed locally only.']
    )


def hardware_info():
    cpu = 'Unknown CPU'
    for line in read('/proc/cpuinfo').splitlines():
        if line.lower().startswith('model name'):
            cpu = line.split(':', 1)[-1].strip()
            break
    mem_kib = 0
    try:
        mem_kib = int(re.search(r'^MemTotal:\s+(\d+)', read('/proc/meminfo'), re.M).group(1))
    except (AttributeError, ValueError):
        pass
    cpu_threads = os.cpu_count() or 0
    vendor = read('/sys/class/dmi/id/sys_vendor')
    product = read('/sys/class/dmi/id/product_name')
    board = read('/sys/class/dmi/id/board_name')
    bios = read('/sys/class/dmi/id/bios_version')
    gpu_lines = [line.strip() for line in command(['lspci', '-mm']).splitlines()
                 if 'VGA compatible controller' in line or '3D controller' in line or 'Display controller' in line]
    gpu = ' / '.join(gpu_lines[:2]) or 'lspci not installed or GPU unavailable'
    return dict(
        headline=product or 'Hardware', subtitle='CPU, graphics, memory and motherboard',
        facts=[['CPU', cpu], ['CPU logical threads', str(cpu_threads)],
               ['RAM installed (reported)', f'{mem_kib / 1024 / 1024:.2f} GiB' if mem_kib else 'Unknown'],
               ['GPU', gpu], ['Manufacturer', vendor or 'Unknown'],
               ['System model', product or 'Unknown'], ['Motherboard', board or 'Unknown'],
               ['BIOS', bios or 'Unknown'],
               ['Thermal zones', str(len(list(Path('/sys/class/thermal').glob('thermal_zone*'))))]],
        notes=['GPU information requires pciutils (lspci).',
               'Device serial numbers are intentionally not collected.']
    )


def packages_info():
    if not shutil.which('pacman'):
        return dict(headline='Applications', subtitle='Arch package inventory', facts=[], rows=[],
                    notes=['pacman is unavailable on this computer.'])
    lines = command(['pacman', '-Q'], 15).splitlines()
    foreign = command(['pacman', '-Qm'], 15).splitlines()
    explicit = command(['pacman', '-Qe'], 15).splitlines()
    packages = []
    for line in lines:
        fields = line.rsplit(' ', 1)
        if len(fields) == 2:
            packages.append(dict(name=fields[0], version=fields[1]))
    packages.sort(key=lambda p: p['name'].lower())
    return dict(headline=f'{len(packages)} installed packages', subtitle='Pacman packages, including repository and foreign packages',
                facts=[['Total installed', str(len(packages))], ['Explicitly installed', str(len(explicit))],
                       ['Foreign / AUR-built', str(len(foreign))],
                       ['Repository packages', str(max(0, len(packages) - len(foreign)))]],
                rows=packages,
                notes=['Package inventory does not mean an application has a visible desktop entry.',
                       'AUR packages are listed, but are not upgraded by the pacman repository updater.'])


def storage_info():
    mounts = []
    stdout = command(['lsblk', '-J', '-o', 'NAME,SIZE,FSTYPE,MOUNTPOINT,MODEL,TYPE'], 6)
    if stdout:
        try:
            devices = json.loads(stdout).get('blockdevices', [])
            def traverse(items):
                for dev in items:
                    if dev.get('type') in ('disk', 'part', 'lvm', 'crypt'):
                        mounts.append(dict(name=dev.get('name', ''), size=dev.get('size') or '',
                                           filesystem=dev.get('fstype') or '', mount=dev.get('mountpoint') or '',
                                           device=dev.get('model') or '', type=dev.get('type', '')))
                    traverse(dev.get('children') or [])
            traverse(devices)
        except (ValueError, TypeError):
            pass
    disk = shutil.disk_usage('/')
    cache = command(['du', '-sh', str(Path.home() / '.cache')], 5)
    journal = command(['journalctl', '--disk-usage'], 5)
    return dict(headline='Storage & maintenance', subtitle='Filesystem capacity and physical block devices',
                facts=[['Root capacity', f'{disk.total / 1024 ** 3:.1f} GiB'],
                       ['Root used', f'{disk.used / 1024 ** 3:.1f} GiB'],
                       ['Root available', f'{disk.free / 1024 ** 3:.1f} GiB'],
                       ['User cache', cache.split('\t')[0] if cache else 'Unavailable'],
                       ['System journal', journal or 'Unavailable']],
                rows=mounts, notes=['All information is read-only. Disk cleanup is not run automatically.'])


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ('os', 'hardware', 'apps', 'storage'):
        print(json.dumps(dict(ok=False, error='Unknown diagnostic category')))
        return 2
    functions = dict(os=os_info, hardware=hardware_info, apps=packages_info, storage=storage_info)
    try:
        print(json.dumps(dict(ok=True, **functions[sys.argv[1]]()), ensure_ascii=False))
        return 0
    except Exception as exc:
        print(json.dumps(dict(ok=False, error=f'Diagnostic unavailable: {type(exc).__name__}: {exc}')))
        return 1


if __name__ == '__main__':
    sys.exit(main())
