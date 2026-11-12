#!/usr/bin/env python3
"""Integration install workflow with mocked helpers; no network or live updates."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HELPER = '''import json
from pathlib import Path
import sys
import time
root = Path(__file__).resolve().parent
command = sys.argv[1]
def option(key, fallback=""):
    return sys.argv[sys.argv.index(key)+1] if key in sys.argv else fallback
state_file = root / "mock-status.json"
def save_state(state):
    temporary = state_file.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    temporary.replace(state_file)
if Path(__file__).name == "rusticq-shell-updates.py":
    state = json.loads(state_file.read_text())
    if command == "status":
        print(json.dumps(state))
    elif command == "releases":
        print(json.dumps({"ok":True,"releases":[]}))
    elif command == "check":
        tag = option("--tag", "v1.0.0")
        if tag == "fail":
            print(json.dumps({"ok":False,"message":"Offline"})); sys.exit(1)
        if tag == "slow": time.sleep(.3)
        release = {"tag":tag,"asset":"full.zip","danger":tag.startswith("beta"),"downgrade":False}
        state["release"] = release
        save_state(state)
        print(json.dumps({"ok":True,"release":release,"message":"Release fetched"}))
    else:
        expected = "REAPPLY LOCAL" if command == "reapply-local" else "UPDATE SHELL"
        assert option("--confirm") == expected
        state.update(install_count=state["install_count"]+1, last_command=command,
                     last_tag=option("--tag"), last_target=option("--target"))
        save_state(state)
        print(json.dumps({"ok":True,"target":option("--target"),"installed_path":"/tmp/mock-installed","message":"Installed"}))
elif Path(__file__).name == "rusticq-doctor.py":
    print(json.dumps({"totals":{"ok":1,"warn":0,"skip":0}}))
elif Path(__file__).name == "rusticq-config-guard.py":
    print(json.dumps({"ok":True,"data":{"settings":{"status":"ok","snapshots":0},"message":"Imported"}}))
elif Path(__file__).name == "rusticq-dependencies.py":
    print(json.dumps({"ok":True,"items":[],"missing_core":0,"missing_optional":0}))
else:
    print(json.dumps({"ok":True,"permanent":True,"compatibility":{},"percent":100,"changes":[]}))
'''
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "modules/settings/pages"
ShellRoot {
    Window {
        visible: true
        width: 800; height: 800
        Flickable {
            id: scroll
            anchors.fill: parent
            contentHeight: page.implicitHeight
            SettingsIntegrationPage { id: page; width: scroll.width }
        }
        TestCase {
            name: "ShellInstall"
            when: true
            function descendants(item) {
                let result = [item];
                for (const child of item.children) result = result.concat(descendants(child));
                return result;
            }
            function choose(name) {
                const item = descendants(page).find(child => child.objectName === name);
                verify(item !== undefined, name);
                const point = item.mapToItem(page, 0, 0);
                scroll.contentY = Math.min(point.y, scroll.contentHeight - scroll.height);
                wait(30);
                mouseClick(item, item.width / 2, item.height / 2);
            }
            function initTestCase() {
                tryVerify(() => page.shellUpdateStatus.dev_ready === true);
                tryCompare(page, "shellUpdateCheckBusy", false);
                wait(100);
                compare(page.shellUpdateStatus.install_count, 0);
                compare(ShellReload.begins, 0);
            }
            function init() {
                page.shellUpdateTarget = "installed";
                page.shellReleaseTag = "v1.0.0";
                page.shellUpdateRiskAccepted = false;
                page.shellUpdateAction = "";
                page.shellUpdateConfirm = "";
            }
            function waitInstall(before) {
                tryVerify(() => page.shellUpdateStatus.install_count === before + 1);
                tryCompare(page, "shellUpdateBusy", false);
                compare(ShellReload.lastSuccess, true);
                compare(ShellReload.lastPath, "/tmp/mock-installed");
            }
            function cleanup() {
                console.log("INSTALL TEST " + qtest_results.functionName + " failed=" + qtest_results.failed);
                if (qtest_results.failed) console.log("INSTALL STATE", JSON.stringify(page.shellUpdateStatus), page.shellUpdateMessage,
                    page.shellUpdateBusy, page.shellUpdateAction, page.shellCheckSucceeded, page.shellFetchInstallPending, ShellReload.pending, ShellReload.updating);
            }
            function cleanupTestCase() { console.log("INSTALL RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
            function test_fetch_install_stable() {
                const before = page.shellUpdateStatus.install_count;
                choose("shell-fetch-install");
                waitInstall(before);
                compare(page.shellUpdateStatus.last_command, "update-shell");
                compare(page.shellUpdateStatus.last_target, "installed");
                compare(page.shellUpdateStatus.last_tag, "v1.0.0");
                verify(!page.shellFetchInstallPending);
            }
            function test_fetch_failure_never_installs_or_reloads() {
                const before = page.shellUpdateStatus.install_count;
                const begins = ShellReload.begins;
                page.shellReleaseTag = "fail";
                choose("shell-fetch-install");
                tryCompare(page, "shellUpdateCheckBusy", false);
                wait(100);
                compare(page.shellUpdateStatus.install_count, before);
                compare(page.shellUpdateAction, "");
                compare(page.shellFetchInstallPending, false);
                compare(ShellReload.begins, begins);
            }
            function test_fetch_risk_requires_review() {
                const before = page.shellUpdateStatus.install_count;
                page.shellReleaseTag = "beta-4";
                choose("shell-fetch-install");
                tryCompare(page, "shellUpdateAction", "update-shell");
                compare(page.shellUpdateStatus.install_count, before);
                verify(!page.shellInstallReady);
                page.shellUpdateRiskAccepted = true;
                choose("shell-install-selected");
                waitInstall(before);
                compare(page.shellUpdateStatus.last_tag, "beta-4");
            }
            function test_import_reloads_current_config() {
                page.settingsImportPath = "/tmp/mock.json";
                page.settingsImportPreview = {path: "/tmp/mock.json", sha256: "a".repeat(64)};
                page.settingsImportConfirmation = "IMPORT SETTINGS";
                const finishes = ShellReload.finishes;
                page.settingsTransfer("import");
                tryVerify(() => ShellReload.finishes === finishes + 1);
                compare(ShellReload.lastSuccess, true);
                compare(ShellReload.lastPath, Quickshell.shellDir);
            }
            function test_manual_install_after_check() {
                const before = page.shellUpdateStatus.install_count;
                page.shellUpdateCheck();
                tryCompare(page, "shellUpdateCheckBusy", false);
                compare(page.shellUpdateStatus.install_count, before);
                choose("shell-review-install");
                verify(page.shellInstallReady);
                choose("shell-install-selected");
                waitInstall(before);
            }
            function test_reapply_local_installs_without_typing() {
                const before = page.shellUpdateStatus.install_count;
                page.shellUpdateTarget = "installed";
                page.shellUpdateAction = "reapply-local";
                verify(page.shellInstallReady);
                compare(page.shellUpdateConfirm, "");
                choose("shell-install-selected");
                waitInstall(before);
                compare(page.shellUpdateStatus.last_command, "reapply-local");
            }
            function test_target_change_cancels_auto_install() {
                const before = page.shellUpdateStatus.install_count;
                page.shellReleaseTag = "slow";
                page.shellFetchAndInstall();
                page.shellUpdateTarget = "dev";
                tryCompare(page, "shellUpdateCheckBusy", false);
                wait(100);
                compare(page.shellUpdateStatus.install_count, before);
                compare(page.shellUpdateAction, "");
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix="rusticq-shell-install-") as folder:
        root = Path(folder)
        for name in ("config", "components", "assets", "services", "modules"):
            shutil.copytree(ROOT / name, root / name)
        (root / "user-settings.json").write_text("{}")
        (root / "config/ShellReload.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property bool pending: false
    property bool updating: false
    property string message: ""
    property bool reloadFailed: false
    property int begins: 0
    property int finishes: 0
    property bool lastSuccess: false
    property string lastPath: ""
    function beginUpdate() { updating = true; begins++; }
    function finishUpdate(success, path) { updating = false; finishes++; lastSuccess = success; lastPath = path; }
    function requestReload() {}
}
''')
        scripts = root / "scripts"
        scripts.mkdir()
        for name in ("rusticq-shell-updates.py", "rustiq-desktop-integration.py", "rusticq-doctor.py", "rusticq-config-guard.py", "rusticq-dependencies.py"):
            (scripts / name).write_text(HELPER)
        (scripts / "mock-status.json").write_text(json.dumps({"ok":True,"installed":True,"dev_ready":True,
            "installed_path":"/tmp/mock-installed","local_path":"/tmp/mock-dev","release":{},"install_count":0}))
        (root / "shell.qml").write_text(QML)
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="generic",
                   QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=folder)
        result = subprocess.run(["qs", "-p", str(root), "--no-color"], env=env,
                                capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        print(output, end="")
        summary = re.search(r"INSTALL RESULTS (\d+) passed, (\d+) failed", output)
        assert result.returncode == 0 and summary and int(summary[1]) >= 8 and int(summary[2]) == 0
        assert not re.search(r"TypeError|ReferenceError|Binding loop|Could not load", output), output
    print("PASS: fetch/install, manual/local install, risk review, failures, target changes and successful-import reload")


if __name__ == "__main__":
    main()
