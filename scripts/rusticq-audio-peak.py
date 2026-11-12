#!/usr/bin/env python3
"""In-memory peak fallback for PipeWire streams with unnamed audio channels.

Quickshell 0.3.1's native monitor cannot map Unknown channels to FL/FR.
pw-cat streams PCM through a pipe; samples are never written to disk.
"""
from array import array
import json
import math
import os
import selectors
import shutil
import signal
import subprocess
import sys
import time


def sample_peak(data):
    samples = array('f')
    samples.frombytes(data)
    peak = max((abs(value) for value in samples if math.isfinite(value)), default=0.0)
    return min(1.0, peak ** (1.0 / 3.0))


def stop(signum, frame):
    raise SystemExit(0)


def monitor(target):
    if not target or len(target) > 256 or any(char in target for char in '\0\r\n') or not shutil.which('pw-cat'):
        raise ValueError('Peak capture unavailable')
    properties = json.dumps({'application.name': 'RusticQ Audio Meter',
                             'media.name': 'Peak monitor', 'media.category': 'Monitor',
                             'stream.monitor': True, 'stream.capture.sink': True,
                             'node.passive': True, 'node.dont-reconnect': True})
    command = ['pw-cat', '--record', '--raw', '--format', 'f32', '--rate', '24000',
               '--channels', '2', '--latency', '100ms', '--target', target,
               '--properties', properties, '-']
    process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            previous = 0.0
            last_data = time.monotonic()
            peak = 0.0
            pending = b''
            while process.poll() is None:
                ready = selector.select(timeout=0.1)
                now = time.monotonic()
                if ready:
                    chunk = os.read(process.stdout.fileno(), 8192)
                    if not chunk:
                        break
                    pending += chunk
                    size = len(pending) - len(pending) % 4
                    if size:
                        peak = max(peak, sample_peak(pending[:size]))
                        pending = pending[size:]
                        last_data = now
                if now - previous >= 0.09:
                    print(round(peak if now - last_data < 0.25 else 0.0, 4), flush=True)
                    previous = now
                    peak = 0.0
            if process.poll() is not None and process.returncode:
                raise ValueError('Peak capture unavailable')
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        process.stdout.close()


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        if len(sys.argv) != 2:
            raise ValueError('Missing target')
        monitor(sys.argv[1])
    except (OSError, ValueError):
        print('unavailable', flush=True)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
