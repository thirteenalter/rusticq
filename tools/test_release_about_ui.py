#!/usr/bin/env python3
"""Exercise About history and manifest error recovery in isolated Quickshell 0.3.1."""
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
import "modules/settings/pages"

ShellRoot {
    id: root
    property bool repaired: false
    property int selectedIndex: -1
    property var picker: null
    property bool inspectedPopup: false
    readonly property bool recovery: Quickshell.env("RUSTICQ_RELEASE_TEST_RECOVERY") === "1"

    function check(value, message) {
        if (!value) {
            console.error("TEST_FAILED", message);
            Qt.quit();
            throw new Error(message);
        }
    }
    function findNamed(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) {
            const found = findNamed(child, name);
            if (found) return found;
        }
        return null;
    }
    Component.onCompleted: Quickshell.watchFiles = false
    IpcHandler {
        target: "release_test"
        function retry(): void {
            root.repaired = true;
            root.findNamed(about, "releaseRetry").clicked();
            checks.start();
        }
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 960
        implicitHeight: 900
        color: "#282828"
        Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: about.implicitHeight
            clip: true
            SettingsAboutPage {
                id: about
                width: parent.width
            }
        }
    }
    Timer {
        id: checks
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (root.recovery && !root.repaired) {
                if (ReleaseInfo.loading || !ReleaseInfo.error) return;
                root.check(!ReleaseInfo.ready, "Invalid current metadata must not display a guessed version");
                root.check(root.findNamed(about, "releaseRetry").visible, "Error retry action");
                console.log("REPAIR_NEEDED");
                stop();
                return;
            }
            if (ReleaseInfo.loading || !ReleaseInfo.ready) return;
            root.check(!ReleaseInfo.error, ReleaseInfo.error);
            root.check(ReleaseInfo.tag === "beta-4", "Current tag");
            root.check(ReleaseInfo.displayName === "Beta 4", "Current name");
            root.check(ReleaseInfo.requiredQuickshell === "0.3.1", "Compatibility minimum");
            root.check(ReleaseInfo.releases.length === (root.recovery ? 15 : 16), "History count");
            root.check(ReleaseInfo.warnings.length === (root.recovery ? 1 : 0), "Invalid history warning");
            root.check(about.implicitHeight > 400 && about.width > 600, "About geometry");
            if (!root.picker) {
                root.picker = root.findNamed(about, "releasePicker");
                root.check(root.picker !== null, "Version selector");
                root.check(about.selectedRelease.tag === ReleaseInfo.tag, "Initial selection");
                root.picker.popup.open();
                return;
            }
            if (!root.inspectedPopup) {
                root.check(root.picker.popup.visible, "Open version menu");
                root.check(root.picker.popup.contentItem.count === ReleaseInfo.releases.length, "Rendered history choices");
                root.picker.popup.close();
                root.inspectedPopup = true;
            }
            if (root.selectedIndex >= 0) {
                const selected = ReleaseInfo.releases[root.selectedIndex];
                root.check(about.selectedRelease.tag === selected.tag, "History selection: " + selected.tag);
                root.check(about.selectedRelease.summary.length > 0, "Selected summary");
                root.check(about.selectedRelease.changes.length > 0, "Selected highlights");
                root.check(about.selectedRelease.notes.length > 0, "Selected notes");
                root.check(root.picker.currentIndex === root.selectedIndex, "Selector index");
            }
            root.selectedIndex++;
            if (root.selectedIndex < ReleaseInfo.releases.length) {
                root.picker.activated(root.selectedIndex);
                return;
            }
            stop();
            about.selectedTag = ReleaseInfo.tag;
            Qt.callLater(function() {
                root.check(about.selectedRelease.tag === "beta-4", "Return to active version");
                root.check(root.picker.currentIndex === 0, "Current version restored in selector");
                const screenshot = Quickshell.env("RUSTICQ_RELEASE_TEST_SCREENSHOT");
                if (screenshot) {
                    about.grabToImage(function(result) {
                        root.check(result.saveToFile(screenshot), "Save About preview");
                        console.log("TEST_PASSED");
                        Qt.quit();
                    });
                } else {
                    console.log("TEST_PASSED");
                    Qt.quit();
                }
            });
        }
    }
    Timer {
        interval: 12000
        running: true
        onTriggered: root.check(false, "Timed out waiting for release information")
    }
}
'''


def run_case(recovery=False):
    with tempfile.TemporaryDirectory(prefix='rusticq-release-ui-') as folder:
        base = Path(folder)
        source = base / 'source'
        for directory in ('config', 'assets'):
            shutil.copytree(ROOT / directory, source / directory)
        for relative in ('VERSION', 'scripts/rusticq-release.py', 'components/Icon.qml',
                         'modules/settings/SettingsSection.qml',
                         'modules/settings/pages/SettingsAboutPage.qml'):
            target = source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        for path in (ROOT / 'config/releases').glob('*.json'):
            for relative in json.loads(path.read_text())['notes']:
                target = source / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
        (source / 'shell.qml').write_text(QML)
        (source / 'user-settings.json').write_text('{}')
        runtime = base / 'runtime'
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=str(runtime),
                   XDG_STATE_HOME=str(base / 'state'), XDG_DATA_HOME=str(base / 'data'),
                   XDG_CACHE_HOME=str(base / 'cache'), HOME=str(base / 'home'),
                   RUSTICQ_RELEASE_TEST_RECOVERY='1' if recovery else '0',
                   RUSTICQ_RELEASE_TEST_SCREENSHOT='' if recovery else '/tmp/rusticq-beta4-about.png')
        saved = (source / 'config/releases/beta-4.json').read_text()
        if recovery:
            (source / 'config/releases/beta-4.json').write_text('{invalid')
            (source / 'config/releases/beta-3.json').write_text('{invalid historical manifest')
        process = subprocess.Popen(['qs', '-p', str(source), '--no-color'], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        lines = queue.Queue()

        def reader():
            for line in process.stdout:
                lines.put(line.rstrip())

        threading.Thread(target=reader, daemon=True).start()
        output = []
        passed = False
        deadline = time.monotonic() + 15
        try:
            while time.monotonic() < deadline:
                try:
                    line = lines.get(timeout=.2)
                except queue.Empty:
                    if process.poll() is not None:
                        break
                    continue
                output.append(line)
                if 'REPAIR_NEEDED' in line:
                    (source / 'config/releases/beta-4.json').write_text(saved)
                    reply = subprocess.run(['qs', 'ipc', '-p', str(source), 'call', 'release_test', 'retry'],
                                           env=env, capture_output=True, text=True, timeout=5)
                    assert reply.returncode == 0, reply.stdout + reply.stderr
                if 'TEST_PASSED' in line:
                    passed = True
                    break
                if any(error in line for error in ('TEST_FAILED', 'ReferenceError', 'TypeError', 'Binding loop')):
                    break
            assert passed, '\n'.join(output)
            assert process.wait(timeout=5) == 0, '\n'.join(output)
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
            process.stdout.close()


def main():
    if not shutil.which('qs'):
        raise SystemExit('Quickshell is required for this runtime check')
    run_case()
    run_case(recovery=True)
    print('PASS: About selects every documented version; broken current metadata shows an error and recovers on retry; broken history shows a warning')


if __name__ == '__main__':
    main()
