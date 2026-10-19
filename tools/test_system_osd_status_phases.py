#!/usr/bin/env python3
"""Regression for microphone status, 3-phase keyboard light and touchpad controls.

Uses simulated sysfs and hyprctl results. Never changes the current compositor.
"""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
script = ROOT / 'scripts/rusticq-osd-hardware.py'
spec = importlib.util.spec_from_file_location('rusticq_hw_status_tests', script)
hw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hw)


def content(name): return (ROOT / name).read_text()


class StatusOsdTests(unittest.TestCase):
    def test_mic_state_does_not_use_percentage(self):
        controller = content('modules/main/SystemOsdController.qml')
        osd = content('modules/main/SystemOsd.qml')
        self.assertEqual(controller.count('root.present("microphone", 0,'), 2)
        self.assertNotIn('root.source.audio.volume * 100', controller)
        self.assertNotIn('audio.volume * 100, audio.muted ? "Microphone', controller)
        self.assertIn('root.kind !== "microphone"', osd)
        self.assertIn('Store.osdMuted ? "MUTED" : "ACTIVE"', osd)
        self.assertIn('root.kind === "microphone"', osd)

    def test_keyboard_phases_exact_for_real_3_stage_device(self):
        self.assertEqual([hw.keyboard_stage(n, 3) for n in range(4)],
                         [(0, 3), (1, 3), (2, 3), (3, 3)])
        self.assertEqual(hw.keyboard_target(2, 3, 1), (3, 3, 3))
        self.assertEqual(hw.keyboard_target(2, 3, -1), (1, 1, 3))
        self.assertEqual(hw.keyboard_target(0, 3, -1), (0, 0, 3))
        self.assertEqual(hw.keyboard_target(3, 3, 1), (3, 3, 3))

    def test_keyboard_large_led_quantized_to_three_not_percent(self):
        self.assertEqual(hw.keyboard_stage(170, 255), (2, 3))
        self.assertEqual(hw.keyboard_target(170, 255, 1), (255, 3, 3))
        self.assertEqual(hw.keyboard_target(170, 255, -1), (85, 1, 3))
        self.assertEqual(hw.keyboard_stage(1, 1), (1, 1))
        self.assertEqual(hw.keyboard_stage(1, 2), (1, 2))
        ui = content('modules/main/SystemOsd.qml')
        self.assertIn('model: Store.osdStages', ui)
        self.assertIn('Store.osdStage === 0 ? "OFF"', ui)
        self.assertIn('index < Store.osdStage', ui)
        self.assertIn('root.kind !== "keyboard"', ui)

    def test_keyboard_watcher_emits_stages_not_percent(self):
        with tempfile.TemporaryDirectory() as temp:
            base=Path(temp); dev=base/'asus::kbd_backlight'; dev.mkdir()
            (dev/'max_brightness').write_text('3'); (dev/'brightness').write_text('1')
            with patch.object(hw,'BACKLIGHT',base/'none'),patch.object(hw,'LEDS',base):
                captured=[]; steps=[0]
                def sleeping(_):
                    steps[0]+=1
                    if steps[0] == 2: (dev/'brightness').write_text('2')
                    if steps[0] == 4: raise StopIteration
                with patch.object(hw.time,'sleep',side_effect=sleeping),patch.object(hw,'emit',side_effect=lambda **k: captured.append(k)):
                    with self.assertRaises(StopIteration): hw.watch()
                self.assertEqual(len(captured),1)
                self.assertEqual(captured[0]['stage'],2)
                self.assertEqual(captured[0]['stages'],3)
                self.assertNotIn('percent',captured[0])

    def test_touchpad_explicit_on_off_toggle_and_no_mouse(self):
        with tempfile.TemporaryDirectory() as temp:
            runtime=Path(temp)/'rusticq'
            recorded=[]; events=[]
            def fake_run(args,**kwargs):
                recorded.append(args)
                if args[:3] == ['hyprctl','-j','devices']:
                    return subprocess.CompletedProcess(args,0,stdout=json.dumps({'mice':[
                        {'name':'usb-mouse'}, {'name':'elan-touchpad'}]}),stderr='')
                return subprocess.CompletedProcess(args,0,stdout='ok',stderr='')
            with patch.object(hw, 'RUNTIME',runtime),patch.object(hw,'TOUCHPAD_STATUS',runtime/'status.json'),\
                 patch.object(hw.subprocess,'run',side_effect=fake_run),patch.object(hw,'emit',side_effect=lambda **kw: events.append(kw)),\
                 patch.object(hw,'omarchy_touchpad_disabled',return_value=False):
                hw.change_touchpad('touchpad-off')
                hw.change_touchpad('touchpad-off')  # already off, no second command
                hw.change_touchpad('touchpad-on')
                hw.change_touchpad('touchpad-toggle')
            self.assertEqual([e['enabled'] for e in events], [False,False,True,False])
            evals=[a for a in recorded if a[1]=='eval']
            self.assertEqual(len(evals),3)
            for call in evals:
                self.assertIn('elan-touchpad',call[-1])
                self.assertNotIn('usb-mouse',call[-1])
            self.assertEqual(json.loads((runtime/'status.json').read_text())['enabled'],False)

    def test_touchpad_lua_escaped_and_keyword_fallback(self):
        calls=[]
        def run(args,**kw):
            calls.append(args)
            if args[1] == 'eval':
                return subprocess.CompletedProcess(args,1,stdout='',stderr='unsupported eval')
            return subprocess.CompletedProcess(args,0,stdout='ok',stderr='')
        with patch.object(hw.subprocess,'run',side_effect=run):
            hw._set_touchpad('name";os.execute("bad")--touchpad',False)
            self.assertIn('\\"', calls[0][-1])
            self.assertEqual(calls[1][1],'keyword')
            with self.assertRaisesRegex(ValueError,'Unsafe touchpad name'):
                hw._set_touchpad('evil\nname-touchpad',False)

    def test_keyboard_and_touchpad_ui_controls_are_connected(self):
        for action in ('touchpad-on','touchpad-off','touchpad-toggle'):
            self.assertIn('"'+action+'"',content('modules/main/SystemOsdController.qml'))
            self.assertIn('"'+action+'"',content('shell.qml'))
            self.assertIn("'osd-"+action+"'",content('scripts/rustiq-desktop-integration.py'))
            self.assertIn('action:"'+action+'"',content('modules/settings/pages/SettingsModulesPage.qml'))
            self.assertIn("'"+action+"'",content('scripts/rusticq-osd-hardware.py'))

if __name__=='__main__': unittest.main()
