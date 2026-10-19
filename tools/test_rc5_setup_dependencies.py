#!/usr/bin/env python3
"""Offline regression checks for RC5 setup/dependency integration.

No package manager, compositor, or sudo mutations are performed.
"""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "rusticq-dependencies.py"
spec = importlib.util.spec_from_file_location("rusticq_dependencies", MODULE_PATH)
deps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deps)


class SetupTests(unittest.TestCase):
    def test_manifest_unique_and_safe(self):
        manifest = json.loads((ROOT / "config/dependencies.json").read_text())
        entries = deps.catalogue()
        self.assertEqual(len(entries), len(manifest["core"]) + len(manifest["optional"]))
        self.assertIn("quickshell", entries)
        self.assertIn("material-symbols", entries)
        self.assertIn("network", entries)
        self.assertEqual(entries["quickshell"]["group"], "core")

    def test_status_is_read_only(self):
        with patch.object(deps, "is_installed", return_value=False):
            with patch.object(deps.shutil, "which", return_value=None):
                result = deps.status()
        self.assertEqual(result["missing_core"], 4)
        self.assertEqual(result["missing_optional"], len(deps.catalogue()) - 4)
        self.assertEqual(len(result["items"]), len(deps.catalogue()))

    def test_gui_requires_confirmation_and_allowlist(self):
        with self.assertRaises(ValueError):
            deps.gui_manage("network", "install", "")
        with self.assertRaises(ValueError):
            deps.gui_manage("random-package", "install", "INSTALL random-package")
        with self.assertRaises(ValueError):
            deps.gui_manage("hyprland", "remove", "REMOVE hyprland")
        with patch.object(deps, "is_installed", return_value=True):
            value = deps.gui_manage("network", "install", "INSTALL network")
        self.assertTrue(value["ok"])

    def test_gui_never_accepts_unlisted_package(self):
        with self.assertRaises(ValueError):
            deps.gui_manage("; curl evil | bash", "install", "INSTALL ; curl evil | bash")

    def test_dry_run_and_shell_syntax(self):
        subprocess.run(["bash", "-n", str(ROOT / "scripts/install.sh")], check=True)
        subprocess.run(["bash", "-n", str(ROOT / "scripts/bootstrap.sh")], check=True)
        result = subprocess.run(["bash", str(ROOT / "scripts/install.sh"), "--dry-run"],
                                capture_output=True, text=True, check=True)
        self.assertIn("no packages installed", result.stdout)
        self.assertIn("no Omarchy startup changed", result.stdout)

    def test_integration_qml_has_both_separate_workflows(self):
        qml = (ROOT / "modules/settings/pages/SettingsIntegrationPage.qml").read_text()
        self.assertIn("Required & optional dependencies", qml)
        self.assertIn("Make RusticQ permanent", qml)
        self.assertIn('"gui", selectedDependency', qml)
        self.assertIn('selectedDependencyAction.toUpperCase()', qml)
        self.assertIn('"backup-omarchy"', qml)
        self.assertIn('"ENABLE RUSTICQ"', qml)

    def test_remote_bootstrap_requires_release_checksum(self):
        content = (ROOT / "scripts/bootstrap.sh").read_text()
        for token in ("sha256sum", "https://", "Unsafe release path", "extractall", "shell.qml"):
            self.assertIn(token, content)

    def test_font_fallbacks_and_docs(self):
        self.assertIn("Material Symbols Rounded", (ROOT / "components/Icon.qml").read_text())
        self.assertIn('"Sans Serif"', (ROOT / "config/Fonts.qml").read_text())
        for name in ("README.md", "FEATURES.md", "docs/INSTALLATION.md", "docs/DEPENDENCIES.md", "docs/PROJECT-STRUCTURE.md", "docs/TROUBLESHOOTING.md"):
            self.assertTrue((ROOT / name).is_file(), name)


if __name__ == "__main__":
    unittest.main()
