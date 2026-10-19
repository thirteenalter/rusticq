#!/usr/bin/env python3
"""Offline tests for RusticQ feature-matrix expansion; no GUI, file uploads or package changes."""
import importlib.util
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(filename, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


SEARCH = load('rusticq-desktop-search.py', 'beta3_search')
NOTES = load('rusticq-notes.py', 'beta3_notes')
LAUNCHER = load('rusticq-launcher-tools.py', 'beta3_launcher')


class Beta3FeatureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'user'
        self.home.mkdir()
        self.notes = self.home / 'state' / 'notes.json'
        p = patch.object(NOTES, 'STATE', self.notes)
        p.start()
        self.addCleanup(p.stop)

    def test_notes_add_read_move_cycle_and_delete(self):
        created = NOTES.op('add', 'Write docs')
        self.assertEqual(created['stage'], 'todo')
        self.assertEqual(NOTES.op('list')['items'][0]['title'], 'Write docs')
        self.assertEqual(NOTES.op('move', created['id'], 'doing')['stage'], 'doing')
        self.assertEqual(NOTES.op('toggle', created['id'])['stage'], 'done')
        self.assertEqual(NOTES.op('toggle', created['id'])['stage'], 'todo')
        self.assertEqual(NOTES.op('delete', created['id'])['title'], 'Write docs')
        self.assertEqual(NOTES.op('list')['items'], [])

    def test_notes_private_atomic_and_validation(self):
        NOTES.op('add', 'Private note')
        self.assertEqual(self.notes.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.notes.parent.stat().st_mode & 0o777, 0o700)
        self.assertFalse(list(self.notes.parent.glob('*.tmp')))
        for title in ('', '\nhello', 'a' * 270):
            with self.assertRaises(ValueError):
                NOTES.op('add', title)
        with self.assertRaises(ValueError):
            NOTES.op('move', 'x' * 32, 'todo')

    def test_note_missing_file_symlink_refused(self):
        self.notes.parent.mkdir(parents=True)
        target = self.home / 'secret.json'
        target.write_text('{"schema":1,"notes":[]}')
        self.notes.symlink_to(target)
        with self.assertRaisesRegex(ValueError, 'Unsafe'):
            NOTES.op('list')

    def test_launcher_notes_provider_and_action_no_arbitrary_eval(self):
        result = LAUNCHER.search('notes', '+Build desktop')
        self.assertEqual(result[0]['action'], 'note-add')
        msg = LAUNCHER.execute('note-add', 'Build desktop')
        self.assertIn('todo', msg)
        note = LAUNCHER.search('notes', 'Build')[0]
        self.assertEqual(note['action'], 'note-toggle')
        self.assertIn('doing', LAUNCHER.execute('note-toggle', note['payload']))
        self.assertEqual(LAUNCHER.search('settings', 'notes')[0]['payload'], 'notes')
        with self.assertRaises(ValueError):
            LAUNCHER.execute('note-toggle', 'id;rm -rf ~')

    def test_files_search_is_explicit_and_bounded(self):
        docs = self.home / 'Documents'
        docs.mkdir()
        (docs / 'Report for October.txt').write_text('done')
        (docs / '.private-report.txt').write_text('secret')
        self.assertEqual(SEARCH.file_results('', home=self.home), [])
        result = SEARCH.file_results('report', home=self.home)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['action'], 'file')

    def test_files_search_cannot_escape_symlink(self):
        docs = self.home / 'Documents'
        docs.mkdir()
        secret = Path(self.temp.name) / 'secret'
        secret.mkdir()
        (secret / 'transfer-record.txt').write_text('outside')
        (docs / 'escape').symlink_to(secret)
        (docs / 'transfer.txt').symlink_to(secret / 'transfer-record.txt')
        self.assertEqual(SEARCH.file_results('transfer', home=self.home), [])

    def test_folder_search_and_explicit_open_allowlist(self):
        docs = self.home / 'Documents'
        docs.mkdir()
        (docs / 'projects').mkdir()
        result = SEARCH.file_results('proj', folders=True, home=self.home)
        self.assertEqual(result[0]['action'], 'folder')
        with patch.object(SEARCH.shutil, 'which', return_value='/bin/xdg-open'), \
             patch.object(SEARCH.subprocess, 'Popen') as process:
            SEARCH.open_item('folder', result[0]['payload'], home=self.home)
        process.assert_called_once()
        with self.assertRaisesRegex(ValueError, 'outside home'):
            SEARCH.open_item('file', '/etc/passwd', home=self.home)

    def test_window_provider_exact_address(self):
        with patch.object(SEARCH, 'hypr_snapshot', return_value=[
            {'address':'0xabcdef12','title':'Code editor','class':'code'},
            {'address':'not-valid','title':'System private','class':'secret'},
        ]):
            result = SEARCH.search_hypr('windows', 'editor')
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['payload'], '0xabcdef12')

    def test_workspace_provider_checks_availability(self):
        with patch.object(SEARCH, 'hypr_snapshot', return_value=[{'id': 3, 'windows': 2}]):
            result = SEARCH.search_hypr('workspaces', '3')
            self.assertEqual(result[0]['payload'], '3')
            with patch.object(SEARCH.subprocess, 'run', return_value=subprocess.CompletedProcess([],0,'ok','')) as dispatch:
                SEARCH.open_item('workspace','3')
            self.assertIn('workspace', dispatch.call_args[0][0])
            with self.assertRaisesRegex(ValueError, 'no longer exists'):
                SEARCH.open_item('workspace','7')

    def test_invalid_window_and_workspace_payloads(self):
        for action, payload in [('window', '0xabcdef;exit'), ('workspace', '1;exit')]:
            with self.assertRaises(ValueError):
                SEARCH.open_item(action, payload)

    def test_qml_reuses_existing_services(self):
        qml = (ROOT / 'modules/main/MiniAudio.qml').read_text()
        self.assertIn('root.playbackStreams', qml)
        self.assertIn('PwObjectTracker { objects: root.advancedOpen ?', qml)
        self.assertIn('appStream.audioNode.audio.volume = value', qml)
        notice = (ROOT / 'services/NotificationCenter.qml').read_text()
        self.assertIn('readonly property var displayHistory:', notice)
        self.assertIn('function groupedHistory()', notice)
        self.assertIn('function toggleGroup(app)', notice)
        self.assertIn('NotificationCenter.toggleGroup(', (ROOT / 'modules/bar/BarNotifications.qml').read_text())

    def test_ui_notes_and_profiles_navigation(self):
        shell = (ROOT / 'modules/settings/SettingsWindow.qml').read_text()
        self.assertIn('id: notesPage', shell)
        self.assertIn('Store.settingsTab === "notes" ? notesPage', shell)
        board = (ROOT / 'modules/settings/pages/SettingsNotesPage.qml').read_text()
        self.assertIn('root.modify("toggle"', board)
        store = (ROOT / 'config/SettingsStore.qml').read_text()
        self.assertIn('function applyDesktopProfile(profile)', store)
        self.assertIn('function restoreDesktopProfile()', store)
        self.assertIn('desktopProfilePrevious: desktopProfilePrevious', store)
        self.assertIn('SettingsStore.applyDesktopProfile(', (ROOT / 'modules/settings/pages/SettingsModulesPage.qml').read_text())

    def test_default_launcher_not_replaced(self):
        qml=(ROOT/'modules/main/MiniLauncher.qml').read_text()
        self.assertIn('DesktopEntries.applications.values', qml)
        self.assertIn('^:(emoji|settings|wallpaper|color|ocr|files|folders|windows|workspaces|notes)', qml)
        self.assertIn('Keys.onDownPressed', qml)


if __name__ == '__main__':
    unittest.main()
