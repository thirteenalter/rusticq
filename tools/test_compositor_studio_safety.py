#!/usr/bin/env python3
"""29 independent checks for RusticQ Beta-3 compositor editor security.

All tests run in fake XDG_HOME and command fixtures. They never touch real WM.
"""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/rusticq-compositor-config.py'
spec = importlib.util.spec_from_file_location('rusticq_compositor_test_module', SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

MAIN = 'require("default.hypr.omarchy")\nrequire("hypr.monitors")\nrequire("hypr.input")\nrequire("hypr.bindings")\nrequire("hypr.looknfeel")\nrequire("hypr.autostart")\n'


class CompositorStudioSafety(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / 'home'
        self.config = self.home / '.config'
        self.state = self.home / '.local/state/rusticq/compositor-config'
        h = self.config / 'hypr'; h.mkdir(parents=True)
        (h / 'hyprland.lua').write_text(MAIN)
        for n in m.LUA_SECTIONS.values(): (h / n).write_text('-- existing user configuration\n')
        n = self.config / 'niri'; n.mkdir(parents=True)
        (n / 'config.kdl').write_text('// existing niri config\n')
        bin = self.root / 'bin'; bin.mkdir()
        self.fake_hypr = bin / 'hyprctl'
        self.fake_hypr.write_text('#!/bin/sh\nif [ "$1" = configerrors ]; then echo ok; fi\n')
        self.fake_hypr.chmod(0o755)
        self.fake_niri = bin / 'niri'
        self.fake_niri.write_text('#!/bin/sh\nif grep -q BROKEN "$4" 2>/dev/null; then exit 1; fi\nexit 0\n')
        self.fake_niri.chmod(0o755)
        self.env = patch.dict(os.environ, {'XDG_CURRENT_DESKTOP': 'Hyprland', 'PATH': str(bin) + ':' + os.environ['PATH']}, clear=False)
        self.env.start(); self.addCleanup(self.env.stop)
        self.cfg = patch.object(m, 'CONFIG', self.config); self.cfg.start(); self.addCleanup(self.cfg.stop)
        self.st = patch.object(m, 'STATE', self.state); self.st.start(); self.addCleanup(self.st.stop)
        self.h = patch.object(m, 'HOME', self.home); self.h.start(); self.addCleanup(self.h.stop)
        self.patch_socket = patch.dict(os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': '', 'NIRI_SOCKET': ''}, clear=False)
        self.patch_socket.start(); self.addCleanup(self.patch_socket.stop)

    def source(self, name='autostart.lua'):
        return self.config / 'hypr' / name

    def demo_apply(self, section='autostart', values=None):
        if values is None: values={'commands': ['waybar']}
        prev = m.preview('hyprland', section, values)
        return m.apply('hyprland', section, values, prev['token'])

    def test_01_hyprland_detect_by_desktop(self):
        self.assertEqual(m.compositor(), 'hyprland')

    def test_02_hyprland_detect_by_socket(self):
        with patch.dict(os.environ, {'XDG_CURRENT_DESKTOP':'niri','HYPRLAND_INSTANCE_SIGNATURE':'abc'}):
            self.assertEqual(m.compositor(), 'hyprland')

    def test_03_niri_detect_by_desktop(self):
        with patch.dict(os.environ, {'XDG_CURRENT_DESKTOP':'niri'}): self.assertEqual(m.compositor(),'niri')

    def test_04_niri_detect_by_socket(self):
        with patch.dict(os.environ, {'NIRI_SOCKET':'sock'}): self.assertEqual(m.compositor(),'niri')

    def test_05_ambiguous_socket_detection(self):
        with patch.dict(os.environ, {'HYPRLAND_INSTANCE_SIGNATURE':'abc', 'NIRI_SOCKET':'xyz'}): self.assertEqual(m.compositor(),'ambiguous')

    def test_06_unknown_session_read_only(self):
        with patch.dict(os.environ, {'XDG_CURRENT_DESKTOP':'GNOME'}): self.assertFalse(any(m.summary()['editable'].values()))

    def test_07_hyprland_all_four_enabled(self):
        self.assertTrue(all(m.summary()['editable'].values()))

    def test_08_niri_requires_schema_gate(self):
        with patch.dict(os.environ, {'XDG_CURRENT_DESKTOP':'niri'}):
            self.assertTrue(m.summary()['editable']['autostart'])
            self.assertTrue(m.summary()['editable']['appearance'])
            self.assertFalse(m.summary()['editable']['input'])
            self.assertFalse(m.summary()['editable']['monitors'])

    def test_09_autostart_rejects_multiline_in_one_item(self):
        with self.assertRaisesRegex(ValueError,'single lines'): m.validate('hyprland','autostart',{'commands':['ok\nrm -rf /']})

    def test_10_autostart_rejects_empty_and_too_many(self):
        for values in ({'commands':['']},{'commands':['x']*25}):
            with self.assertRaises(ValueError): m.validate('hyprland','autostart',values)

    def test_11_input_rejects_metacharacters(self):
        with self.assertRaisesRegex(ValueError,'keyboard'): m.validate('hyprland','input',dict(kb_layout='us; touchpad=false',follow_mouse=True,natural_scroll=False))

    def test_12_appearance_rejects_out_of_range(self):
        with self.assertRaises(ValueError): m.validate('hyprland','appearance',dict(gaps_in=999,gaps_out=10,rounding=8))

    def test_13_monitor_rejects_bad_output(self):
        with self.assertRaisesRegex(ValueError,'output'): m.validate('hyprland','monitors',dict(output='../DP-1',mode='preferred',position='auto',scale=1))

    def test_14_preview_is_strictly_read_only(self):
        before=self.source().read_bytes()
        result=m.preview('hyprland','autostart',{'commands':['foot']})
        self.assertTrue(result['changed'])
        self.assertIn('hl.exec_cmd',result['diff'])
        self.assertEqual(self.source().read_bytes(),before)
        self.assertFalse(self.state.exists())

    def test_15_autostart_escaped_quotes_and_backslashes(self):
        s=m.generate('hyprland','autostart',{'commands':['echo "hello" \\ world']})
        self.assertIn('hl.exec_cmd(',s)
        self.assertIn('\\"hello\\"',s)
        self.assertIn('\\\\ world',s)

    def test_16_apply_preserves_original_user_lines(self):
        orig=self.source().read_text()
        applied=self.demo_apply()
        self.assertTrue(applied['ok'])
        self.assertTrue(self.source().read_text().startswith(orig))
        self.assertTrue(Path(applied['backup']).is_dir())

    def test_17_reapply_replaces_only_one_owned_block(self):
        self.demo_apply()
        self.demo_apply(values={'commands':['ghostty']})
        current=self.source().read_text()
        self.assertEqual(current.count(m.BEGIN+'autostart'),1)
        self.assertIn('ghostty',current)
        self.assertNotIn('waybar',current)

    def test_18_preview_token_refuses_concurrent_edits(self):
        vals={'commands':['foot']}
        prev=m.preview('hyprland','autostart',vals)
        self.source().write_text('-- changed by other tool\n')
        with self.assertRaisesRegex(ValueError,'Preview expired'): m.apply('hyprland','autostart',vals,prev['token'])

    def test_19_symlinked_config_refused(self):
        f=self.source(); f.unlink(); f.symlink_to(self.config/'niri/config.kdl')
        with self.assertRaisesRegex(ValueError,'Symlinked'): m.preview('hyprland','autostart',{'commands':['foot']})

    def test_20_missing_lua_require_refused(self):
        (self.config/'hypr/hyprland.lua').write_text('-- no imports\n')
        with self.assertRaisesRegex(ValueError,'does not load'): m.preview('hyprland','autostart',{'commands':['foot']})

    def test_21_failed_hyprland_reload_restores_original(self):
        orig=self.source().read_bytes()
        self.fake_hypr.write_text('#!/bin/sh\nif [ "$1" = configerrors ]; then grep -q "RUSTICQ COMPOSITOR CONFIG" ' + str(self.source()) + ' && echo "Lua syntax error" || echo ok; fi\n')
        with self.assertRaisesRegex(ValueError,'original file restored'): self.demo_apply()
        self.assertEqual(self.source().read_bytes(),orig)

    def test_22_rollback_refuses_overwriting_newer_edits(self):
        r=self.demo_apply()
        self.source().write_text('-- edited later\n')
        with self.assertRaisesRegex(ValueError,'changed since snapshot'): m.rollback(Path(r['backup']).name)

    def test_23_rollback_restores_and_validates_original(self):
        orig=self.source().read_bytes()
        r=self.demo_apply()
        self.assertTrue(m.rollback(Path(r['backup']).name)['ok'])
        self.assertEqual(self.source().read_bytes(),orig)

    def test_24_niri_autostart_and_gaps_apply(self):
        with patch.dict(os.environ, {'XDG_CURRENT_DESKTOP':'niri'}):
            p=self.config/'niri/config.kdl'
            before=p.read_text()
            v={'commands':['waybar']}
            preview=m.preview('niri','autostart',v)
            applied=m.apply('niri','autostart',v,preview['token'])
            self.assertTrue(applied['ok'])
            self.assertIn('spawn-sh-at-startup "waybar"',p.read_text())
            v2={'gaps_in':8,'gaps_out':10}
            preview=m.preview('niri','appearance',v2)
            self.assertTrue(m.apply('niri','appearance',v2,preview['token'])['ok'])
            self.assertIn('gaps 8',p.read_text())
            # Rolling back an earlier snapshot after a later edit should be blocked.
            with self.assertRaisesRegex(ValueError,'changed since snapshot'): m.rollback(Path(applied['backup']).name)
            self.assertTrue(p.read_text().startswith(before))

    def test_25_no_duplicate_existing_managed_marker(self):
        self.source().write_text((m.BEGIN+'autostart\n')*2+(m.END+'autostart\n')*2)
        with self.assertRaisesRegex(ValueError,'inconsistent'): m.preview('hyprland','autostart',{'commands':['foot']})

    def test_26_no_unverified_niri_when_validator_missing(self):
        with patch.dict(os.environ,{'XDG_CURRENT_DESKTOP':'niri','PATH':'/nonexistent'}):
            with self.assertRaisesRegex(ValueError,'validator|binary'): m.preview('niri','autostart',{'commands':['waybar']})

    def test_27_unsupported_niri_input_is_readonly(self):
        with self.assertRaisesRegex(ValueError,'read-only'): m.require_loaded('niri','input')

    def test_29_utf8_command_preserves_original_bytes(self):
        command = "notify-send café ☀"
        code = m.lua_string(command)
        self.assertNotIn('Ã', code)
        self.assertIn('\\195', code)
        self.assertIn('\\169', code)

    def test_28_no_dangerous_uncontrolled_rewrite(self):
        contents='-- original custom Lua\n-- custom tail\n'.encode()
        output=m.replace_block(contents,'hyprland','autostart',{'commands':['foot']})
        self.assertTrue(output.startswith(contents))
        self.assertNotIn(b'require("default.hypr', output)


if __name__=='__main__': unittest.main(verbosity=2)
