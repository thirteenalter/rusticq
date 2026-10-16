#!/usr/bin/env python3
"""Offline regression for RusticQ Settings floating geometry and dock padding."""
import importlib.util
from pathlib import Path
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / 'scripts/rustiq-settings-float.py'
spec = importlib.util.spec_from_file_location('float_helper', MODULE_PATH)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def test_window_match_exact_title_address():
    clients = [
        {'title': 'Firefox', 'address': '0x123abc'},
        {'title': 'RusticQ · Settings', 'address': 'notvalid'},
        {'title': 'RusticQ · Settings', 'address': '0x123abd', 'floating': False},
    ]
    assert helper.find_settings_window(clients) == clients[-1]
    assert helper.find_settings_window([clients[0], clients[1]]) is None
    assert helper.find_settings_window({'clients': clients}) is None


def test_floats_resizes_and_centers_only_settings():
    client = {'title': 'RusticQ · Settings', 'address': '0x123abd',
              'floating': False, 'size': [1600, 900]}
    with patch.object(helper, 'dispatch', return_value=Mock(returncode=0, stdout='ok', stderr='')) as call:
        assert helper.ensure_float(client)
        expressions = [x.args[0] for x in call.call_args_list]
        assert len(expressions) == 3
        assert all('address:0x123abd' in s for s in expressions)
        assert 'float(' in expressions[0] and 'action = "set"' in expressions[0]
        assert 'resize(' in expressions[1] and 'x = 940' in expressions[1]
        assert 'y = 600' in expressions[1] and 'relative = false' in expressions[1]
        assert 'center(' in expressions[2]


def test_matching_floating_window_is_not_resized():
    client = {'title': 'RusticQ · Settings', 'address': '0x123abd',
              'floating': True, 'size': [940, 600]}
    with patch.object(helper, 'dispatch') as call:
        assert helper.ensure_float(client)
        call.assert_not_called()


def test_floating_wrong_size_resizes_without_toggling_float():
    client = {'title': 'RusticQ · Settings', 'address': '0x123abd',
              'floating': True, 'size': [940, 660]}
    with patch.object(helper, 'dispatch', return_value=Mock(returncode=0, stdout='ok', stderr='')) as call:
        assert helper.ensure_float(client)
        expressions = [x.args[0] for x in call.call_args_list]
        assert len(expressions) == 2
        assert 'resize(' in expressions[0]
        assert 'center(' in expressions[1]
        assert not any('float(' in s for s in expressions)


def test_invalid_window_address_never_dispatches():
    with patch.object(helper, 'dispatch') as call:
        assert not helper.ensure_float({'title': 'RusticQ · Settings', 'address': 'oops'})
        call.assert_not_called()


def test_settings_outer_geometry():
    source = (ROOT / 'modules/settings/SettingsWindow.qml').read_text()
    assert 'implicitWidth: 940' in source and 'implicitHeight: 600' in source
    assert 'minimumSize: Qt.size(760, 500)' in source
    assert 'maximized: false' in source and 'fullscreen: false' in source
    assert 'radius: 18\n        color: Theme.background' not in source
    assert 'border.width: 1\n        border.color: Theme.borderaccent\n        clip: true' not in source
    assert 'startSystemMove()' in source
    assert 'onPressed: root.startSystemMove()' in source
    assert 'onClicked: Store.settingsVisible = false' not in source
    assert 'scripts/rustiq-settings-float.py' in source
    assert 'Layout.fillHeight: true' in source


def test_dock_width_uses_actual_items():
    source = (ROOT / 'modules/main/RusticDock.qml').read_text()
    assert 'readonly property int dockPadding: 10' in source
    assert 'Math.ceil(contentRow.implicitWidth) + dockPadding * 2' in source
    assert 'anchors.margins: dock.dockPadding' in source
    assert 'parent.width - implicitWidth' in source
    assert 'shortcutCount * 58' not in source
    assert 'runningCount * 58' not in source


if __name__ == '__main__':
    for name, f in sorted(globals().items()):
        if name.startswith('test_') and callable(f):
            f()
            print('PASS', name)
