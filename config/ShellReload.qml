pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One reload coordinator per running shell; never starts another instance.
Singleton {
    id: root
    property bool updating: false
    property bool previousWatchFiles: true
    readonly property bool pending: reloadDelay.running
    property string message: ""
    property bool reloadFailed: false
    function beginUpdate() {
        if (updating) return;
        previousWatchFiles = Quickshell.watchFiles;
        Quickshell.watchFiles = false;
        updating = true;
        reloadDelay.stop();
        message = "";
        reloadFailed = false;
    }
    function finishUpdate(success, path) {
        if (updating) Quickshell.watchFiles = previousWatchFiles;
        updating = false;
        if (success) reloadPath(path);
    }
    function requestReload() {
        if (updating) return;
        message = "Configuration ready. Reloading shell…";
        reloadFailed = false;
        reloadDelay.restart();
    }
    function reloadPath(path) {
        if (!path || path === Quickshell.shellDir) {
            requestReload();
        } else if (!remoteReload.running) {
            remoteReload.exec(["qs", "ipc", "-p", path, "call", "rusticq", "reload"]);
        }
    }
    Timer {
        id: reloadDelay
        interval: 650
        onTriggered: Quickshell.reload(false)
    }
    Process {
        id: remoteReload
        onExited: (code, status) => {
            root.reloadFailed = code !== 0;
            root.message = code === 0 ? "Installed shell is reloading." : "Files installed. No running shell accepted reload at the updated path; they will load when that shell starts.";
        }
    }
    Connections {
        target: Quickshell
        function onReloadFailed(errorString) {
            root.reloadFailed = true;
            root.message = "Reload failed; the previous shell is still running. " + errorString;
        }
    }
}
