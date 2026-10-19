"""Tests: safe launcher providers, search privacy and dimensional conversion."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(path,name):
    spec=importlib.util.spec_from_file_location(name, ROOT/'scripts'/path)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

TOOLS=load('rusticq-launcher-tools.py','rusticq_tools_test')
CALC=load('rusticq-calc.py','rusticq_unit_calc')
DOCTOR=load('rusticq-doctor.py','rusticq_doctor_ext')

class Providers(unittest.TestCase):
    def test_emoji_search_and_settings_tabs(self):
        self.assertEqual(TOOLS.search('emoji','cat')[0]['payload'],'🐱')
        self.assertEqual(TOOLS.search('settings','display')[0]['payload'],'display')
        self.assertTrue(all(row['action']=='settings' for row in TOOLS.search('settings','')))
        self.assertLessEqual(len(TOOLS.search('emoji','')),48)
        for mode in ('emoji','settings','wallpaper','color','ocr'):
            self.assertIsInstance(TOOLS.search(mode,'') if mode != 'wallpaper' else TOOLS.search(mode,'',Path('/tmp/empty-home')),list)
        with self.assertRaisesRegex(ValueError,'Unknown'):
            TOOLS.search('command', '')
        with self.assertRaisesRegex(ValueError,'long'):
            TOOLS.search('emoji','a'*1000)

    def test_wallpaper_only_scans_private_local_images(self):
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory)/'home'; home.mkdir()
            image=home/'Pictures'/'Wallpapers'; image.mkdir(parents=True)
            allowed=image/'starry-night.png'; allowed.write_bytes(b'PNG TEST FIXTURE')
            outside=Path(directory)/'secret.png'; outside.write_bytes(b'external')
            (image/'outside.png').symlink_to(outside)
            (image/'not-wallpaper.sh').write_text('echo dangerous')
            items=TOOLS.wallpapers('starry',home)
            self.assertEqual(len(items),1)
            self.assertEqual(items[0]['payload'],str(allowed))
            self.assertEqual(TOOLS.wallpapers('outside',home),[])

    def test_emoji_clipboard_requires_explicit_selection(self):
        with patch.object(TOOLS,'clipboard') as clip:
            self.assertIn('Copied',TOOLS.execute('emoji','🐱'))
            clip.assert_called_once_with('🐱')
            with self.assertRaisesRegex(ValueError,'catalogue'):
                TOOLS.execute('emoji','; rm -rf ~/.config')
            self.assertEqual(clip.call_count,1)

    def test_color_hex_rgb_hsl_not_arbitrary_command(self):
        with self.assertRaisesRegex(ValueError,'Invalid color'):
            TOOLS.execute('color','bash')
        with patch.object(TOOLS.shutil,'which', return_value='/usr/bin/hyprpicker'), \
             patch.object(TOOLS,'call',side_effect=[b'#A1B2C3\n',b'']) as subprocess_call:
            message=TOOLS.execute('color','pick')
            self.assertIn('#A1B2C3',message)
            self.assertEqual(subprocess_call.call_args_list[0].args[0],['hyprpicker','-f','hex'])

    def test_ocr_is_only_on_explicit_selection_local_and_safe(self):
        with self.assertRaisesRegex(ValueError,'Invalid OCR'):
            TOOLS.execute('ocr','upload')
        with patch.object(TOOLS.shutil,'which', return_value='/usr/bin/tool'), \
             patch.object(TOOLS,'call',side_effect=[b'10,20 100x150',b'PNG test',b'hello text',b'']) as proc:
            self.assertIn('10 OCR characters', TOOLS.execute('ocr','region'))
            self.assertEqual(proc.call_args_list[0].args[0],['slurp'])
            self.assertEqual(proc.call_args_list[1].args[0],['grim','-g','10,20 100x150','-'])
            self.assertEqual(proc.call_args_list[2].args[0],['tesseract','stdin','stdout'])

    def test_execute_wallpaper_refuses_outside_home(self):
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory)/'home';home.mkdir()
            outside=Path(directory)/'evil.png';outside.write_bytes(b'foo')
            with patch.object(TOOLS.Path,'home', return_value=home):
                with self.assertRaisesRegex(ValueError,'home directory'):
                    TOOLS.execute('wallpaper',str(outside))

    def test_units_and_scientific_still_work(self):
        for expr,expected in [('5 km to m','5000 m'),('1 mi to ft','5280 ft'),
                              ('100 c to f','212 f'),('32 f to c','0 c'),
                              ('1 hr to min','60 min'),('1 kg to g','1000 g'),
                              ('sqrt(144)+8','20')]:
            self.assertEqual(CALC.evaluate(expr),expected)
        for expr in ('1 m to kg','-400 c to k','1 billion to USD'):
            with self.subTest(expr=expr), self.assertRaises(ValueError):
                CALC.evaluate(expr)

    def test_launcher_reuses_existing_ux(self):
        qml=(ROOT/'modules/main/MiniLauncher.qml').read_text()
        for name in ('toolsMode','toolList','toolSearchProcess','toolRunProcess','selectedIndex',
                     'Keys.onDownPressed','Keys.onUpPressed','Keys.onReturnPressed',
                     'Quickshell.execDetached','Store.showSettings('):
            self.assertIn(name,qml)
        self.assertIn('execute-later',qml)
        self.assertIn('launched();',qml)

    def test_doctor_checks_optional_capabilities_without_running_them(self):
        with patch.object(DOCTOR.shutil,'which', return_value=None):
            with tempfile.TemporaryDirectory() as directory:
                result=DOCTOR.doctor(directory)
        ids={i['id'] for i in result['checks']}
        self.assertIn('launcher.ocr',ids)
        self.assertIn('launcher.color',ids)

if __name__ == '__main__': unittest.main()
