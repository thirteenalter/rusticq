#!/usr/bin/env python3
"""Checked hyprsunset adapter. Silent is handled by RusticQ's native DND."""
import argparse
import json
import re
import shutil
import subprocess
import time


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
        if key != "night":
            raise ValueError("Unknown mode")
        if not shutil.which("hyprctl") or not shutil.which("hyprsunset"):
            raise RuntimeError("Night mode requires hyprsunset")
        try:
            temp = temperature()
        except (RuntimeError, subprocess.TimeoutExpired):
            # Only an explicit set may start the daemon; status stays read-only.
            return {"available": True, "active": False, "temperature": None,
                    "detail": "Night Light is ready to start"}
        return {"available": True, "active": temp < 6500, "temperature": temp,
                "detail": f"Screen temperature: {temp} K"}
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        return {"available": False, "active": False, "detail": str(exc)}


def set_mode(key, enabled, kelvin=4000):
    if key != "night" or type(enabled) is not bool:
        raise ValueError("Invalid mode or state")
    if type(kelvin) is not int or not 2000 <= kelvin <= 6000:
        raise ValueError("Night Light temperature must be between 2000 and 6000 K")
    before = probe(key)
    if not before["available"]:
        raise RuntimeError(before["detail"])
    target = kelvin if enabled else 6500
    if before.get("temperature") == target or (not enabled and before.get("temperature") is None):
        return
    if before.get("temperature") is None:
        # Do not toggle Omarchy's fixed 4000 K mode or write its configuration.
        command = ["hyprsunset", "--temperature", str(target)]
        if shutil.which("uwsm-app"):
            command = ["uwsm-app", "--"] + command
        subprocess.Popen(command, stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    # A newly started daemon can overwrite its first IPC value during startup.
    for _ in range(12):
        try:
            run(["hyprctl", "hyprsunset", "temperature", str(target)])
            time.sleep(.15)
            if temperature() == target:
                return
        except (RuntimeError, subprocess.TimeoutExpired):
            time.sleep(.1)
    raise RuntimeError("Night Light did not reach the requested temperature")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("status", "set"))
    parser.add_argument("mode", nargs="?", choices=("night",))
    parser.add_argument("state", nargs="?", choices=("on", "off"))
    parser.add_argument("--temperature", type=int, default=4000)
    args = parser.parse_args()
    if args.action == "set" and (args.mode is None or args.state is None):
        parser.error("set requires a mode and on/off")
    error = ""
    try:
        if args.action == "set":
            set_mode(args.mode, args.state == "on", args.temperature)
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        error = str(exc)
    print(json.dumps({"ok": not error, "error": error,
                      "states": {"night": probe("night")}}))
    return int(bool(error))


if __name__ == "__main__":
    raise SystemExit(main())
