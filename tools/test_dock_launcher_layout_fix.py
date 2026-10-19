#!/usr/bin/env python3
"""Offline tests for Alpha 4 RC1 dock/launcher fix (no desktop session needed)."""
import importlib.util
import json
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("running_apps", ROOT / "scripts/rustiq-running-apps.py")
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


def test_clients_and_dedup():
    clients = [
        {"class": "kitty", "title": "Terminal", "address": "0x123abc890", "mapped": True, "focusHistoryID": 5},
        {"class": "firefox", "title": "Browser", "address": "0x123abc891", "mapped": True, "focusHistoryID": 0},
        {"class": "Firefox", "title": "Other window", "address": "0x123abc892", "mapped": True, "focusHistoryID": 4},
        {"class": "quickshell", "title": "RusticQ", "address": "0x123abc893", "mapped": True},
        {"class": "hiddenapp", "address": "0x123abc894", "mapped": False},
        {"class": "dialog", "address": "foobar", "mapped": True},
        {"class": "xwayland-app", "title": "X11 Window", "address": "123abc895", "focusHistoryID": 3},
    ]
    result = MOD.parse_clients(clients)
    assert [x["appId"] for x in result] == ["firefox", "xwayland-app", "kitty"], result
    assert result[0]["active"] is True
    assert result[1]["address"] == "0x123abc895"
    assert len(MOD.parse_clients([])) == 0
    try:
        MOD.parse_clients({"clients": []})
    except ValueError:
        pass
    else:
        raise AssertionError("Malformed data accepted")


def test_commands_and_focus():
    clients = [{"class": "org.example.App", "title": "Window", "address": "0xabc123eeee", "mapped": True}]
    with mock.patch.object(MOD.subprocess, "run") as runner:
        runner.return_value = mock.Mock(returncode=0, stdout=json.dumps(clients), stderr="")
        assert MOD.list_apps()["apps"][0]["appId"] == "org.example.App"
        assert runner.call_args.args[0] == ["hyprctl", "-j", "clients"]
        MOD.focus_window("0xabc123eeee")
        command = runner.call_args.args[0]
        assert command[:2] == ["hyprctl", "dispatch"]
        assert 'hl.dsp.focus({ window = "address:0xabc123eeee" })' == command[2]
        assert MOD.focus_window("abcdef1234")["ok"]
        assert runner.call_count == 3
    for bad in [";rm -rf /", "nothex", "", "0x2", "123123\n"]:
        try:
            MOD.focus_window(bad)
        except ValueError:
            pass
        else:
            raise AssertionError("Unsafe address accepted: " + bad)


def test_qml_contract():
    dock = (ROOT / 'modules/main/RusticDock.qml').read_text()
    assert 'model: SettingsStore.dockRunningApps ? dock.runningApps : []' in dock
    assert 'Math.ceil(contentRow.implicitWidth) + dockPadding * 2' in dock
    assert 'dock.runningApps = []' in dock
    assert 'Hyprland.toplevels.values.length' not in dock
    launcher = (ROOT / 'modules/main/MiniLauncher.qml').read_text()
    overlay = (ROOT / 'modules/main/LauncherOverlay.qml').read_text()
    settings = (ROOT / 'config/SettingsStore.qml').read_text()
    settings_page = (ROOT / 'modules/settings/pages/SettingsLauncherPage.qml').read_text()
    assert 'readonly property bool cleanHover' in launcher
    assert 'visible: root.showResults' in launcher
    assert 'model: root.displayedResults' in launcher
    assert 'launcherLayoutMode === "clean-hover" && !launcherSurface.showResults' in overlay
    assert 'launcherLayoutMode: launcherLayoutMode' in settings
    assert 'onClicked: { SettingsStore.launcherLayoutMode' in settings_page


if __name__ == '__main__':
    for test in (test_clients_and_dedup, test_commands_and_focus, test_qml_contract):
        test()
        print('PASS', test.__name__)
