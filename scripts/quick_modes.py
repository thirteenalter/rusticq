#!/usr/bin/env python3
"""Small, checked adapters for notification DND and hyprsunset. No shell eval."""
import argparse
import json
import re
import shutil
import subprocess


def run(args, timeout=5):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Service command failed")
    return result.stdout.strip()


def temperature():
    value = run(["hyprctl", "hyprsunset", "temperature"])
    if not re.fullmatch(r"\d+", value):
        raise RuntimeError("hyprsunset did not return a temperature")
    return int(value)


def probe(key):
    try:
        if key == "silent":
            value = run(["omarchy", "shell", "notifications", "dndState"])
            if value not in ("on", "off"):
                raise RuntimeError("Notification service did not return its DND state")
            return {"available": True, "active": value == "on", "detail": "Do Not Disturb"}
        if key != "night":
            raise ValueError("Unknown mode")
        if not shutil.which("hyprctl") or not shutil.which("hyprsunset"):
            raise RuntimeError("Night mode requires hyprsunset")
        try:
            temp = temperature()
        except (RuntimeError, subprocess.TimeoutExpired):
            # Omarchy can start hyprsunset on demand; no start happens during a probe.
            if not shutil.which("omarchy-toggle-nightlight"):
                raise RuntimeError("Start hyprsunset to use Night mode")
            return {"available": True, "active": False, "detail": "Start night light (4000 K)"}
        return {"available": True, "active": temp < 6000, "detail": f"Screen temperature: {temp} K"}
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        return {"available": False, "active": False, "detail": str(exc)}


def set_mode(key, enabled):
    if key not in ("silent", "night") or type(enabled) is not bool:
        raise ValueError("Invalid mode or state")
    before = probe(key)
    if not before["available"]:
        raise RuntimeError(before["detail"])
    if before["active"] == enabled:
        return
    if key == "silent":
        run(["omarchy", "shell", "notifications", "setDnd", "on" if enabled else "off"])
    else:
        try:
            temperature()
        except (RuntimeError, subprocess.TimeoutExpired):
            run(["omarchy", "toggle", "nightlight"], timeout=10)
        run(["hyprctl", "hyprsunset", "temperature", "4000" if enabled else "6500"])
        if (temperature() < 6000) != enabled:
            raise RuntimeError("Night mode did not reach the requested temperature")
    after = probe(key)
    if not after["available"] or after["active"] != enabled:
        raise RuntimeError(f"{key.capitalize()} did not reach the requested state")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("status", "set"))
    parser.add_argument("mode", nargs="?", choices=("silent", "night"))
    parser.add_argument("state", nargs="?", choices=("on", "off"))
    args = parser.parse_args()
    if args.action == "set" and (args.mode is None or args.state is None):
        parser.error("set requires a mode and on/off")
    error = ""
    try:
        if args.action == "set":
            set_mode(args.mode, args.state == "on")
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        error = str(exc)
    print(json.dumps({"ok": not error, "error": error,
                      "states": {key: probe(key) for key in ("silent", "night")}}))
    return int(bool(error))


if __name__ == "__main__":
    raise SystemExit(main())
