pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool active: false
    property string outputFile: ""
    readonly property string helper: Quickshell.shellPath("scripts/rustiq-record.py")

    function refresh() {
        if (!statusProcess.running)
            statusProcess.exec(["python3", helper, "status"]);
    }

    function action(command) {
        if (["start-screen", "start-region", "start-audio", "stop", "folder", "portal-check"].indexOf(command) < 0)
            return;
        Quickshell.execDetached(["python3", helper, command]);
        if (command === "stop") active = false;
        refreshLater.restart();
    }
    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text.trim());
                    root.active = result.active === true;
                    root.outputFile = result.file || "";
                } catch (e) {
                    root.active = false;
                    root.outputFile = "";
                }
            }
        }
    }
    Timer { id: refreshLater; interval: 1500; onTriggered: root.refresh() }
    Timer { interval: 2500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
