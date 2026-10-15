#!/usr/bin/env python3
"""Offline service-contract tests. Never change actual desktop modes."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("quick_modes", Path(__file__).resolve().parents[1] / "scripts/quick_modes.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ModesTests(unittest.TestCase):
    def setUp(self):
        self.dnd = False
        self.temp = 6500
        self.writes = []
        self.respond_to_writes = True
        self.run_patch = patch.object(mod, "run", side_effect=self.run_command)
        self.which_patch = patch.object(mod.shutil, "which", return_value="/test/bin/tool")
        self.run_patch.start()
        self.which_patch.start()
        self.addCleanup(self.run_patch.stop)
        self.addCleanup(self.which_patch.stop)

    def run_command(self, args, timeout=5):
        if args[:3] == ["omarchy", "shell", "notifications"]:
            if args[3] == "setDnd":
                self.writes.append(args)
                if self.respond_to_writes:
                    self.dnd = args[4] == "on"
            return "on" if self.dnd else "off"
        if args == ["omarchy", "toggle", "nightlight"]:
            self.writes.append(args)
            self.temp = 4000
            return ""
        if args[:3] == ["hyprctl", "hyprsunset", "temperature"]:
            if self.temp is None:
                raise RuntimeError("hyprsunset not running")
            if len(args) == 4:
                self.writes.append(args)
                if self.respond_to_writes:
                    self.temp = int(args[3])
            return str(self.temp)
        raise AssertionError(f"Unexpected command: {args}")

    def test_probes_are_read_only(self):
        for key in ("silent", "night"):
            self.assertTrue(mod.probe(key)["available"])
            self.assertFalse(mod.probe(key)["active"])
        self.assertEqual(self.writes, [])

    def test_silent_round_trip_and_idempotent_set(self):
        mod.set_mode("silent", True)
        self.assertTrue(mod.probe("silent")["active"])
        mod.set_mode("silent", True)
        self.assertEqual(len(self.writes), 1)
        mod.set_mode("silent", False)
        self.assertFalse(mod.probe("silent")["active"])

    def test_night_round_trip(self):
        mod.set_mode("night", True)
        self.assertEqual(self.temp, 4000)
        mod.set_mode("night", False)
        self.assertEqual(self.temp, 6500)

    def test_night_start_is_explicit(self):
        self.temp = None
        self.assertTrue(mod.probe("night")["available"])
        self.assertEqual(self.writes, [])
        mod.set_mode("night", True)
        self.assertEqual(self.temp, 4000)

    def test_failed_apply_is_not_reported_as_success(self):
        self.respond_to_writes = False
        for key in ("silent", "night"):
            with self.assertRaises(RuntimeError):
                mod.set_mode(key, True)

    def test_missing_service_timeout_and_invalid_response(self):
        for failure in (FileNotFoundError("missing"), subprocess.TimeoutExpired("test", 5)):
            with patch.object(mod, "run", side_effect=failure):
                state = mod.probe("silent")
                self.assertFalse(state["available"])
                self.assertTrue(state["detail"])
        with patch.object(mod, "run", return_value="Target not found."):
            self.assertFalse(mod.probe("silent")["available"])

    def test_no_night_backend(self):
        with patch.object(mod.shutil, "which", return_value=None):
            self.assertFalse(mod.probe("night")["available"])
            with self.assertRaises(RuntimeError):
                mod.set_mode("night", True)
        self.assertEqual(self.writes, [])

    def test_rejects_unknown_mode_and_non_boolean(self):
        for key, value in (("silent; shutdown now", True), ("night", "on")):
            with self.assertRaises(ValueError):
                mod.set_mode(key, value)
        self.assertEqual(self.writes, [])


if __name__ == "__main__":
    unittest.main()
