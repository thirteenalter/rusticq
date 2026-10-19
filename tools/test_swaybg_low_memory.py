#!/usr/bin/env python3
"""Offline swaybg backend and memory target contracts (no Wayland process started)."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
WALL=ROOT/'scripts/rusticq-wallpaper.py'
MEM=ROOT/'scripts/rusticq-idle-memory.py'


def load_module(path, name):
    spec=importlib.util.spec_from_file_location(name,path)
    obj=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


class SwaybgCompatibility(unittest.TestCase):
    def setUp(self):
        self.mod=load_module(WALL, 'wallpaper_backend_unit_test')
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder=Path(self.tmp.name)
        self.file=self.folder/'wall.png'
        self.file.write_bytes(b'fake wallpaper for mocked process')

    def test_duplicate_apply_reuses_managed_swaybg(self):
        m=self.mod
        image=str(self.file)
        m.write_state(self.folder,dict(backend='swaybg',pid=5001,start='123',image=image,mode='fill',output='*'))
        with patch.object(m,'runtime_dir',return_value=self.folder), \
             patch.object(m,'is_our_swaybg',return_value=True), \
             patch.object(m,'live_wallpaper_processes',return_value=[{'pid':5001,'name':'swaybg'}]), \
             patch.object(m.shutil,'which',return_value='/usr/bin/swaybg'), \
             patch.object(m.subprocess,'Popen') as process, \
             patch.dict(os.environ,{'WAYLAND_DISPLAY':'wayland-1'}):
            result=m.apply_swaybg(self.file)
        self.assertTrue(result['reused'])
        self.assertEqual(result['pid'],5001)
        process.assert_not_called()

    def test_other_wallpaper_process_blocks_without_explicit_permission(self):
        m=self.mod
        with patch.object(m,'runtime_dir',return_value=self.folder), \
             patch.object(m,'live_wallpaper_processes',return_value=[{'pid':9001,'name':'hyprpaper'}]), \
             patch.object(m.shutil,'which',return_value='/usr/bin/swaybg'), \
             patch.object(m.subprocess,'Popen') as process, \
             patch.dict(os.environ,{'WAYLAND_DISPLAY':'wayland-1'}):
            with self.assertRaisesRegex(RuntimeError,'Another wallpaper backend'):
                m.apply_swaybg(self.file)
        process.assert_not_called()

    def test_single_managed_process_started_and_old_managed_one_retired(self):
        m=self.mod
        m.write_state(self.folder,dict(backend='swaybg',pid=5001,start='123',image='old.png',mode='fill',output='*'))
        class FakeProcess:
            pid=5002
            def poll(self): return None
        with patch.object(m,'runtime_dir',return_value=self.folder), \
             patch.object(m,'live_wallpaper_processes',return_value=[{'pid':5001,'name':'swaybg'}]), \
             patch.object(m,'is_our_swaybg',side_effect=lambda pid,start:pid==5001), \
             patch.object(m,'stop_owned',return_value=True) as stop, \
             patch.object(m,'proc_start',return_value='456'), \
             patch.object(m.shutil,'which',return_value='/usr/bin/swaybg'), \
             patch.object(m.subprocess,'Popen',return_value=FakeProcess()) as launch, \
             patch.object(m.time,'sleep'), \
             patch.dict(os.environ,{'WAYLAND_DISPLAY':'wayland-1'}):
            data=m.apply_swaybg(self.file,mode='fit')
        self.assertEqual(data['pid'],5002)
        self.assertEqual(m.read_state(self.folder)['mode'],'fit')
        self.assertEqual(m.read_state(self.folder)['start'],'456')
        stop.assert_called_once_with(5001,'123')
        self.assertEqual(launch.call_args.args[0],['swaybg','-o','*','-i',str(self.file),'-m','fit'])

    def test_invalid_output_and_wrong_session_fail(self):
        m=self.mod
        with patch.object(m.shutil,'which',return_value='/usr/bin/swaybg'):
            with patch.dict(os.environ,{'WAYLAND_DISPLAY':'wayland-1'}):
                with self.assertRaisesRegex(ValueError,'Invalid output name'):
                    m.apply_swaybg(self.file,output='; rm -rf ~')
        with patch.object(m.shutil,'which',return_value='/usr/bin/swaybg'):
            with patch.dict(os.environ,{'WAYLAND_DISPLAY':''}):
                with self.assertRaisesRegex(RuntimeError,'Wayland session'):
                    m.apply_swaybg(self.file)

    def test_status_reports_installed_and_managed_without_mutation(self):
        m=self.mod
        with patch.object(m,'runtime_dir',return_value=self.folder), \
             patch.object(m,'live_wallpaper_processes',return_value=[]), \
             patch.object(m.shutil,'which',return_value='/usr/bin/swaybg'):
            st=m.status()
        self.assertTrue(st['ok'])
        self.assertFalse(st['managed_active'])
        self.assertTrue(st['installed']['swaybg'])
        self.assertFalse((self.folder/'managed.json').exists())

    def test_gui_selectors_and_optional_dependency_are_connected(self):
        store=(ROOT/'config/SettingsStore.qml').read_text()
        ui=(ROOT/'modules/settings/pages/SettingsAppearancePage.qml').read_text()
        shell=(ROOT/'shell.qml').read_text()
        deps=json.loads((ROOT/'config/dependencies.json').read_text())
        self.assertIn('property string wallpaperBackend: "swaybg"',store)
        self.assertIn('property bool wallpaperAutoRestore',store)
        self.assertIn('wallpaperReplaceOnRestore: wallpaperReplaceOnRestore',store)
        self.assertIn('model: ["swaybg", "hyprpaper", "awww", "swww", "auto"]',ui)
        self.assertIn('sourceSize: Qt.size(720, 280)',ui)
        self.assertIn('SettingsStore.wallpaperFitMode',ui)
        self.assertIn('"--replace-conflicts"',ui)
        self.assertIn('wallpaperStartup.exec(args)',shell)
        self.assertIn('!SettingsStore.lowMemoryShellMode || Store.aiVisible',shell)
        self.assertIn('lowMemoryShellMode: lowMemoryShellMode',store)
        self.assertIn('Low Memory Shell Mode',(ROOT/'modules/settings/pages/SettingsModulesPage.qml').read_text())
        self.assertIn('SettingsStore.wallpaperAutoRestore',shell)
        self.assertTrue(any(e.get('package')=='swaybg' for e in deps['optional']))


class MemoryReportTests(unittest.TestCase):
    def setUp(self): self.mod=load_module(MEM,'wallpaper_memory_test')

    def test_free_used_estimator_and_target_cutoff(self):
        mem={'MemTotal':7340032,'MemFree':2306867,'Buffers':50000,'Cached':2350000,
             'KReclaimable':980000,'Shmem':29000,'MemAvailable':5242880}
        # Ensures calculation is not the same as MemTotal-MemAvailable.
        result=self.mod.free_used_kib(mem)
        expected=max(0,mem['MemTotal']-mem['MemFree']-(mem['Buffers']+mem['Cached']+mem['KReclaimable']-mem['Shmem']))
        self.assertEqual(result,expected)
        self.assertNotEqual(result,mem['MemTotal']-mem['MemAvailable'])

    def test_baseline_save_then_compare(self):
        m=self.mod
        with tempfile.TemporaryDirectory() as d, patch.dict(os.environ,{'XDG_STATE_HOME':d}):
            saved=m.compare_baseline({'system_used_mib':2120.0}, save=True)
            self.assertTrue(saved['baseline_saved'])
            compared=m.compare_baseline({'system_used_mib':2010.0})
            self.assertEqual(compared['change_from_baseline_mib'],-110.0)
            self.assertEqual((Path(d)/'rusticq/wallpaper-memory-baseline.json').stat().st_mode & 0o777, 0o600)


if __name__=='__main__':unittest.main()
