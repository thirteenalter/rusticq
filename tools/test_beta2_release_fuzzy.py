"""Fuzzy ranking smoke tests and deterministic release/patch packaging."""
from pathlib import Path
import importlib.util
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]


def load(path, name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    v=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(v)
    return v

BUILDER=load('tools/build-release.py','rusticq_builder_test')


def qml_function(source, name):
    start=source.index('    function '+name+'(')
    opening=source.index('{',start)
    depth=0
    for i in range(opening,len(source)):
        if source[i]=='{': depth+=1
        if source[i]=='}':
            depth-=1
            if not depth: return source[start:i+1]
    raise ValueError('Malformed function')


class Tests(unittest.TestCase):
    def test_js_score_and_typo_tolerance(self):
        if not shutil.which('node'):
            self.skipTest('Node unavailable; JS source behavior must be checked in QML runtime')
        source=(ROOT/'modules/main/MiniLauncher.qml').read_text()
        impl='\n'.join(qml_function(source,name) for name in ('textOf','editDistance2','searchScore'))
        js='''"use strict";
const assert=require('node:assert/strict');
'''+impl+'''
const firefox={name:"Firefox",genericName:"Web Browser",id:"firefox",comment:"Internet"};
const terminal={name:"Kitty Terminal",genericName:"Terminal Emulator",id:"kitty"};
assert(searchScore(firefox,'firefox')>searchScore(firefox,'fire'));
assert(searchScore(firefox,'fire')>searchScore(firefox,'firfox'));
assert(searchScore(firefox,'firfox')>0);
assert(searchScore(terminal,'terminal')>0);
assert.equal(searchScore(firefox,':ocr'),0);
assert.equal(searchScore(firefox,'=2+2'),0);
assert.equal(searchScore(firefox,'xyzxyz'),0);
console.log('fuzzy ranking verified');
'''
        result=subprocess.run(['node','-e',js], capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)

    def test_reproducible_byte_for_byte_and_delta(self):
        with tempfile.TemporaryDirectory() as folder:
            loc=Path(folder)
            src=loc/'src';src.mkdir()
            (src/'shell.qml').write_text('Item {}\n')
            (src/'README.md').write_text('README\n')
            (src/'user-settings.json').write_text('{"secrets":"do not include"}')
            (src/'.env').write_text('secret token')
            first=BUILDER.build(loc/'a',root=src,label='fixture')
            second=BUILDER.build(loc/'b',root=src,label='fixture')
            self.assertEqual(first['full_sha256'], second['full_sha256'])
            self.assertEqual(first['patch_sha256'],second['patch_sha256'])
            with zipfile.ZipFile(loc/'a/fixture-full.zip') as z:
                self.assertNotIn('quickshell/user-settings.json',z.namelist())
                self.assertNotIn('quickshell/.env',z.namelist())
            (src/'shell.qml').write_text('Item { width: 1 }\n')
            (src/'config').mkdir();(src/'config/theme.qml').write_text('QtObject {}\n')
            updated=BUILDER.build(loc/'c',loc/'a/fixture-full.zip',root=src,label='fixture')
            self.assertEqual(updated['patch_count'],2)
            with zipfile.ZipFile(loc/'c/fixture-patch.zip') as z:
                self.assertEqual(set(z.namelist()),{'quickshell/shell.qml','quickshell/config/theme.qml'})

    def test_package_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder);(p/'shell.qml').write_text('Item {}')
            (p/'outside').symlink_to('/etc/passwd')
            with self.assertRaisesRegex(ValueError,'symlink'):
                BUILDER.sources(p)

if __name__=='__main__': unittest.main()
