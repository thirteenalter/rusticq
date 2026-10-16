#!/usr/bin/env python3
"""Alpha 4 RC1 regression tests. No real system update is executed."""
from pathlib import Path
import importlib.util
import json
from unittest.mock import patch
import subprocess
import os
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

inspector = load('rustiq_inspect', ROOT / 'scripts' / 'rustiq-inspect.py')
updater = load('rustiq_updater', ROOT / 'scripts' / 'rustiq-updater.py')

for method in [inspector.os_info, inspector.hardware_info, inspector.storage_info, inspector.packages_info]:
    report = method()
    require(isinstance(report.get('facts'), list), 'Missing facts from ' + method.__name__)
    require(isinstance(report.get('headline'), str), 'Missing headline from ' + method.__name__)

report = inspector.os_info()
require(any(fact[0] == 'Kernel' for fact in report['facts']), 'Kernel diagnostic absent')
with patch.object(inspector, 'command', return_value='alpha 1.0\nbeta 2.3\n'):
    with patch.object(inspector.shutil, 'which', return_value='/usr/bin/pacman'):
        result = inspector.packages_info()
        require(len(result['rows']) == 2, 'Package parser failed')

# Safe update simulation: mock checkupdates; never spawn real pacman/pkexec.
with patch.object(updater.shutil, 'which', side_effect=lambda x: '/usr/bin/' + x):
    with patch.object(updater.subprocess, 'run', return_value=subprocess.CompletedProcess(
        ['checkupdates', '--nocolor'], 0, 'linux 6.1 -> 6.2\nmesa 25.0 -> 25.1\n', '')):
        result = updater.check_updates()
        require(result['ok'] and result['count'] == 2, 'Updater package parsing failed')
        require(result['packages'][0]['name'] == 'linux', 'Updater package name parsing failed')
    with patch.object(updater.subprocess, 'run', return_value=subprocess.CompletedProcess(
        ['checkupdates', '--nocolor'], 2, '', '')):
        result = updater.check_updates()
        require(result['ok'] and result['count'] == 0, 'No-updates status not recognized')

# Persistent status file and log behavior without a privileged upgrade.
with tempfile.TemporaryDirectory() as temp:
    updater.ROOT = Path(temp)
    updater.STATE = updater.ROOT / 'status.json'
    updater.LOG = updater.ROOT / 'pacman.log'
    updater.LOCK = updater.ROOT / 'upgrade.lock'
    updater.write_state(state='completed', phase='done', progress=100, message='Finished')
    updater.append_log('[DONE] complete')
    result = updater.status()
    require(result['state'] == 'completed' and result['progress'] == 100, 'Persistent update status failed')
    require(result['lines'][-1] == '[DONE] complete', 'Terminal log could not be read')

settings = (ROOT / 'modules/settings/SettingsWindow.qml').read_text()
for tab in ['os', 'hardware', 'apps', 'storage', 'updates']:
    require('key:"' + tab + '"' in settings, 'Sidebar tab missing: ' + tab)
    require('Store.settingsTab === "' + tab + '"' in settings, 'Loader route missing: ' + tab)
require('Flickable {' in settings and 'id: navigationScroll' in settings, 'Sidebar must scroll')
for name in ['SettingsInfoPage', 'SettingsOSPage', 'SettingsHardwarePage', 'SettingsAppsPage',
             'SettingsStoragePage', 'SettingsUpdaterPage']:
    require((ROOT / 'modules/settings/pages' / (name + '.qml')).exists(), name + ' missing')
updater_qml = (ROOT / 'modules/settings/pages/SettingsUpdaterPage.qml').read_text()
require('root.confirmation = true' in updater_qml, 'Explicit confirmation missing')
require('function startUpgrade()' in updater_qml, 'Upgrade action missing')
require('function checkUpdates()' in updater_qml, 'Read-only check missing')
require('onTriggered: root.refreshStatus()' in updater_qml, 'Live status polling missing')
require('root.itemProgressAvailable' in updater_qml and 'root.status.progress / 100' in updater_qml, 'Observed pacman item progress missing')
require('root.checking' in updater_qml, 'Check-updates activity missing')
print('Alpha 4 RC1 diagnostics, updater simulation, and QML structure: PASS')
