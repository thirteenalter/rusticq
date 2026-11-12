pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// VERSION selects the active manifest. Load the local catalog once per shell.
Singleton {
    id: root
    property var current: ({})
    property var releases: []
    property var warnings: []
    property string error: ""
    readonly property bool loading: reader.running
    readonly property bool ready: Boolean(current.tag)
    readonly property string tag: current.tag || "unknown"
    readonly property string displayName: current.name || (loading ? "Loading version…" : "Version unavailable")
    readonly property string channel: current.channel || ""
    readonly property int betaNumber: channel === "beta" ? current.number : 0
    readonly property string requiredQuickshell: current.minimumQuickshell || "unavailable"

    function refresh() {
        if (reader.running) return;
        current = ({});
        releases = [];
        warnings = [];
        error = "";
        reader.running = true;
    }

    Process {
        id: reader
        command: ["python3", Quickshell.shellPath("scripts/rusticq-release.py"), "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(this.text);
                    if (!value.ok) {
                        root.error = value.error || "Unable to load release information.";
                        return;
                    }
                    root.current = value.result.current;
                    root.releases = value.result.releases;
                    root.warnings = value.result.warnings;
                    root.error = "";
                } catch (exception) {
                    root.error = "Unable to read release information.";
                }
            }
        }
        onExited: (code, status) => {
            if ((code !== 0 || !root.ready) && !root.error)
                root.error = "Release information is unavailable. Try reloading it.";
        }
    }

    Component.onCompleted: refresh()
}
