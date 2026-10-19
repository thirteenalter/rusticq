#!/usr/bin/env python3
"""Regression checks for notification ownership diagnosis, local preview and Wi-Fi lifecycle."""
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[1]
script = root / 'scripts' / 'rustiq-notification-doctor.py'
spec = importlib.util.spec_from_file_location('doctor', script)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

mine = mod.get_status(self_pid=1234, output='PID=1234\nComm=quickshell', returncode=0)
assert mine['state'] == 'owned', mine
mako = mod.get_status(self_pid=1234, output='PID=5678\nComm=mako', returncode=0)
assert mako['state'] == 'conflict' and 'Mako' in mako['suggestion'], mako
quattro = mod.get_status(self_pid=1234, output='PID=5678\nComm=omarchy-shell', returncode=0)
assert quattro['state'] == 'conflict' and 'Omarchy' in quattro['suggestion'], quattro
free = mod.get_status(self_pid=1234, output='Name org.freedesktop.Notifications not provided', returncode=1)
assert free['state'] == 'free', free
missing = mod.get_status(self_pid=1234, output='No connection to user bus', returncode=1)
assert missing['state'] == 'error', missing

center = (root / 'services/NotificationCenter.qml').read_text()
bar = (root / 'modules/bar/BarNotifications.qml').read_text()
wifi = (root / 'services/WifiManager.qml').read_text()
assert 'NotificationServer {' in center
assert 'n.tracked = true;' in center
assert 'NotificationCenter.receivesSystemNotifications' in bar
assert 'NotificationCenter.previewNotification()' in bar
assert 'NotificationCenter.refreshServerStatus()' in bar
assert 'Quickshell.processId' in center
assert 'wifiDevice.scannerEnabled = false' not in wifi
assert 'Component.onDestruction:' not in wifi
print('Notification diagnostics + UI source regression: PASS')
