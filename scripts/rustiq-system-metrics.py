#!/usr/bin/env python3
"""Read-only Linux metric snapshot for RusticQ monitor. No extra pip modules."""
import json
import os
from pathlib import Path
import subprocess

SYS = Path(os.environ.get('RUSTIQ_METRICS_SYS', '/sys'))
PROC = Path(os.environ.get('RUSTIQ_METRICS_PROC', '/proc'))


def text_file(path):
    try:
        return path.read_text().strip()
    except (OSError, UnicodeError):
        return ''


def float_file(path):
    try:
        return float(text_file(path))
    except ValueError:
        return None


def net_data():
    rx = tx = 0
    interfaces = []
    lines = text_file(PROC / 'net/dev').splitlines()[2:]
    for row in lines:
        if ':' not in row:
            continue
        interface, columns = row.split(':', 1)
        interface = interface.strip()
        values = columns.split()
        if len(values) < 9 or interface == 'lo':
            continue
        # Count actual hardware / VPN connections, not container veth links.
        if interface.startswith(('veth', 'docker', 'br-', 'virbr')):
            continue
        status = text_file(SYS / 'class/net' / interface / 'operstate')
        if status not in ('up', 'unknown'):
            continue
        try:
            in_bytes, out_bytes = int(values[0]), int(values[8])
        except ValueError:
            continue
        rx += in_bytes
        tx += out_bytes
        interfaces.append(interface)
    return {'rxBytes': rx, 'txBytes': tx, 'interfaces': interfaces}


def disk_data():
    read_sectors = write_sectors = 0
    disks = []
    for block in (SYS / 'block').glob('*'):
        name = block.name
        if name.startswith(('loop', 'ram', 'zram', 'sr', 'dm-', 'md')):
            continue
        parts = text_file(block / 'stat').split()
        if len(parts) < 7:
            continue
        try:
            # Most Linux block devices report sectors in fixed 512-byte units.
            read_sectors += int(parts[2])
            write_sectors += int(parts[6])
            disks.append(name)
        except ValueError:
            continue
    return {'readBytes': read_sectors * 512, 'writeBytes': write_sectors * 512, 'devices': disks}


def gpu_data():
    for card in sorted((SYS / 'class/drm').glob('card[0-9]*')):
        device = card / 'device'
        if not device.exists():
            continue
        vendor = text_file(device / 'vendor')
        if not vendor:
            continue
        vendors = {'0x1002': 'AMD', '0x8086': 'Intel', '0x10de': 'NVIDIA'}
        name = vendors.get(vendor.lower(), 'GPU')
        used = float_file(device / 'gpu_busy_percent')
        if used is None:
            used = float_file(device / 'gt_busy_percent')
        mem_used = float_file(device / 'mem_info_vram_used')
        mem_total = float_file(device / 'mem_info_vram_total')
        if used is not None:
            return {'name': name + ' ' + card.name, 'usage': max(0, min(100, used)),
                    'vramUsed': mem_used, 'vramTotal': mem_total}
    # NVIDIA hardware may expose utilization only via nvidia-smi.
    try:
        data = subprocess.run(['nvidia-smi', '--query-gpu=name,utilization.gpu,memory.used,memory.total',
                               '--format=csv,noheader,nounits'], capture_output=True, text=True,
                              timeout=2, check=False)
        if data.returncode == 0 and data.stdout.strip():
            values = [c.strip() for c in data.stdout.splitlines()[0].split(',')]
            if len(values) >= 4:
                return {'name': values[0], 'usage': float(values[1]),
                        'vramUsed': float(values[2]) * 1024 * 1024,
                        'vramTotal': float(values[3]) * 1024 * 1024}
    except (OSError, ValueError, subprocess.TimeoutExpired):
        pass
    return {'name': 'GPU', 'usage': None, 'vramUsed': None, 'vramTotal': None}


def snapshot():
    return {'gpu': gpu_data(), 'network': net_data(), 'diskIo': disk_data()}


if __name__ == '__main__':
    print(json.dumps(snapshot(), ensure_ascii=False))
