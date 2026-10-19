#!/usr/bin/env python3
"""Regression smoke tests: standalone, no Quickshell/Hyprland needed."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/rustiq-system-metrics.py'
with tempfile.TemporaryDirectory() as scratch:
    scratch = Path(scratch)
    sysroot = scratch/'sys'; procroot = scratch/'proc'
    (sysroot/'class/net/wlp2s0').mkdir(parents=True)
    (sysroot/'class/net/wlp2s0/operstate').write_text('up')
    (sysroot/'block/nvme0n1').mkdir(parents=True)
    (sysroot/'block/nvme0n1/stat').write_text('1 0 900 0 1 0 1200 0 0 0 0')
    (sysroot/'class/drm/card0/device').mkdir(parents=True)
    (sysroot/'class/drm/card0/device/vendor').write_text('0x1002')
    (sysroot/'class/drm/card0/device/gpu_busy_percent').write_text('37')
    (procroot/'net').mkdir(parents=True)
    (procroot/'net/dev').write_text('Inter-| Receive | Transmit\n face |bytes packets errs drop fifo frame compressed multicast |bytes packets errs drop fifo colls carrier compressed\n  wlp2s0: 1000 0 0 0 0 0 0 0 3500 0 0 0 0 0 0 0\n')
    env = {**os.environ, 'RUSTIQ_METRICS_SYS':str(sysroot), 'RUSTIQ_METRICS_PROC':str(procroot)}
    result = subprocess.run(['python3',str(SCRIPT)],env=env,capture_output=True,text=True,check=True)
    data=json.loads(result.stdout)
    assert data['gpu']['usage'] == 37
    assert data['network']['rxBytes'] == 1000
    assert data['network']['txBytes'] == 3500
    assert data['diskIo']['readBytes'] == 900*512
    assert data['diskIo']['writeBytes'] == 1200*512

shell=(ROOT/'shell.qml').read_text()
context=(ROOT/'modules/main/ContextMenu.qml').read_text()
advanced=(ROOT/'modules/bar/BarAdvanced.qml').read_text()
mon=(ROOT/'modules/main/SystemMonitorWindow.qml').read_text()
store=(ROOT/'config/Store.qml').read_text()
assert 'SystemMonitorWindow' in shell
assert 'shell-monitor' in context and 'Store.systemMonitorVisible = true' in context
assert 'systemMonitorVisible: false' in store
assert 'Pipewire.preferredDefaultAudioSource' in advanced
assert 'root.inputDevices' in advanced
assert 'SystemMetrics' in mon and 'WifiService.ssid' in mon
assert 'kind === "menu" ? 14' in (ROOT/'modules/main/IndicatorPopup.qml').read_text()
assert 'Layout.leftMargin: 42' in (ROOT/'modules/bar/BarMonitors.qml').read_text()
print('System monitor / audio / popup regression: OK')
