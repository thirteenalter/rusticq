#!/usr/bin/env python3
"""Offline adapter tests with structured CLI fixtures and real child processes."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("speedtest_adapter", ROOT / "scripts/rusticq-speedtest.py")
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)

RESULT = {"type":"result", "ping":{"latency":12.5}, "download":{"bandwidth":12500000},
          "upload":{"bandwidth":2500000}, "interface":{"externalIp":"PRIVATE"}}


class AdapterTests(unittest.TestCase):
    def fake_cli(self, folder, body):
        path = Path(folder) / "speedtest"
        path.write_text(f"#!{sys.executable}\n" + body)
        path.chmod(0o700)
        return str(path)

    def test_units_and_private_fields(self):
        result = adapter.parse_event(RESULT, "ookla")
        self.assertEqual((result["pingMs"], result["downloadMbps"], result["uploadMbps"]), (12.5, 100, 20))
        self.assertNotIn("PRIVATE", json.dumps(result))
        self.assertEqual(adapter.parse_event({"ping":12.5,"download":100e6,"upload":20e6}, "sivel"), result)
        event = adapter.parse_event({"type":"download","download":{"bandwidth":31250000,"progress":.5}}, "ookla")
        self.assertEqual(event, {"phase":"download","downloadMbps":250,"progress":.325})

    def test_invalid_or_incomplete_measurements(self):
        for bad in (-1, True, None, "25", float("nan"), float("inf")):
            with self.assertRaises(adapter.TestError):
                adapter.parse_event({"ping":bad,"download":0,"upload":0}, "sivel")
        with self.assertRaises(adapter.TestError):
            adapter.parse_event({"type":"result", "download":{}}, "ookla")

    def test_no_backend_and_no_test_traffic_during_probe(self):
        with patch.object(adapter.shutil, "which", return_value=None):
            self.assertIsNone(adapter.detect_backend())
        with tempfile.TemporaryDirectory() as folder:
            executable = self.fake_cli(folder, 'import sys\nprint("Speedtest by Ookla")\nassert sys.argv[1:] == ["--version"]\n')
            with patch.object(adapter.shutil, "which", return_value=executable):
                self.assertEqual(adapter.detect_backend(), ("ookla", executable))
            self.assertFalse(any("accept" in arg for arg in adapter.command_for("ookla", executable)))

    def test_supported_backend_priority_and_name_collision(self):
        with tempfile.TemporaryDirectory() as folder:
            ookla = self.fake_cli(folder, 'print("Speedtest by Ookla 1.2.0")\n')
            with patch.object(adapter.shutil, "which", side_effect=lambda name: ookla):
                self.assertEqual(adapter.detect_backend()[0], "ookla")
            Path(ookla).write_text(f'#!{sys.executable}\nprint("speedtest-cli 2.1.3")\n')
            with patch.object(adapter.shutil, "which", return_value=ookla):
                self.assertEqual(adapter.detect_backend()[0], "sivel")
            Path(ookla).write_text(f'#!{sys.executable}\nprint("unrelated tool")\n')
            with patch.object(adapter.shutil, "which", return_value=ookla):
                self.assertIsNone(adapter.detect_backend())

    def test_real_process_progress_and_final_without_newline(self):
        with tempfile.TemporaryDirectory() as folder:
            path = self.fake_cli(folder, 'import json, sys\n'
                'print(json.dumps({"type":"ping","ping":{"latency":12.5,"progress":1}}), flush=True)\n'
                'print(json.dumps({"type":"upload","upload":{"bandwidth":2500000,"progress":.5}}), flush=True)\n'
                f'sys.stdout.write({json.dumps(json.dumps(RESULT))})\n')
            events = []
            adapter.run_backend("ookla", path, lambda **event: events.append(event))
            self.assertEqual([e["phase"] for e in events], ["preparing", "ping", "upload", "complete"])
            self.assertEqual(events[-1]["downloadMbps"], 100)

    def test_failures_do_not_commit_results_or_leak_output(self):
        bodies = [
            'import sys\nprint("GDPR license PRIVATE",file=sys.stderr)\nsys.exit(1)\n',
            'print("not JSON PRIVATE")\n',
            f'import sys\nprint({json.dumps(json.dumps(RESULT))})\nsys.exit(1)\n',
            'print("x" * 70000)\n',
            'pass\n',
        ]
        with tempfile.TemporaryDirectory() as folder:
            for body in bodies:
                events = []
                with self.assertRaises(adapter.TestError) as caught:
                    adapter.run_backend("ookla", self.fake_cli(folder, body), lambda **e: events.append(e))
                self.assertNotIn("PRIVATE", str(caught.exception))
                self.assertNotIn("complete", [e["phase"] for e in events])
        self.assertIn("review its terms", adapter.failure_message("license"))
        with tempfile.TemporaryDirectory() as folder:
            path = self.fake_cli(folder, 'import sys\nprint("=====")\nprint("Review the EULA and GDPR terms")\nsys.exit(1)\n')
            with self.assertRaisesRegex(adapter.TestError, "review its terms"):
                adapter.run_backend("ookla", path, lambda **event: None)

    def test_timeout_reaps_process_group(self):
        with tempfile.TemporaryDirectory() as folder:
            pid_file = Path(folder) / "pid"
            path = self.fake_cli(folder, f'import os,time\nopen({str(pid_file)!r},"w").write(str(os.getpid()))\ntime.sleep(10)\n')
            with self.assertRaisesRegex(adapter.TestError, "timed out"):
                adapter.run_backend("ookla", path, lambda **event: None, timeout=.2)
            with self.assertRaises(ProcessLookupError):
                os.kill(int(pid_file.read_text()), 0)

    def test_popup_owns_advanced_only_card_and_monitor_routing(self):
        popup = (ROOT/"modules/main/IndicatorPopup.qml").read_text()
        panel = (ROOT/"modules/bar/NetworkPanel.qml").read_text()
        self.assertIn("wifiComponent; NetworkPanel", popup)
        self.assertIn("popupScreen: popup.hostWindow ? popup.hostWindow.screen : null", popup)
        self.assertIn("popup.beginWifiQr(screen, ssid)", popup)
        self.assertIn("widgetLoader.item ? widgetLoader.item.implicitHeight", popup)
        self.assertIn("hostWindow.screen.height - 95", popup)
        self.assertIn("SettingsStore.showSpeedTestPanel && wifiCard.advancedOpen", panel)
        self.assertIn("visible: active", panel)
        self.assertIn("externalScroll: true", panel)

    def test_cancellation_reaps_backend_and_workers(self):
        with tempfile.TemporaryDirectory() as folder:
            self.fake_cli(folder, 'import sys,os,time,subprocess\n'
                'if "--version" in sys.argv:\n print("Speedtest by Ookla");sys.exit(0)\n'
                'child=subprocess.Popen([sys.executable,"-c","import time;time.sleep(30)"])\n'
                'print("{\\"type\\":\\"ping\\",\\"ping\\":{\\"latency\\":10}}",flush=True)\n'
                'open(os.environ["TEST_PIDS"],"w").write(str(os.getpid())+" "+str(child.pid))\n'
                'time.sleep(30)\n')
            env = dict(os.environ, PATH=folder, TEST_PIDS=str(Path(folder)/"pids"))
            proc = subprocess.Popen([sys.executable, str(ROOT/"scripts/rusticq-speedtest.py")], env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                deadline = time.monotonic()+5
                while not Path(env["TEST_PIDS"]).exists() and time.monotonic()<deadline:
                    time.sleep(.02)
                self.assertTrue(Path(env["TEST_PIDS"]).exists())
                proc.send_signal(signal.SIGTERM)
                output, errors = proc.communicate(timeout=3)
                self.assertEqual(proc.returncode, 130, errors)
                self.assertEqual(json.loads(output.splitlines()[-1])["phase"], "cancelled")
                for pid in Path(env["TEST_PIDS"]).read_text().split():
                    status = Path(f"/proc/{pid}/stat")
                    self.assertTrue(not status.exists() or status.read_text().split()[2] == "Z", pid)
            finally:
                if proc.poll() is None:
                    proc.kill(); proc.wait()


if __name__ == "__main__":
    unittest.main()
