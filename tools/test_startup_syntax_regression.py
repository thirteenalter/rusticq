#!/usr/bin/env python3
"""Ensure the static validator catches the QML sibling-separator crash.

This is a source-only test: it does not claim to replace qmllint or a live qs run.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
checker = root / "tools" / "verify-static.py"
assert checker.is_file()

result = subprocess.run([sys.executable, str(checker)], capture_output=True, text=True)
assert result.returncode == 0, result.stdout + result.stderr

with tempfile.TemporaryDirectory(prefix="rustiq-qml-syntax-") as temporary:
    temp = Path(temporary) / "quickshell"
    shutil.copytree(root, temp, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    target = temp / "modules" / "bar" / "BarMonitors.qml"
    original = target.read_text(encoding="utf-8")
    needle = '    Text { Layout.fillWidth:true;text:root.status;'
    assert needle in original
    # Follow the previous closing `}` with an invalid QML separator.
    target.write_text(original.replace(needle, '    ; Text { Layout.fillWidth:true;text:root.status;', 1), encoding="utf-8")
    failed = subprocess.run([sys.executable, str(temp / "tools" / "verify-static.py")], capture_output=True, text=True)
    assert failed.returncode != 0, "Checker wrongly accepted an invalid QML declaration separator"
    assert "invalid semicolon between QML object declarations" in failed.stdout, failed.stdout

print("PASS: all QML sources pass structural checks; injected sibling separator is detected")
