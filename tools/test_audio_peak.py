#!/usr/bin/env python3
"""Offline PCM peak and error handling tests; no audio device access."""
from array import array
import importlib.util
import math
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('audio_peak', ROOT / 'scripts/rusticq-audio-peak.py')
PEAK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PEAK)


class AudioPeakTests(unittest.TestCase):
    def test_silence_and_negative_samples(self):
        self.assertEqual(PEAK.sample_peak(array('f', [0, 0]).tobytes()), 0)
        self.assertAlmostEqual(PEAK.sample_peak(array('f', [-0.125, 0.02]).tobytes()), 0.5)

    def test_clip_and_nonfinite_samples(self):
        self.assertEqual(PEAK.sample_peak(array('f', [2, -3]).tobytes()), 1)
        self.assertEqual(PEAK.sample_peak(array('f', [math.nan, math.inf, -math.inf]).tobytes()), 0)

    def test_invalid_target_and_missing_tool_never_spawn(self):
        with patch.object(PEAK.shutil, 'which', return_value=None), patch.object(PEAK.subprocess, 'Popen') as spawn:
            for target in ('', 'node\nname', 'spotify'):
                with self.assertRaises(ValueError): PEAK.monitor(target)
            spawn.assert_not_called()


if __name__ == '__main__':
    unittest.main()
