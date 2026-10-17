#!/usr/bin/env python3
"""RusticQ's allowlisted Arch dependency diagnostics / optional installation.

status and core-packages are read-only; launch requires a visible confirmation
and opens a terminal. apply prompts a second time inside the terminal before
any package operation. Never run commands from user-provided package names.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

MANIFEST = Path(__file__).resolve().parent.parent / "config" / "dependencies.json"


def catalogue():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    result = {}
    for group in ("core", "optional"):
        for item in data[group]:
            if not re.fullmatch(r"[a-z][a-z0-9-]{0,50}", item["id"]):
                raise RuntimeError("Invalid dependency identifier in manifest")
            if not re.fullmatch(r"[a-z][a-z0-9@._+-]{0,90}", item["package"]):
                raise RuntimeError("Invalid pacman package in manifest")
            if item["id"] in result:
                raise RuntimeError("Duplicate dependency identifier")
            result[item["id"]] = {**item, "group": group}
    return result


def is_installed(package):
    if not shutil.which("pacman"):
        return False
    # deptest respects virtual providers (e.g. quickshell-git providing quickshell).
    # -Qq would incorrectly call those compatible installations missing.
    result = subprocess.run(["pacman", "-T", "--", package],
                            text=True, capture_output=True, check=False, timeout=8)
    return result.returncode == 0


def status():
    items = []
    for entry in catalogue().values():
        items.append({**entry, "installed": is_installed(entry["package"])})
    return {"ok": True, "arch": bool(shutil.which("pacman")), "items": items,
            "missing_core": sum(1 for it in items if it["group"] == "core" and not it["installed"]),
            "missing_optional": sum(1 for it in items if it["group"] == "optional" and not it["installed"])}


def choose_terminal():
    candidates = [
        ("ghostty", ["ghostty", "-e"]), ("foot", ["foot", "-e"]),
        ("kitty", ["kitty", "-e"]), ("alacritty", ["alacritty", "-e"]),
        ("wezterm", ["wezterm", "start", "--"]),
        ("konsole", ["konsole", "-e"]), ("xterm", ["xterm", "-e"]),
    ]
    for name, command in candidates:
        if shutil.which(name):
            return command
    raise RuntimeError("No supported terminal emulator installed. Open a terminal to install the package manually.")


def launch(dep_id, confirmation):
    entry = catalogue().get(dep_id)
    if entry is None:
        raise ValueError("Unknown dependency ID")
    if confirmation != "INSTALL " + dep_id:
        raise ValueError("Explicit INSTALL <id> confirmation is required")
    if not shutil.which("pacman"):
        raise RuntimeError("This installer supports Arch Linux/pacman only")
    if is_installed(entry["package"]):
        return {"ok": True, "message": entry["name"] + " is already installed."}
    cmd = choose_terminal() + [sys.executable, str(Path(__file__).resolve()), "apply", dep_id]
    subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    return {"ok": True, "message": "Opened a terminal for " + entry["name"] + ". Confirm the install there; this does not imply success."}


def apply(dep_id):
    entry = catalogue().get(dep_id)
    if entry is None:
        raise ValueError("Unknown dependency ID")
    if not shutil.which("pacman"):
        raise RuntimeError("pacman not found")
    package = entry["package"]
    print("\nRusticQ optional dependency installer", flush=True)
    print("Package:", package, "\nPurpose:", entry["description"], flush=True)
    print("Official Arch repository packages only. No AUR and no --noconfirm.", flush=True)
    answer = input("Type INSTALL to continue: ").strip()
    if answer != "INSTALL":
        print("Cancelled. No packages changed.")
        return 1
    if is_installed(package):
        print("Already installed.")
        return 0
    if shutil.which("omarchy"):
        print("Omarchy detected. Update with Omarchy's own guarded update command first.", flush=True)
        result = subprocess.run(["omarchy", "update"], check=False)
        if result.returncode:
            print("Omarchy update did not finish. Package installation cancelled.")
            return result.returncode
        cmd = ["sudo", "pacman", "-S", "--needed", "--", package]
    else:
        # Arch partial upgrades are unsupported, so sync+upgrade with install.
        cmd = ["sudo", "pacman", "-Syu", "--needed", "--", package]
    print("Running:", " ".join(cmd), flush=True)
    result = subprocess.run(cmd, check=False)
    print("\nExit status:", result.returncode, flush=True)
    try:
        input("Press Enter to close this terminal...")
    except EOFError:
        pass
    return result.returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "core-packages", "missing-core", "launch", "apply"])
    parser.add_argument("dependency", nargs="?")
    parser.add_argument("--confirm", default="")
    args = parser.parse_args()
    try:
        if args.action == "status":
            print(json.dumps(status(), ensure_ascii=False))
        elif args.action == "core-packages":
            for item in catalogue().values():
                if item["group"] == "core":
                    print(item["package"])
        elif args.action == "missing-core":
            for item in catalogue().values():
                if item["group"] == "core" and not is_installed(item["package"]):
                    print(item["package"])
        elif args.action == "launch":
            print(json.dumps(launch(args.dependency, args.confirm), ensure_ascii=False))
        else:
            sys.exit(apply(args.dependency))
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        if args.action == "apply":
            print("ERROR:", exc, file=sys.stderr)
        else:
            print(json.dumps({"ok": False, "message": str(exc)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
