#!/usr/bin/env python3
"""Real subprocess regressions for automatic Omarchy + dotfiles shortcut backup.

Runs against temporary HOME/OMARCHY trees; never edits the host system.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'scripts/rustiq-desktop-integration.py'


class ShortcutArchives(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.top = Path(tmp.name)
        self.home = self.top / 'home'; self.home.mkdir()
        self.config = self.home / '.config'
        self.hypr = self.config / 'hypr'; self.hypr.mkdir(parents=True)
        self.bindings = self.hypr / 'bindings.lua'
        self.original = 'o.bind("SUPER + ESCAPE", "Omarchy recovery", "omarchy-recovery")\n'
        self.bindings.write_text(self.original)
        (self.hypr / 'hyprland.lua').write_text('require("default.hypr.omarchy")\n')
        (self.hypr / 'monitors.lua').write_text('-- custom monitor before override\n')
        (self.config / 'omarchy').mkdir(); (self.config / 'omarchy' / 'shell.json').write_text('{"theme":"old"}')
        (self.config / 'waybar').mkdir(); (self.config / 'waybar' / 'config.jsonc').write_text('original bar')
        (self.config / 'quickshell').mkdir(); (self.config / 'quickshell' / 'widget.json').write_text('private widget')
        (self.home / '.zshrc').write_text('# customized shell dotfile\n')
        (self.home / '.profile').write_text('export EXAMPLE=yes\n')
        self.default = self.top / 'omarchy' / 'default'
        (self.default / 'hypr').mkdir(parents=True)
        (self.default / 'hypr' / 'autostart.lua').write_text('hl.exec_cmd("omarchy-launch-shell")\n')
        (self.default / 'hypr' / 'bindings.lua').write_text('-- upstream default bindings\n')
        (self.default / 'themes').mkdir(); (self.default / 'themes' / 'gruvbox.conf').write_text('accent=teal\n')
        (self.default / 'dotfiles').mkdir(); (self.default / 'dotfiles' / 'zshrc').write_text('# upstream zsh\n')
        self.env = dict(os.environ)
        self.env.update(HOME=str(self.home), XDG_CONFIG_HOME=str(self.config),
                        XDG_STATE_HOME=str(self.home / '.local/state'),
                        XDG_DATA_HOME=str(self.home / '.local/share'),
                        OMARCHY_PATH=str(self.top / 'omarchy'))
        self.env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        self.state = self.home / '.local/state/rusticq/integration'

    def run_helper(self, *args, ok=True):
        call = subprocess.run([sys.executable, str(HELPER), *args], env=self.env,
                              capture_output=True, text=True, timeout=20)
        try: result = json.loads(call.stdout)
        except ValueError: raise AssertionError((call.stdout, call.stderr))
        self.assertEqual(call.returncode == 0, ok, result)
        return result

    def test_complete_defaults_and_user_dotfiles_before_each_override(self):
        before = self.run_helper('status')
        self.assertEqual(before['shortcut_archives']['count'], 0)
        self.assertFalse((self.state / 'backup').exists())
        result = self.run_helper('shortcut', '--key', 'SUPER + ESCAPE', '--action', 'power')
        archive = Path(result['backup_dir'])
        self.assertTrue(archive.is_dir())
        self.assertEqual((archive / 'config/hypr/bindings.lua').read_text(), self.original)
        self.assertEqual((archive / 'config/hypr/monitors.lua').read_text(), '-- custom monitor before override\n')
        self.assertEqual((archive / 'config/waybar/config.jsonc').read_text(), 'original bar')
        self.assertEqual((archive / 'home/.zshrc').read_text(), '# customized shell dotfile\n')
        default_backup = Path(result['default_backup_dir'])
        self.assertTrue((default_backup / 'default/themes/gruvbox.conf').is_file())
        self.assertTrue((default_backup / 'default/dotfiles/zshrc').is_file())
        self.assertEqual((self.default / 'hypr/bindings.lua').read_text(), '-- upstream default bindings\n')
        self.assertIn('o.bind("SUPER + ESCAPE"', self.bindings.read_text())
        self.assertEqual(archive.stat().st_mode & 0o777, 0o700)
        self.assertEqual((archive/'home/.zshrc').stat().st_mode & 0o777, 0o600)
        second = self.run_helper('shortcut', '--key', 'SUPER + SHIFT + R', '--action', 'settings')
        self.assertNotEqual(result['backup_dir'], second['backup_dir'])
        self.assertIn('o.bind("SUPER + ESCAPE"', (Path(second['backup_dir']) / 'config/hypr/bindings.lua').read_text())
        self.assertEqual(Path(result['backup_dir']).joinpath('config/hypr/bindings.lua').read_text(), self.original)
        summary = self.run_helper('verify-shortcut-backups')
        self.assertEqual(summary['count'], 2)
        self.assertTrue(summary['default']['ok'])
        status = self.run_helper('status')
        self.assertEqual(status['shortcut_archives']['count'], 2)
        self.assertTrue(status['shortcut_archives']['defaults_present'])
        self.run_helper('shortcut-revert', '--action', 'power')
        self.assertEqual(self.run_helper('verify-shortcut-backups')['count'], 3)
        self.run_helper('shortcut-revert', '--action', 'settings')
        self.assertEqual(self.bindings.read_text(), self.original)
        self.assertTrue(default_backup.exists())
        self.assertEqual(self.run_helper('verify-shortcut-backups')['count'], 4)

    def test_verify_is_actionable_and_create_backup_does_not_edit_shortcut(self):
        absent = self.run_helper('verify-shortcut-backups', ok=False)
        self.assertIn('Create backup now', absent['message'])
        original = self.bindings.read_bytes()
        result = self.run_helper('create-shortcut-backup')
        self.assertTrue(result['backup_verified'])
        self.assertEqual(result['count'], 1)
        self.assertGreater(result['default_files'], 0)
        self.assertTrue(Path(result['backup_dir']).is_dir())
        self.assertTrue(Path(result['default_backup_dir']).is_dir())
        self.assertEqual(original, self.bindings.read_bytes())
        report = self.run_helper('verify-shortcut-backups')
        self.assertEqual(report['count'], 1)
        self.assertEqual(report['default_files'], result['default_files'])
        self.assertTrue(report['default']['ok'])
        self.assertEqual(self.run_helper('status')['shortcuts'], {})

    def test_create_backup_failure_is_shown_and_keeps_shortcuts_untouched(self):
        (self.config / 'hypr' / 'oversized.dat').write_bytes(b'X' * 64_000_100)
        original = self.bindings.read_bytes()
        result = self.run_helper('create-shortcut-backup', ok=False)
        self.assertIn('size limit', result['message'])
        self.assertEqual(self.bindings.read_bytes(), original)
        self.assertEqual(self.run_helper('status')['shortcuts'], {})

    def test_corrupted_backup_refuses_next_override_without_mutation(self):
        result = self.run_helper('shortcut', '--key', 'SUPER + SHIFT + R', '--action', 'settings')
        before = self.bindings.read_bytes()
        full = Path(result['default_backup_dir']) / 'default/themes/gruvbox.conf'
        full.write_text('tampered\n')
        failed = self.run_helper('shortcut', '--key', 'SUPER + ALT + P', '--action', 'power', ok=False)
        self.assertIn('checksum mismatch', failed['message'])
        self.assertEqual(self.bindings.read_bytes(), before)

    def test_missing_omarchy_defaults_fail_closed(self):
        # The old is_omarchy() check implicitly required the defaults folder;
        # a broken Omarchy installation could otherwise silently skip its backup.
        import shutil
        shutil.rmtree(self.default)
        result = self.run_helper('create-shortcut-backup', ok=False)
        self.assertIn('Omarchy full defaults missing', result['message'])
        self.assertEqual(self.bindings.read_text(), self.original)
        self.assertEqual(self.run_helper('status')['shortcuts'], {})

    def test_invalid_top_level_symlink_aborts_before_lua_change(self):
        (self.config / 'waybar' / 'config.jsonc').unlink()
        (self.config / 'waybar').rmdir()
        (self.config / 'waybar').symlink_to(self.config / 'omarchy', target_is_directory=True)
        failed = self.run_helper('shortcut', '--key', 'SUPER + SHIFT + Q', '--action', 'settings', ok=False)
        self.assertIn('Symlinked top-level', failed['message'])
        self.assertEqual(self.bindings.read_text(), self.original)

    def test_existing_managed_shortcut_does_not_relabel_current_state_pristine(self):
        # Simulate a user upgrading from an older RusticQ ZIP after an override
        # already changed bindings, with no permanent-integration backup.
        block = ('-- BEGIN RUSTICQ MANAGED RC4\n'
                 'o.rebind("SUPER + SHIFT + R", "RusticQ Settings", "qs ipc call rusticq settings")\n'
                 '-- END RUSTICQ MANAGED RC4\n')
        self.bindings.write_text(self.original + '\n' + block)
        self.state.mkdir(parents=True)
        (self.state / 'shortcuts.json').write_text('{"settings":"SUPER + SHIFT + R"}\n')
        before = self.bindings.read_text()
        result = self.run_helper('shortcut', '--key', 'SUPER + ALT + P', '--action', 'power')
        self.assertEqual((Path(result['backup_dir']) / 'config/hypr/bindings.lua').read_text(), before)
        self.assertFalse((self.state / 'backup/omarchy-snapshot.json').exists())
        self.assertFalse((self.state / 'backup/user-config-index.json').exists())
        self.assertTrue(Path(result['default_backup_dir']).exists())

    def test_backup_failure_does_not_mutate_live_bindings(self):
        (self.config / 'waybar' / 'large.log').write_bytes(b'0' * 64_000_100)
        failed = self.run_helper('shortcut', '--key', 'SUPER + ALT + R', '--action', 'settings', ok=False)
        self.assertIn('size limit', failed['message'])
        self.assertEqual(self.bindings.read_text(), self.original)
        self.assertEqual(self.run_helper('status')['shortcuts'], {})


if __name__ == '__main__':
    unittest.main()
