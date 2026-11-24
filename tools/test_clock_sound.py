#!/usr/bin/env python3
"""Clock sound generation, stream gain and process/loop cleanup without audio devices."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import wave

HELPER = Path(__file__).resolve().parents[1] / 'scripts/rusticq-clock-sound.py'
spec = importlib.util.spec_from_file_location('clock_sound', HELPER)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class SoundTests(unittest.TestCase):
    def test_distinct_valid_wav_presets(self):
        with tempfile.TemporaryDirectory() as folder:
            data = []
            for sound in ('chime', 'bell', 'digital'):
                path = Path(folder) / (sound + '.wav')
                mod.write_chime(path, sound)
                with wave.open(str(path)) as audio:
                    self.assertEqual((audio.getnchannels(), audio.getsampwidth(), audio.getframerate()), (1, 2, 24000))
                    self.assertEqual(audio.getnframes(), 48000)
                    data.append(audio.readframes(48000))
            self.assertEqual(len(set(data)), 3)

    def test_gain_is_per_stream_and_caps_at_125(self):
        with patch.object(mod.shutil, 'which', side_effect=lambda name: '/bin/' + name):
            commands = mod.player_commands('/tmp/a sound.wav', 125)
        self.assertIn('1.25', commands[0])
        self.assertIn('--volume=81920', commands[1])
        self.assertEqual(commands[0][-1], '/tmp/a sound.wav')
        self.assertIn('state.restore-props = false', commands[0][-2])
        for value in (-1, 126, 200, True, 125.5):
            with self.assertRaises(ValueError):
                mod.player_commands('tone.wav', value)

    def test_missing_file_and_missing_backend_are_clear(self):
        with self.assertRaisesRegex(RuntimeError, 'file is unavailable'):
            mod.play('custom', 100, False, '/tmp/nonexistent-rusticq-tone.wav')
        with patch.object(mod.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(RuntimeError, 'pw-play or paplay'):
                mod.play('chime', 100, False)
        with patch.object(mod.subprocess, 'run') as run:
            mod.play('chime', 0, True)
            run.assert_not_called()

    def test_loop_stop_custom_file_and_no_orphan_player(self):
        with tempfile.TemporaryDirectory(prefix='rusticq-sound-test-') as folder:
            root = Path(folder)
            player = root / 'pw-play'
            player.write_text('''#!/usr/bin/python3
import json, os, sys, time
from pathlib import Path
with Path(os.environ['SOUND_TEST_LOG']).open('a') as f:
    f.write(json.dumps({'pid':os.getpid(),'args':sys.argv[1:]})+'\\n')
time.sleep(.12)
''')
            player.chmod(0o755)
            log = root / 'events.jsonl'
            env = dict(os.environ, PATH=folder, SOUND_TEST_LOG=str(log))
            process = subprocess.Popen([sys.executable, str(HELPER), 'timer', '--loop', '--volume', '125'], env=env)
            try:
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    lines = log.read_text().splitlines() if log.exists() else []
                    if len(lines) >= 3:
                        break
                    time.sleep(.025)
                self.assertGreaterEqual(len(lines), 3, 'loop repeated')
            finally:
                process.terminate()
                self.assertEqual(process.wait(timeout=3), 0)
            for entry in map(json.loads, log.read_text().splitlines()):
                self.assertIn('1.25', entry['args'])
                with self.assertRaises(ProcessLookupError):
                    os.kill(entry['pid'], 0)
            custom = root / 'My sound ; quoted.wav'
            mod.write_chime(custom, 'bell')
            before = len(log.read_text().splitlines())
            once = subprocess.run([sys.executable, str(HELPER), 'alarm', '--sound', 'custom', '--file', str(custom), '--volume', '90'],
                                  env=env, capture_output=True, text=True, timeout=5)
            self.assertEqual(once.returncode, 0, once.stdout)
            entries = list(map(json.loads, log.read_text().splitlines()))
            self.assertEqual(len(entries), before + 1, 'play once')
            self.assertEqual(entries[-1]['args'][-1], str(custom))
            invalid = subprocess.run([sys.executable, str(HELPER), 'timer', '--volume', '126'], env=env,
                                     capture_output=True, text=True, timeout=5)
            self.assertEqual(invalid.returncode, 2)
            self.assertIn('125', invalid.stderr)


if __name__ == '__main__':
    unittest.main()
