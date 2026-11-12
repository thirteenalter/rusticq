#!/usr/bin/env python3
"""Manifest validation, history ordering and release packaging; fully offline."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def load(relative, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


RELEASE = load('scripts/rusticq-release.py', 'rusticq_manifest_test')
BUILDER = load('tools/build-release.py', 'rusticq_manifest_builder_test')


class ReleaseManifests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='rusticq-versioning-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'source'
        self.root.mkdir()
        shutil.copytree(ROOT / 'config/releases', self.root / 'config/releases')
        shutil.copytree(ROOT / 'changelog', self.root / 'changelog')
        shutil.copytree(ROOT / 'docs', self.root / 'docs')
        (self.root / 'VERSION').write_text('beta-4\n')
        (self.root / 'shell.qml').write_text('ShellRoot {}\n')

    def write_manifest(self, tag, data):
        path = self.root / 'config/releases' / (tag + '.json')
        path.write_text(json.dumps(data), encoding='utf-8')

    def test_active_beta4_and_all_documented_versions(self):
        catalog = RELEASE.release_catalog(ROOT)
        current = catalog['current']
        self.assertEqual(current['tag'], 'beta-4')
        self.assertEqual(current['name'], 'Beta 4')
        self.assertEqual(current['date'], '2026-11-13')
        self.assertEqual(current['minimumQuickshell'], '0.3.1')
        self.assertEqual(current['manifest'], 'config/releases/beta-4.json')
        self.assertEqual(catalog['warnings'], [])
        self.assertEqual(len(catalog['releases']), 16)
        self.assertEqual(len({release['tag'] for release in catalog['releases']}), 16)
        self.assertNotIn('beta-2', [release['tag'] for release in catalog['releases']])

    def test_history_numeric_order_and_candidates_before_previous_alpha(self):
        tags = [release['tag'] for release in RELEASE.release_catalog(self.root)['releases']]
        self.assertEqual(tags[:4], ['beta-4', 'beta-3', 'beta-1', 'alpha-4'])
        self.assertLess(tags.index('alpha-4-rc5'), tags.index('alpha-4-rc4'))
        self.assertLess(tags.index('rustiq-alpha-3'), tags.index('rustiq-alpha-3-rc-4'))
        self.assertEqual(tags[-1], 'rustiq-alpha-1')

    def test_version_pointer_selects_a_historical_manifest(self):
        (self.root / 'VERSION').write_text('rustiq-alpha-3-rc-2\n')
        release = RELEASE.current_release(self.root)
        self.assertEqual(release['name'], 'Alpha 3 RC2')
        self.assertEqual(release['channel'], 'alpha')
        self.assertEqual(release['candidate'], 2)
        self.assertIsNone(release['date'])
        self.assertEqual(RELEASE.release_catalog(self.root)['current'], release)

    def test_invalid_history_is_skipped_without_losing_current_release(self):
        (self.root / 'config/releases/beta-3.json').write_text('{broken')
        result = RELEASE.release_catalog(self.root)
        self.assertEqual(result['current']['tag'], 'beta-4')
        self.assertEqual(len(result['warnings']), 1)
        self.assertIn('beta-3.json', result['warnings'][0])
        self.assertNotIn('beta-3', [entry['tag'] for entry in result['releases']])

    def test_missing_current_manifest_fails_instead_of_guessing(self):
        (self.root / 'config/releases/beta-4.json').unlink()
        with self.assertRaises(FileNotFoundError):
            RELEASE.release_catalog(self.root)

    def test_invalid_current_fields_are_rejected(self):
        original = json.loads((self.root / 'config/releases/beta-4.json').read_text())
        for field, value in [('schemaVersion', 2), ('schemaVersion', True), ('tag', 'beta-3'),
                             ('name', 'Beta 3'), ('date', '2026-02-30'), ('date', []),
                             ('minimumQuickshell', 'latest'), ('summary', ''),
                             ('changes', []), ('changes', ['ok', None]),
                             ('notes', ['../../etc/passwd']), ('notes', ['/etc/passwd']),
                             ('notes', ['docs/missing.md'])]:
            with self.subTest(field=field, value=value):
                bad = copy.deepcopy(original)
                bad[field] = value
                self.write_manifest('beta-4', bad)
                with self.assertRaises(ValueError):
                    RELEASE.current_release(self.root)

    def test_invalid_version_pointers_are_rejected(self):
        for tag in ('', '../beta-4', 'beta-4/../../', 'beta-four', 'beta-0', 'beta-4\ntrailing'):
            with self.subTest(tag=tag):
                (self.root / 'VERSION').write_text(tag)
                with self.assertRaises(ValueError):
                    RELEASE.current_release(self.root)

    def test_default_build_label_and_checksum_manifest_use_active_metadata(self):
        out = Path(self.temp.name) / 'dist'
        result = BUILDER.build(out, root=self.root)
        self.assertEqual(result['label'], 'rusticq-beta-4')
        self.assertEqual(result['release'], RELEASE.current_release(self.root))
        saved = json.loads((out / 'rusticq-beta-4-manifest.json').read_text())
        self.assertEqual(result, saved)
        with zipfile.ZipFile(out / 'rusticq-beta-4-full.zip') as archive:
            self.assertEqual(archive.read('quickshell/VERSION').decode().strip(), result['release']['tag'])
            self.assertEqual(json.loads(archive.read('quickshell/config/releases/beta-4.json'))['name'], result['release']['name'])

    def test_explicit_build_label_preserves_release_identity(self):
        result = BUILDER.build(Path(self.temp.name) / 'custom', root=self.root, label='ci-validation')
        self.assertEqual(result['label'], 'ci-validation')
        self.assertEqual(result['release']['tag'], 'beta-4')

    def test_unsafe_build_label_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'archive label'):
            BUILDER.build(Path(self.temp.name) / 'dist', root=self.root, label='../outside')

    def test_local_credentials_and_agent_files_are_excluded_from_archives(self):
        for relative in ('.aws/credentials', '.codex/auth.json', '.agents/local.md'):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('private fixture: must not be packaged')
        entries = BUILDER.sources(self.root)
        self.assertTrue(entries)
        for name, data in entries.items():
            self.assertNotIn('private fixture', data.decode('utf-8', errors='replace'), name)
            self.assertFalse(any(part in {'.aws', '.codex', '.agents'} for part in Path(name).parts), name)


if __name__ == '__main__':
    unittest.main()
