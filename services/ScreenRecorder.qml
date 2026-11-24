pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool active: false
    property string outputFile: ""
    property bool refreshQueued: false
    readonly property string helper: Quickshell.shellPath("scripts/rustiq-record.py")

    function refresh() {
        if (statusProcess.running) { refreshQueued = true; return; }
        statusProcess.exec(["python3", helper, "status"]);
    }

    function action(command) {
        if (["start-screen", "start-region", "start-audio", "stop", "folder", "portal-check"].indexOf(command) < 0)
            return;
        Quickshell.execDetached(["python3", helper, command]);
        refreshLater.restart();
    }
    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text.trim());
                    root.active = result.ok === true && result.active === true;
                    root.outputFile = root.active && typeof result.file === "string" ? result.file : "";
                } catch (e) {
                    root.active = false;
                    root.outputFile = "";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) { root.active = false; root.outputFile = ""; }
            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(root.refresh);
            }
        }
    }
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/rusticq-recorder/active.json" : ""
        watchChanges: true
        preload: false
        printErrors: false
        onFileChanged: root.refresh()
    }
    Timer { id: refreshLater; interval: 1500; onTriggered: root.refresh() }
    Timer { interval: 2500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
