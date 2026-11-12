#!/usr/bin/env python3
"""Real native reloads in isolated offscreen shells, including atomic source swaps."""
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import Quickshell
import Quickshell.Io
import "config"
ShellRoot {
    IpcHandler {
        target: "rusticq"
        function reload(): void { ShellReload.requestReload(); }
        function save(): void { SettingsStore.clockFormat = "HH:mm:ss"; SettingsStore.save(); }
        function begin(): void { ShellReload.beginUpdate(); console.log("WATCH", Quickshell.watchFiles); }
        function finish(success: bool): void { ShellReload.finishUpdate(success, Quickshell.shellDir); }
        function remote(path: string): void { ShellReload.reloadPath(path); }
    }
    Component.onCompleted: console.log("CONFIG_LOADED", Quickshell.processId, SettingsStore.clockFormat, "MARKER")
    Connections {
        target: Quickshell
        function onReloadFailed(errorString) { console.log("RELOAD_FAILED", errorString); }
    }
}
'''


class Shell:
    def __init__(self, path, env):
        self.path, self.env = path, env
        self.output = []
        self.lines = queue.Queue()
        self.proc = subprocess.Popen(["qs", "-p", str(path), "--no-color"], env=env,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        def reader():
            for line in self.proc.stdout:
                self.lines.put(line.rstrip())
        threading.Thread(target=reader, daemon=True).start()

    def wait(self, fragment, timeout=8):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            line = self.lines.get(timeout=max(.01, deadline - time.monotonic()))
            self.output.append(line)
            if fragment in line:
                print(line)
                return line
        raise AssertionError("Missing " + fragment + "\n" + "\n".join(self.output))

    def quiet(self, seconds=1):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                line = self.lines.get(timeout=max(.01, deadline - time.monotonic()))
            except queue.Empty:
                break
            self.output.append(line)
            assert "CONFIG_LOADED" not in line, line
        assert self.proc.poll() is None

    def call(self, *args):
        reply = subprocess.run(["qs", "ipc", "-p", str(self.path), "call", "rusticq", *args],
                               env=self.env, capture_output=True, text=True, timeout=5)
        assert reply.returncode == 0, reply.stdout + reply.stderr

    def close(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.proc.stdout.close()


def main():
    with tempfile.TemporaryDirectory(prefix="rusticq-config-reload-") as folder:
        base = Path(folder)
        runtime = base / "runtime"
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="generic",
                   QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(runtime), QS_NO_RELOAD_POPUP="1")
        def tree(name):
            path = base / name
            shutil.copytree(ROOT / "config", path / "config")
            (path / "shell.qml").write_text(QML.replace("MARKER", name))
            (path / "user-settings.json").write_text('{"clockFormat":"HH:mm"}')
            return path
        path = tree("first")
        first = Shell(path, env)
        try:
            initial = first.wait("CONFIG_LOADED")
            pid = first.proc.pid
            assert str(pid) in initial
            first.call("save")
            first.quiet()
            assert json.loads((path / "user-settings.json").read_text())["clockFormat"] == "HH:mm:ss"
            replacement = path / "new-settings.json"
            replacement.write_text('{"clockFormat":"HH:mm dddd"}')
            replacement.replace(path / "user-settings.json")
            assert "HH:mm dddd" in first.wait("CONFIG_LOADED")
            assert first.proc.pid == pid
            first.call("begin")
            first.wait("WATCH false")
            (path / "user-settings.json").write_text('{"clockFormat":"dd/MM/yyyy"}')
            first.quiet()
            first.call("finish", "true")
            assert "dd/MM/yyyy" in first.wait("CONFIG_LOADED")
            first.call("begin")
            first.wait("WATCH false")
            stage = base / "staged"
            shutil.copytree(path, stage)
            (stage / "shell.qml").write_text(QML.replace("MARKER", "new-source"))
            path.rename(base / "previous-source")
            stage.rename(path)
            first.quiet()
            first.call("finish", "true")
            assert "new-source" in first.wait("CONFIG_LOADED")
            assert first.proc.pid == pid
            first.call("begin")
            first.wait("WATCH false")
            first.call("finish", "false")
            first.quiet()
            (path / "user-settings.json").write_text("invalid json")
            first.quiet()
            (path / "user-settings.json").write_text('{"clockFormat":"HH:mm"}')
            first.wait("CONFIG_LOADED")
            other_path = tree("second")
            second = Shell(other_path, env)
            try:
                second.wait("CONFIG_LOADED")
                other_pid = second.proc.pid
                first.call("remote", str(other_path))
                second.wait("CONFIG_LOADED")
                assert second.proc.pid == other_pid
                first.quiet()
            finally:
                second.close()
            saved_source = (path / "shell.qml").read_text()
            (path / "shell.qml").write_text("invalid qml {{{")
            first.wait("RELOAD_FAILED")
            assert first.proc.poll() is None
            (path / "shell.qml").write_text(saved_source.replace("new-source", "recovered-source"))
            first.wait("CONFIG_LOADED")
            assert first.proc.pid == pid
        finally:
            first.close()
    print("PASS: own saves do not reload; external settings, imports, atomic source replacement and remote IPC reload in place; failed updates/invalid JSON do not reload; invalid QML keeps the previous shell")


if __name__ == "__main__":
    main()
