#!/usr/bin/env python3
"""Regression contracts for transient OSD and non-destructive hardware actions."""
import importlib.util
import json
import os
from pathlib import Path
from unittest.mock import patch
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'scripts/rusticq-osd-hardware.py'
spec=importlib.util.spec_from_file_location('rusticq_osd',SCRIPT)
mod=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def text(file): return (ROOT/file).read_text()


class HardwareOSDTests(unittest.TestCase):
    def test_sysfs_change_emits_only_on_actual_transition(self):
        with tempfile.TemporaryDirectory() as tmp:
            back=Path(tmp)/'backlight'; dev=back/'intel_backlight'; dev.mkdir(parents=True)
            (dev/'brightness').write_text('30')
            (dev/'max_brightness').write_text('100')
            with patch.object(mod,'BACKLIGHT',back), patch.object(mod,'LEDS',Path(tmp)/'nothing'):
                self.assertEqual(mod.snapshot()['brightness'][3],30)
                sent=[]
                counter=[0]
                def sleep(seconds):
                    counter[0]+=1
                    if counter[0]==2: (dev/'brightness').write_text('55')
                    if counter[0]>=4: raise StopIteration()
                def emit(**kwargs): sent.append(kwargs)
                with patch.object(mod.time,'sleep',side_effect=sleep), patch.object(mod,'emit',side_effect=emit):
                    with self.assertRaises(StopIteration): mod.watch()
                self.assertEqual(len(sent),1)
                self.assertEqual(sent[0]['percent'],55)

    def test_brightness_command_uses_brightnessctl_not_sudo(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)/'backlight'; dev=folder/'amdgpu_bl0'; dev.mkdir(parents=True)
            (dev/'brightness').write_text('40'); (dev/'max_brightness').write_text('100')
            calls=[]
            def fake_run(args,**kw):
                calls.append(args)
                (dev/'brightness').write_text(args[-1])
                return subprocess.CompletedProcess(args,0,stdout='',stderr='')
            with patch.object(mod,'BACKLIGHT',folder),patch.object(mod,'LEDS',Path(tmp)/'missing'),patch.object(mod.subprocess,'run',side_effect=fake_run),patch.object(mod,'emit') as record:
                mod.change_backlight('brightness',1)
                self.assertEqual(calls,[['brightnessctl','-d','amdgpu_bl0','set','45']])
                self.assertEqual(record.call_args.kwargs['percent'],45)

    def test_keyboard_backlight_uses_minimum_real_device_step(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)/'leds'; dev=folder/'asus::kbd_backlight'; dev.mkdir(parents=True)
            (dev/'brightness').write_text('1'); (dev/'max_brightness').write_text('3')
            with patch.object(mod,'LEDS',folder),patch.object(mod.subprocess,'run',return_value=subprocess.CompletedProcess([],0,stdout='',stderr='')) as run,patch.object(mod,'emit'):
                mod.change_backlight('keyboard',1)
                self.assertEqual(run.call_args.args[0],['brightnessctl','-d',dev.name,'set','2'])

    def test_touchpad_only_no_all_mice(self):
        devices={'mice':[{'name':'usb-mouse','enabled':True},{'name':'elan-touchpad','enabled':True}]}
        self.assertEqual(mod.touchpads_from_devices(devices), [('elan-touchpad',True)])
        self.assertEqual(mod.touchpads_from_devices({'mice':[{'name':'mouse','enabled':True}]}), [])
        calls=[]
        def fake_run(args,**kw):
            calls.append(args)
            if args[:3]==['hyprctl','-j','devices']:
                return subprocess.CompletedProcess(args,0,stdout=json.dumps(devices),stderr='')
            return subprocess.CompletedProcess(args,0,stdout='ok',stderr='')
        with tempfile.TemporaryDirectory() as tmp, patch.object(mod,'RUNTIME',Path(tmp)/'rusticq'),patch.object(mod,'TOUCHPAD_STATUS',Path(tmp)/'rusticq'/'status.json'),patch.object(mod.subprocess,'run',side_effect=fake_run),patch.object(mod,'emit') as emitter:
            mod.change_touchpad()
            self.assertEqual(calls[-1], ['hyprctl','keyword','device[elan-touchpad]:enabled','false'])
            self.assertEqual(emitter.call_args.kwargs['enabled'],False)
            self.assertEqual(json.loads((Path(tmp)/'rusticq/status.json').read_text())['enabled'],False)

    def test_touchpad_unavailable_or_unknown_fails_closed(self):
        with patch.object(mod.subprocess,'run',return_value=subprocess.CompletedProcess([],0,stdout=json.dumps({'mice':[{'name':'some-mouse','enabled':True}]}),stderr='')):
            with self.assertRaisesRegex(ValueError,'No touchpad'):mod.change_touchpad()
        with tempfile.TemporaryDirectory() as tmp, patch.object(mod,'TOUCHPAD_STATUS',Path(tmp)/'notfound'),patch.object(mod.subprocess,'run',return_value=subprocess.CompletedProcess([],0,stdout=json.dumps({'mice':[{'name':'elan-touchpad'}]}),stderr='')):
            with self.assertRaisesRegex(ValueError,'did not expose'):mod.change_touchpad()

    def test_safeguards_settings_and_shortcut_routing(self):
        shell=text('shell.qml');store=text('config/Store.qml');settings=text('config/SettingsStore.qml');registry=text('scripts/rustiq-desktop-integration.py');controller=text('modules/main/SystemOsdController.qml');ui=text('modules/main/SystemOsd.qml');modules=text('modules/settings/pages/SettingsModulesPage.qml')
        self.assertIn('SystemOsdController {}',shell)
        self.assertIn('SystemOsd { required property var modelData; screen: modelData }',shell)
        self.assertIn('signal osdControlRequested(string action)',store)
        self.assertIn('interval: 1650',store)
        self.assertIn('property bool osdEnabled: true',settings)
        self.assertIn('osdEnabled: osdEnabled',settings)
        self.assertIn('showOsd(',store)
        self.assertIn('heading: "System OSD"',modules)
        self.assertIn('PwObjectTracker',controller)
        self.assertIn('function onMutedChanged()',controller)
        self.assertIn('SplitParser',controller)
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay',ui)
        self.assertIn('focusable: false',ui)
        self.assertIn('ExclusionMode.Ignore',ui)
        for action in ['volume-up','volume-down','volume-mute','microphone-mute','brightness-up','brightness-down','keyboard-up','keyboard-down','touchpad-toggle']:
            self.assertIn("'osd-"+action+"'",registry)
        self.assertIn('osdControlRequested(osdAction)',shell)

if __name__=='__main__':unittest.main()
