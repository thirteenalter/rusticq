#!/usr/bin/env python3
"""Quick Control scope, settings schema and native-window contracts, offline."""
import json
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]


class QuickControlContracts(unittest.TestCase):
    def test_active_entry_point_and_frameless_surface_guards(self):
        shell=(ROOT/'shell.qml').read_text()
        wrapper=(ROOT/'modules/bar/BarWrapper.qml').read_text()
        style=(ROOT/'config/QuickControlStyle.qml').read_text()
        self.assertIn('BarWrapper {',shell)
        self.assertIn('color: "transparent"',wrapper)
        self.assertIn('color: QuickControlStyle.panelBackground ?',wrapper)
        self.assertIn('border.width: QuickControlStyle.panelOutline ?',wrapper)
        self.assertIn('!frameless && SettingsStore.quickControlPanelBackground',style)
        self.assertIn('!frameless && SettingsStore.quickControlPanelOutline',style)
        for contract in ('HyprlandFocusGrab {','windows: [sideWindow]','focusable: Store.sidebarVisible','SurfaceMotion {'):
            self.assertIn(contract,wrapper)

    def test_transparent_input_mask_and_no_whole_panel_blur(self):
        wrapper=(ROOT/'modules/bar/BarWrapper.qml').read_text()
        bridge=(ROOT/'components/QuickControlInputBridge.qml').read_text()
        style=(ROOT/'config/QuickControlStyle.qml').read_text()
        compositor=(ROOT/'scripts/rusticq-glass.py').read_text()
        self.assertIn('"rusticq-controls-transparent"',wrapper)
        self.assertNotIn('controls-transparent',compositor)
        self.assertIn('QuickControlInputMask',wrapper)
        self.assertIn('parent.clip',style)
        self.assertIn('item.activeFocusOnTab',bridge)
        self.assertNotIn('MouseArea {',bridge)
        self.assertNotIn('Timer {',bridge)

    def test_defaults_example_serialization_and_validation(self):
        store=(ROOT/'config/SettingsStore.qml').read_text()
        block=re.search(r'quickControlDefaults:\s*\(\{(.*?)\}\)',store,re.S)[1]
        normalized=re.sub(r'(\bquickControl\w+)\s*:',r'"\1":',block)
        defaults=json.loads('{'+normalized+'}')
        example=json.loads((ROOT/'user-settings.example.json').read_text())
        self.assertEqual(defaults['quickControlLayout'],'classic')
        self.assertEqual(len(defaults),17)
        for key,value in defaults.items():
            self.assertEqual(example[key],value,key)
            self.assertIn(f'{key}: {key},',store)
        self.assertIn('Number.isFinite(value)',store)
        self.assertIn('root.applyQuickControlSettings(root.quickControlDefaults)',store)
        self.assertIn('function resetQuickControlSettings()',store)

    def test_stable_reorder_and_shared_services(self):
        modular=(ROOT/'modules/quickcontrol/ModularQuickControl.qml').read_text()
        advanced=(ROOT/'modules/bar/BarAdvanced.qml').read_text()
        brightness=(ROOT/'services/BrightnessService.qml').read_text()
        metrics=(ROOT/'modules/quickcontrol/QuickControlSystemMetrics.qml').read_text()
        self.assertIn('model:SettingsStore.defaultQuickOrder',modular)
        self.assertIn('item.mapToItem(content,item.width/2,item.height/2)',modular)
        self.assertIn('Math.pow(x-point.x,2)+Math.pow(y-point.y,2)',modular)
        self.assertIn('SettingsStore.moveQuickCard',modular)
        self.assertIn('BrightnessService.setBrightness',advanced)
        self.assertNotIn('Process {',advanced)
        self.assertNotIn('Process {',modular)
        self.assertNotIn('Process {',metrics)
        self.assertIn('id: read',brightness)
        self.assertIn('id:write',brightness)

    def test_scoped_mixer_and_supported_amplification(self):
        mixer=(ROOT/'components/ApplicationAudioMixer.qml').read_text()
        slider=(ROOT/'components/QuickControlSlider.qml').read_text()
        control=(ROOT/'components/ControlSlider.qml').read_text()
        self.assertIn('property bool framelessQuickControl: false',mixer)
        self.assertIn('visible: !root.framelessQuickControl',mixer)
        self.assertIn('maximumValue: Math.max(1.5,value)',mixer)
        self.assertIn('observedMaximum',slider)
        self.assertIn('Math.max(0, Math.min(1, root.value))',control)
        self.assertNotIn('QuickControlStyle',control)


if __name__=='__main__':
    unittest.main()
