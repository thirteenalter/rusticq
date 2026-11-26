#!/usr/bin/env python3
"""Studio transactions with isolated configs and a mocked Hyprland protocol."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import hypr_settings_studio as studio
spec = importlib.util.spec_from_file_location('studio_gateway', ROOT / 'scripts/rusticq-compositor-config.py')
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)


class Studio(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / 'config'
        self.directory = self.config / 'hypr'
        self.directory.mkdir(parents=True)
        self.root = self.directory / 'hyprland.lua'
        self.original = b'-- custom configuration and comments\nhl.config({ general = { gaps_in = 3 } })\n'
        self.root.write_bytes(self.original)
        for key, value in [('HOME', self.home), ('CONFIG', self.config), ('STATE', self.home / 'state')]:
            p = patch.object(core, key, value); p.start(); self.addCleanup(p.stop)
        p = patch.object(core, 'compositor', return_value='hyprland'); p.start(); self.addCleanup(p.stop)
        self.version = '0.55.0'
        self.errors = ''
        self.reloads = 0
        self.bad_apply = False
        p = patch.object(studio, 'ctl', side_effect=self.ctl); p.start(); self.addCleanup(p.stop)
        p = patch.object(studio.shutil, 'which', return_value='/fixture/hyprctl');p.start();self.addCleanup(p.stop)

    def ctl(self, core, *args, optional=False):
        if args == ('-j', 'version'): return json.dumps({'version': self.version})
        if args == ('-j', 'instances'): return '[]'
        if args[:2] == ('-j', 'getoption'):
            key = args[-1]
            if 'unsupported' in key: return '{"error":"unknown option"}'
            spec = studio.BY_ID.get(key) or next((s for s in studio.OPTIONS if s['id'].replace(':','.') == key), None)
            if not spec: return '{}'
            kind = spec['type']; value = spec['default']
            fragment=self.directory/('rusticq-studio.lua' if self.root.suffix=='.lua' else 'rusticq-studio.conf')
            if fragment.exists():
                match=__import__('re').search(studio.META+r'([A-Za-z0-9+/=]+)',fragment.read_text())
                if match:
                    data=json.loads(__import__('base64').b64decode(match[1]));value=data['options'].get(spec['id'],value)
            return json.dumps({'option':key, {'bool':'int','int':'int','float':'float','string':'str'}[kind]:int(value) if kind == 'bool' else value})
        if args == ('configerrors',): return self.errors
        if args == ('reload',):
            self.reloads += 1
            self.errors = 'bad config' if self.bad_apply and self.reloads == 1 else ''
            return 'ok'
        if args == ('-j','activeworkspace'): return '{"name":"1"}'
        if args == ('-j','devices'): return '{}'
        return '[]'

    def payload(self, options=None, records=None):
        revision = core.digest(studio.packed(core, studio.included_files(core,self.root)))
        return dict(options=options or {'decoration:rounding':14}, records=records or {}, revision=revision)

    def apply(self, payload=None):
        payload = payload or self.payload()
        plan = studio.preview(core,payload)
        return studio.apply(core,payload,plan['token'])

    def test_status_reports_effective_values_and_schema(self):
        state = studio.status(core)
        self.assertTrue(state['info']['editable'])
        self.assertEqual(len(state['categories']),21)
        self.assertEqual(state['options'][0]['effective'],0)
        self.assertNotIn('decoration:rounding',state['data']['options'])

    def test_preview_never_writes(self):
        plan = studio.preview(core,self.payload())
        self.assertIn('dofile',plan['diff'])
        self.assertEqual(self.root.read_bytes(),self.original)
        self.assertFalse(Path(plan['info']['managedPath']).exists())

    def test_atomic_apply_preserves_original_and_includes(self):
        result = self.apply()
        self.assertTrue(self.root.read_bytes().startswith(self.original))
        self.assertEqual(self.root.read_text().count('BEGIN RUSTICQ'),1)
        self.assertEqual(studio.history(core)[0]['id'],result['snapshot'])
        self.assertEqual(studio.managed_data(core,studio.detect(core))['options']['decoration:rounding'],14)

    def test_repeated_apply_does_not_duplicate_source(self):
        self.apply(); self.apply(self.payload({'decoration:rounding':16}))
        self.assertEqual(self.root.read_text().count('BEGIN RUSTICQ'),1)

    def test_failed_validation_rolls_back_both_files(self):
        self.bad_apply = True
        with self.assertRaisesRegex(ValueError,'original files restored'): self.apply()
        self.assertEqual(self.root.read_bytes(),self.original)
        self.assertFalse((self.directory/'rusticq-studio.lua').exists())
        self.assertEqual(studio.history(core)[0]['state'],'rolled-back')

    def test_restore_previous_configuration(self):
        result = self.apply(); studio.rollback(core,result['snapshot'])
        self.assertEqual(self.root.read_bytes(),self.original)
        self.assertFalse((self.directory/'rusticq-studio.lua').exists())

    def test_restore_rejects_external_edit(self):
        result = self.apply(); self.root.write_text(self.root.read_text()+'-- new edit\n')
        with self.assertRaisesRegex(ValueError,'newer edits'): studio.rollback(core,result['snapshot'])

    def test_external_include_change_rejects_preview(self):
        include = self.directory/'look.lua'; include.write_text('-- old\n')
        self.root.write_text('dofile("'+str(include)+'")\n')
        payload = self.payload(); include.write_text('-- modified elsewhere\n')
        with self.assertRaisesRegex(ValueError,'externally'): studio.preview(core,payload)

    def test_changed_preview_payload_requires_new_token(self):
        payload = self.payload(); plan = studio.preview(core,payload); payload['options']['decoration:rounding']=16
        with self.assertRaisesRegex(ValueError,'expired'): studio.apply(core,payload,plan['token'])

    def test_invalid_and_unsupported_options(self):
        for options in [{'decoration:rounding':100}, {'decoration:rounding':1.5}, {'animations:enabled':'yes'}, {'bad:unsupported':2}, {'general:layout':'made-up'}]:
            with self.subTest(options=options), self.assertRaises(ValueError): studio.preview(core,self.payload(options))

    def test_color_validation_and_lua_no_injection(self):
        with self.assertRaises(ValueError): studio.preview(core,self.payload({'general:col.active_border':'os.execute("bad")'}))
        plan=studio.preview(core,self.payload({'input:kb_options':'"); os.execute("bad") --'}))
        self.assertIn('\\"',plan['generated'])

    def test_lua_rules_generated_separately_from_legacy(self):
        plan=studio.preview(core,self.payload(records={'window-rules':[{'class':'^kitty$', 'mode':'float'}]}))
        self.assertIn('hl.window_rule',plan['generated']); self.assertNotIn('windowrulev2',plan['generated'])

    def test_legacy_options_and_records(self):
        self.root.unlink(); self.root=self.directory/'hyprland.conf'; self.original=b'# old comment\n'; self.root.write_bytes(self.original); self.version='0.54.0'
        plan=studio.preview(core,self.payload(records={'autostart':[{'command':'terminal', 'once':True}]}))
        self.assertIn('decoration:rounding = 14',plan['generated']); self.assertIn('exec-once = terminal',plan['generated']); self.assertNotIn('hl.',plan['generated'])
        self.apply(); self.assertIn('source = ',self.root.read_text())
        with self.assertRaisesRegex(ValueError,'not audited'): studio.preview(core,self.payload(records={'window-rules':[{'class':'kitty'}]}))

    def test_future_version_is_read_only(self):
        self.version='0.99.0'
        self.assertFalse(studio.detect(core)['editable'])
        with self.assertRaises(ValueError): studio.preview(core,self.payload())

    def test_missing_session_is_read_only(self):
        with patch.object(core,'compositor',return_value='niri'):
            self.assertFalse(studio.detect(core)['editable'])

    def test_foreign_fragment_is_not_overwritten(self):
        (self.directory/'rusticq-studio.lua').write_text('-- user file\n')
        with self.assertRaisesRegex(ValueError,'unrecognized'): studio.preview(core,self.payload())

    def test_symlink_root_is_not_writable(self):
        target=self.directory/'real.lua';self.root.rename(target);self.root.symlink_to(target)
        self.assertFalse(studio.detect(core)['editable'])

    def test_malformed_markers_fail_closed(self):
        self.root.write_text('-- BEGIN RUSTICQ HYPRLAND SETTINGS\n')
        with self.assertRaisesRegex(ValueError,'Malformed'): studio.preview(core,self.payload())

    def test_duplicates_and_secret_env_are_rejected(self):
        for records in [{'autostart':[{'command':'foo'},{'command':'foo'}]}, {'environment':[{'name':'API_KEY','value':'never-store-this'}]}]:
            with self.assertRaises(ValueError): studio.preview(core,self.payload(records=records))

    def test_animation_disable_is_a_real_override(self):
        plan=studio.preview(core,self.payload(records={'animations':[{'leaf':'windows','enabled':False}]}))
        self.assertIn('["enabled"] = false',plan['generated'])

    def test_no_compositor_writes_for_local_preview(self):
        studio.preview(core,self.payload());self.assertEqual(self.reloads,0)

    def test_preset_scope_excludes_sensitive_sections(self):
        for preset in studio.PRESETS.values():
            self.assertTrue(all(studio.BY_ID[key]['page'] in ('appearance','effects','animations','performance') for key in preset))

    def test_snapshot_without_apply_and_restore(self):
        result=studio.snapshot(core)
        studio.rollback(core,result['snapshot'])
        self.assertEqual(self.root.read_bytes(),self.original)
        self.assertFalse((self.directory/'rusticq-studio.lua').exists())

    def test_custom_preset_contains_no_automation(self):
        result=studio.save_preset(core,'My preset',self.payload(records={'autostart':[{'command':'terminal'}]}))
        self.assertIn('My preset',result['presets'])
        self.assertEqual(studio.custom_presets(core)['My preset'],{'decoration:rounding':14})
        self.assertEqual(self.reloads,0)

    def test_export_import_roundtrip_does_not_apply(self):
        target=self.home/'export.json'
        studio.transfer(core,'export',str(target),self.payload())
        result=studio.transfer(core,'import',str(target),{})
        self.assertEqual(result['data']['options'],{'decoration:rounding':14})
        self.assertEqual(self.reloads,0)

    def test_restore_rejects_changed_include(self):
        include=self.directory/'custom.lua';include.write_text('-- original\n')
        self.root.write_text('dofile("'+str(include)+'")\n')
        result=self.apply();include.write_text('-- externally modified\n')
        with self.assertRaisesRegex(ValueError,'Included configuration'): studio.rollback(core,result['snapshot'])

    def test_altered_source_block_is_rejected(self):
        self.apply()
        self.root.write_text(self.root.read_text().replace('dofile(', 'require('))
        with self.assertRaisesRegex(ValueError,'source block'): studio.preview(core,self.payload())

    def test_modern_bool_protocol_and_css_gaps(self):
        with patch.object(studio,'ctl',return_value='{"option":"animations.enabled","bool":true}'):
            value=studio.probe_option(core,studio.BY_ID['animations:enabled'],'lua')
            self.assertIs(value['effective'],True)
        with patch.object(studio,'ctl',return_value='{"option":"general.gaps_in","css":"5 5 5 5"}'):
            self.assertEqual(studio.probe_option(core,studio.BY_ID['general:gaps_in'],'lua')['effective'],5)
        with patch.object(studio,'ctl',return_value='{"option":"general.gaps_in","css":"5 10 5 10"}'):
            self.assertIsNone(studio.probe_option(core,studio.BY_ID['general:gaps_in'],'lua')['effective'])

    def test_empty_environment_value_and_workspace_layout_are_supported(self):
        plan=studio.preview(core,self.payload(records={'environment':[{'name':'TEST_EMPTY','value':''}], 'workspaces':[{'workspace':'2'}]}))
        self.assertIn('hl.env("TEST_EMPTY", "")',plan['generated'])
        self.assertNotIn('["layout"]',plan['generated'])

    def test_returning_lua_entrypoint_is_not_silently_ignored(self):
        self.root.write_text('return require("myconfig")\n')
        with self.assertRaisesRegex(ValueError,'returns before'):studio.preview(core,self.payload())

    def test_missing_cli_dependency_is_reported(self):
        with patch.object(studio.shutil,'which',return_value=None):
            info=studio.detect(core)
            self.assertFalse(info['editable']);self.assertIn('hyprctl is missing',info['reason'])

    def test_cancellation_during_write_restores_both_files(self):
        original_atomic=core.atomic;interrupted=False
        def atomic(path,content):
            nonlocal interrupted
            original_atomic(path,content)
            if path==self.root and not interrupted and content!=self.original:
                interrupted=True;raise InterruptedError('cancelled')
        with patch.object(core,'atomic',side_effect=atomic),self.assertRaisesRegex(ValueError,'original files restored'):
            self.apply()
        self.assertEqual(self.root.read_bytes(),self.original)
        self.assertFalse((self.directory/'rusticq-studio.lua').exists())

    def test_final_manifest_write_failure_is_transactional(self):
        original_atomic=core.atomic;failed=False
        def atomic(path,content):
            nonlocal failed
            if path.name=='manifest.json' and not failed and json.loads(content)['state']=='applied':
                failed=True;raise OSError('simulated disk error')
            original_atomic(path,content)
        with patch.object(core,'atomic',side_effect=atomic),self.assertRaisesRegex(ValueError,'original files restored'):
            self.apply()
        self.assertEqual(self.root.read_bytes(),self.original)
        self.assertEqual(studio.history(core)[0]['state'],'rolled-back')

    def test_preview_restore_older_snapshot_preserves_new_user_comments(self):
        self.apply(self.payload({'decoration:rounding':14}))
        second=self.apply(self.payload({'decoration:rounding':18}))
        self.apply(self.payload({'decoration:rounding':20}))
        self.root.write_text(self.root.read_text()+'-- new custom setting remains\n')
        plan=studio.restore_preview(core,second['snapshot'])
        self.assertIn('14',plan['diff'])
        studio.rollback(core,second['snapshot'],plan['token'])
        self.assertIn('-- new custom setting remains',self.root.read_text())
        self.assertEqual(studio.managed_data(core,studio.detect(core))['options']['decoration:rounding'],14)

    def test_manual_snapshot_can_restore_after_later_apply(self):
        snapshot=studio.snapshot(core)
        self.apply()
        plan=studio.restore_preview(core,snapshot['snapshot'])
        studio.rollback(core,snapshot['snapshot'],plan['token'])
        self.assertFalse((self.directory/'rusticq-studio.lua').exists())
        self.assertNotIn('BEGIN RUSTICQ',self.root.read_text())

    def test_restore_preview_token_rejects_new_external_change(self):
        result=self.apply();plan=studio.restore_preview(core,result['snapshot'])
        self.root.write_text(self.root.read_text()+'-- edit after preview\n')
        with self.assertRaisesRegex(ValueError,'expired'):studio.rollback(core,result['snapshot'],plan['token'])

    def test_two_gateway_writers_share_one_lock(self):
        core.STATE.mkdir(parents=True)
        with (core.STATE/'editor.lock').open('a') as lock:
            studio.fcntl.flock(lock,studio.fcntl.LOCK_EX|studio.fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):self.apply()
        self.assertEqual(self.root.read_bytes(),self.original)

    def test_reported_defaults_and_ranges_override_fallback_schema(self):
        delegate=self.ctl
        def ctl(core,*args,optional=False):
            if args==('-j','descriptions'):
                return json.dumps([{'name':'decoration:rounding','default':0,'min':0,'max':30,'description':'Native rounding description'}])
            return delegate(core,*args,optional=optional)
        with patch.object(studio,'ctl',side_effect=ctl):
            state=studio.status(core)
            self.assertEqual(state['options'][0]['maximum'],30)
            self.assertTrue(state['options'][0]['defaultKnown'])
            self.assertEqual(state['presets']['Default Hyprland'],{'decoration:rounding':0})
            studio.preview(core,self.payload({'decoration:rounding':25}))
            with self.assertRaises(ValueError):studio.preview(core,self.payload({'decoration:rounding':35}))

    def test_unknown_defaults_are_not_fabricated(self):
        state=studio.status(core)
        self.assertFalse(state['options'][0]['defaultKnown'])
        self.assertNotIn('Default Hyprland',state['presets'])


if __name__=='__main__': unittest.main(verbosity=2)
