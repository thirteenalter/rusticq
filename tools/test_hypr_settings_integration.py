#!/usr/bin/env python3
"""Launch/installation contracts, without opening a desktop or writing user dirs."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('hypr_settings_cli',ROOT/'scripts/rusticq-cli.py')
cli=importlib.util.module_from_spec(spec);spec.loader.exec_module(cli)


class Integration(unittest.TestCase):
    def test_cli_uses_existing_ipc_dispatcher(self):
        with patch.object(cli,'ipc_action',return_value={'action':'hypr-settings'}) as action:
            self.assertEqual(cli.main(['hypr-settings']),0)
            action.assert_called_once_with('hypr-settings')

    def test_action_catalogue_can_assign_shortcut(self):
        result=subprocess.run(['python3',str(ROOT/'scripts/rustiq-desktop-integration.py'),'actions'],capture_output=True,text=True,check=True)
        actions=json.loads(result.stdout)['actions']
        self.assertTrue(any(a['key']=='hypr-settings' for a in actions))

    def test_desktop_entry_is_valid(self):
        path=ROOT/'desktop/org.rusticq.HyprlandSettings.desktop'
        if shutil.which('desktop-file-validate'):
            subprocess.run(['desktop-file-validate',str(path)],check=True)
        self.assertIn('Exec=rusticq hypr-settings',path.read_text())
        self.assertTrue((ROOT/'assets/rusticq-hypr-settings.svg').is_file())

    def test_install_dry_run_creates_nothing(self):
        with tempfile.TemporaryDirectory() as folder:
            home=Path(folder)
            env=dict(os.environ,HOME=folder,XDG_DATA_HOME=str(home/'data'),XDG_STATE_HOME=str(home/'state'))
            result=subprocess.run(['bash',str(ROOT/'scripts/install.sh'),'--dry-run','--skip-deps'],env=env,capture_output=True,text=True,check=True)
            self.assertIn('DRY RUN',result.stdout)
            self.assertEqual(list(home.iterdir()),[])


if __name__=='__main__': unittest.main(verbosity=2)
