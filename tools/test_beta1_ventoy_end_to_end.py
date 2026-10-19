#!/usr/bin/env python3
"""Run GUI's actual `search-source` command against a simulated yay binary.

No pacman/yay/flatpak network access and no installation/removal.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / 'scripts' / 'rustiq-package-manager.py'

YAY = '''aur/iventoy-bin 1.0.45-1 (+6 0.01) [5d2h]
    An enhanced version of the PXE server
aur/ventoy-bin 1.1.18-1 (+464 6.31) [8018h]
    A new bootable USB solution
'''

class EndToEndSearch(unittest.TestCase):
    def test_gui_backend_yay_same_as_terminal(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            executable = directory / 'yay'
            executable.write_text('''#!/usr/bin/env python3
import sys
if sys.argv[1:] != ['-Ss','ventoy-bin']:
    print('Unexpected flags: ' + repr(sys.argv[1:]), file=sys.stderr)
    sys.exit(8)
print(''' + repr(YAY) + ''')
''')
            executable.chmod(0o755)
            env = dict(os.environ, PATH=str(directory) + os.pathsep + os.environ.get('PATH',''))
            output = subprocess.run([sys.executable, str(PKG), 'search-source', 'yay', 'ventoy-bin'],
                                    text=True, capture_output=True, env=env, timeout=8)
            self.assertEqual(output.returncode, 0, output.stderr + output.stdout)
            data = json.loads(output.stdout)
            self.assertEqual(data['query'], 'ventoy-bin')
            self.assertEqual(data['source'], 'yay')
            self.assertEqual(data['errors'], [])
            self.assertEqual([item['name'] for item in data['results']], ['iventoy-bin', 'ventoy-bin'])
            self.assertTrue(all(item['source']=='yay' for item in data['results']))

    def test_power_border_and_close_control(self):
        qml = (ROOT/'modules/power/PowerMenu.qml').read_text()
        self.assertIn('PanelWindow {',qml)
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay',qml)
        self.assertIn('radius: Theme.sectionRadius',qml)
        self.assertIn('border.color: Theme.borderaccent',qml)
        self.assertIn('border.width: 1',qml)
        self.assertNotIn('text: "×"',qml)
        self.assertIn('Qt.Key_Escape',qml)

if __name__ == '__main__':
    unittest.main()
