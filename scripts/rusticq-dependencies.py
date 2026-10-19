#!/usr/bin/env python3
"""Read-only dependency inventory and opt-in graphical Polkit installation."""
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


def gui_manage(dep_id, action, confirmation):
    entry = catalogue().get(dep_id)
    if entry is None:
        raise ValueError('Unknown dependency ID')
    if action not in ('install', 'remove'):
        raise ValueError('Unsupported GUI action')
    if action == 'remove' and entry['group'] != 'optional':
        raise ValueError('Core RusticQ dependencies cannot be removed from Integration')
    if confirmation != action.upper() + ' ' + dep_id:
        raise ValueError('Exact ' + action.upper() + ' <id> confirmation required')
    if is_installed(entry['package']) == (action == 'install'):
        return {'ok': True, 'message': entry['name'] + ' is already in the requested state.'}
    # Single policy for both package and dependency installs; no duplicate sudo
    # paths or terminal launchers.
    import importlib.util
    helper = Path(__file__).with_name('rustiq-package-manager.py')
    spec = importlib.util.spec_from_file_location('rusticq_package_ops', helper)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.graphical_transaction(action, entry['package'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "core-packages", "missing-core", "gui"])
    parser.add_argument("dependency", nargs="?")
    parser.add_argument("--operation", choices=["install", "remove"], default="install")
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
        elif args.action == "gui":
            print(json.dumps(gui_manage(args.dependency, args.operation, args.confirm), ensure_ascii=False))
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({"ok": False, "message": str(exc)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
