#!/usr/bin/env python3
"""Exercise the real Appearance page with an isolated, fake wallpaper helper."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="rusticq-wallpaper-ui-") as folder:
        root = Path(folder)
        for name in ("components", "config", "services", "assets", "modules"):
            shutil.copytree(repo / name, root / name)
        (root / "scripts").mkdir()
        (root / "user-settings.json").write_text(json.dumps({"wallpaperPath": ""}))
        (root / "scripts/rusticq-appearance.py").write_text(
            'import json\nprint(json.dumps({"ok": True, "fonts": []}))\n')
        (root / "scripts/rusticq-wallpaper.py").write_text('''
import json, sys, time
from pathlib import Path
with (Path(__file__).parent / "calls.jsonl").open("a") as handle:
    handle.write(json.dumps(sys.argv[1:]) + "\\n")
time.sleep(.2)
ok = "fail.png" not in sys.argv[1]
print(json.dumps({"ok": ok, "message": "TEST applied" if ok else "TEST backend failed"}))
''')
        (root / "shell.qml").write_text('''
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "modules/settings/pages"
ShellRoot {
    Window {
        visible: true
        width: 800; height: 600
        Item {
            anchors.fill: parent
            SettingsAppearancePage { id: page; width: 780 }
            TestCase {
                name: "WallpaperInteraction"
                when: true
                function descendants(item) {
                    let result = [item];
                    for (const child of item.children) result = result.concat(descendants(child));
                    return result;
                }
                function label(text) {
                    return descendants(page).find(item => item.text === text);
                }
                function clickItem(item) {
                    page.y -= item.mapToItem(page.parent, 0, 0).y - 120;
                    wait(30);
                    mouseClick(item, item.width / 2, item.height / 2);
                }
                function apply(path, expected) {
                    const section = descendants(page).find(item => item.heading === "Wallpaper");
                    const input = descendants(section).find(item => item.selectByMouse !== undefined);
                    verify(input !== undefined, "wallpaper path input exists");
                    input.text = path;
                    const button = label("Apply wallpaper").parent.parent;
                    clickItem(button);
                    wait(10);
                    mouseClick(button, button.width / 2, button.height / 2);
                    tryVerify(() => label(expected) !== undefined, 3000);
                    wait(100);
                }
                function test_apply_and_replace() {
                    wait(150);
                    SettingsStore.wallpaperBackend = "swaybg";
                    SettingsStore.wallpaperFitMode = "fit";
                    apply("/tmp/wallpaper with spaces.png", "TEST applied");
                    const row = label("Replace other wallpaper daemons this time (may end Omarchy's wallpaper process)").parent;
                    clickItem(row.children[0]);
                    compare(row.children[0].color, Theme.accent);
                    apply("/tmp/second.png", "TEST applied");
                    apply("/tmp/fail.png", "TEST backend failed");
                    compare(label("TEST backend failed").color, Theme.error);
                }
                function cleanupTestCase() {
                    console.log("WALLPAPER RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed");
                }
            }
        }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="generic",
                   QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=folder)
        try:
            result = subprocess.run(["qs", "-p", str(root / "shell.qml"), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=20)
        except subprocess.TimeoutExpired as exc:
            print((exc.stdout or b"").decode() + (exc.stderr or b"").decode())
            raise
        output = result.stdout + result.stderr
        print(output, end="")
        summary = re.search(r"WALLPAPER RESULTS (\d+) passed, (\d+) failed", output)
        if result.returncode or not summary or int(summary[2]):
            return 1
        calls = [json.loads(line) for line in (root / "scripts/calls.jsonl").read_text().splitlines()]
        assert calls == [
            ["/tmp/wallpaper with spaces.png", "--backend", "swaybg", "--mode", "fit"],
            ["/tmp/second.png", "--backend", "swaybg", "--mode", "fit", "--replace-conflicts"],
            ["/tmp/fail.png", "--backend", "swaybg", "--mode", "fit"],
        ], calls
        print("PASS: Apply dispatch, paths with spaces, one-shot replacement, and backend error feedback")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
