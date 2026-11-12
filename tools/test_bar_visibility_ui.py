#!/usr/bin/env python3
"""Wayland UI regression test with temporary settings (requires a desktop session)."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="rusticq-bar-visibility-") as folder:
        root = Path(folder)
        for name in ("components", "config", "services", "assets", "modules"):
            shutil.copytree(repo / name, root / name)
        (root / "user-settings.json").write_text(json.dumps({"barVisible": False}))
        (root / "shell.qml").write_text('''
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "modules/main"
import "modules/settings/pages"
ShellRoot {
    BarAutoHide {
        id: first
        enabled: SettingsStore.barVisible && SettingsStore.barAutoHide
        screen: Quickshell.screens[0]
    }
    BarAutoHide {
        id: second
        enabled: SettingsStore.barVisible && SettingsStore.barAutoHide
        screen: Quickshell.screens[0]
    }
    BarRecoveryHandle { id: recovery; screen: Quickshell.screens[0] }
    Window {
        visible: true
        width: 800; height: 600
        SettingsBarPage { id: page; width: 780 }
        TestCase {
            when: true
            name: "BarVisibility"
            function descendants(item) {
                let result = [item];
                for (const child of item.children) result = result.concat(descendants(child));
                return result;
            }
            function choose(label) {
                const text = descendants(page).find(item => item.text === label);
                verify(text !== undefined);
                mouseClick(text.parent, text.parent.width / 2, text.parent.height / 2);
                wait(30);
            }
            function test_modes_and_reveal() {
                try {
                wait(150);
                compare(SettingsStore.barVisibilityMode, "hide"); // legacy settings
                verify(recovery.visible);
                choose("Hide completely");
                compare(SettingsStore.barVisibilityMode, "hidden");
                verify(!recovery.visible);
                verify(!first.enabled);
                SettingsStore.setBarVisible(true); // IPC recovery remains available
                compare(SettingsStore.barVisibilityMode, "show");
                choose("Auto-hide");
                compare(SettingsStore.barVisibilityMode, "auto");
                verify(!first.shown);
                verify(!second.shown);
                verify(!recovery.visible);
                const edge = first.edgeWindow;
                verify(edge !== null);
                for (const position of ["top", "bottom", "left", "right"]) {
                    first.position = position;
                    wait(20);
                    verify(edge.visible);
                    compare(edge.anchors.top, position !== "bottom");
                    compare(edge.anchors.bottom, position !== "top");
                    compare(edge.anchors.left, position !== "right");
                    compare(edge.anchors.right, position !== "left");
                    compare(first.vertical ? edge.implicitWidth : edge.implicitHeight, 2);
                }
                first.position = "top";
                wait(30);
                mouseMove(edge.contentItem, edge.width / 2, 1);
                tryCompare(first, "shown", true);
                verify(!second.shown);
                first.hovered = true;
                wait(550);
                verify(first.shown);
                first.hovered = false;
                wait(150);
                verify(first.shown); // grace period to cross margins to the bar
                first.heldOpen = true;
                wait(550);
                verify(first.shown); // popup keeps its anchor visible
                first.heldOpen = false;
                tryCompare(first, "shown", false, 1000);
                choose("Hide bar");
                verify(recovery.visible);
                choose("Show bar");
                verify(!recovery.visible);
                verify(first.shown);
                choose("Hide completely");
                SettingsStore.toggleBar();
                compare(SettingsStore.barVisibilityMode, "show");
                for (let i = 0; i < 2; i++) {
                    SettingsStore.toggleBarCompletely();
                    compare(SettingsStore.barVisibilityMode, "hidden");
                    verify(!SettingsStore.barVisible);
                    verify(!recovery.visible);
                    compare(descendants(page).find(item => item.text === "Hide completely").parent.border.width, 1);
                    SettingsStore.toggleBarCompletely();
                    compare(SettingsStore.barVisibilityMode, "show");
                    verify(SettingsStore.barVisible);
                    verify(!recovery.visible);
                    compare(descendants(page).find(item => item.text === "Show bar").parent.border.width, 1);
                }
                choose("Auto-hide");
                SettingsStore.toggleBarCompletely();
                compare(SettingsStore.barVisibilityMode, "hidden");
                verify(!first.enabled);
                SettingsStore.toggleBarCompletely();
                compare(SettingsStore.barVisibilityMode, "show");
                choose("Auto-hide");
                wait(150);
                } catch (error) { console.log("TEST FAILURE", String(error), error.stack); throw error; }
            }
            function cleanupTestCase() {
                console.log("BAR RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed");
            }
        }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="wayland", QT_QPA_PLATFORMTHEME="generic",
                   QT_QUICK_BACKEND="software")
        result = subprocess.run(["qs", "-p", str(root / "shell.qml"), "--no-color"],
                                env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output, end="")
        summary = re.search(r"BAR RESULTS (\d+) passed, (\d+) failed", output)
        if result.returncode or not summary or int(summary[2]):
            return 1
        saved = json.loads((root / "user-settings.json").read_text())
        assert saved["barAutoHide"] and saved["barVisible"] and saved["showBarRecoveryHandle"]
        print("PASS: four modes, recovery, independent reveal, grace period, popup hold, four edges, persistence")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
