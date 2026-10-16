#!/usr/bin/env python3
"""Read-only current CPU/memory process snapshot. No psutil dependency."""
import json
import os
from pathlib import Path
import time

PROC = Path('/proc')

def cpu_total():
    fields = (PROC / 'stat').read_text().splitlines()[0].split()[1:9]
    return sum(int(x) for x in fields)


def ticks(entry):
    try:
        raw = (entry / 'stat').read_text()
        # comm (field 2) may contain spaces and parentheses.
        after = raw.rsplit(')', 1)[1].strip().split()
        return int(after[11]) + int(after[12])
    except (FileNotFoundError, PermissionError, ProcessLookupError, ValueError, IndexError, OSError):
        return None


def snapshot():
    start_total = cpu_total()
    start_ticks = {}
    for entry in PROC.iterdir():
        if entry.name.isdigit():
            amount = ticks(entry)
            if amount is not None:
                start_ticks[int(entry.name)] = amount
    time.sleep(0.2)
    elapsed = max(1, cpu_total() - start_total)
    cores = os.cpu_count() or 1
    result = []
    for entry in PROC.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            pid = int(entry.name)
            status = (entry / 'status').read_text(errors='replace')
            values = {}
            for line in status.splitlines():
                if ':' in line:
                    key, value = line.split(':', 1)
                    if key in ('Name', 'VmRSS', 'State'):
                        values[key] = value.strip()
            memory = int(values.get('VmRSS', '0 kB').split()[0]) / 1024
            now = ticks(entry)
            before = start_ticks.get(pid)
            cpu = 0 if now is None or before is None else max(0, now - before) * cores * 100 / elapsed
            result.append({'pid': pid, 'name': values.get('Name', '?')[:35],
                           'memMiB': round(memory, 1), 'cpu': round(cpu, 1),
                           'state': values.get('State', '?')[:1]})
        except (PermissionError, FileNotFoundError, ProcessLookupError, ValueError, OSError):
            continue
    result.sort(key=lambda item: (-item['cpu'], -item['memMiB']))
    try:
        load = list(os.getloadavg())
    except OSError:
        load = [0, 0, 0]
    try:
        uptime = int(float((PROC / 'uptime').read_text().split()[0]))
    except (OSError, ValueError, IndexError):
        uptime = 0
    return {'processes': result[:30], 'total': len(result), 'load': [round(x, 2) for x in load],
            'uptime': uptime, 'cores': cores}

if __name__ == '__main__':
    try:
        print(json.dumps(snapshot()))
    except (OSError, PermissionError) as exc:
        print(json.dumps({'error': str(exc), 'processes': [], 'total': 0, 'load': [0, 0, 0], 'cores': 0, 'uptime': 0}))
