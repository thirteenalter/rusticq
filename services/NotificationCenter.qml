pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io

Singleton {
    id: root
    property var history: []
    property var toast: null
    property bool doNotDisturb: false
    property int unread: 0
    property int sequence: 0
    property string serverState: "checking"
    property string serverOwner: "Checking notification service…"
    property string serverAdvice: ""
    property int serverPid: 0
    readonly property bool receivesSystemNotifications: serverState === "owned"

    function refreshServerStatus() {
        if (!doctor.running)
            doctor.exec(["python3", Quickshell.shellPath("scripts/rustiq-notification-doctor.py"), String(Quickshell.processId)]);
    }

    function plain(text) {
        return String(text || "").replace(/<[^>]*>/g, "").trim();
    }

    function initials(app) {
        const src = plain(app) || "App";
        const words = src.split(/\s+/).filter(Boolean);
        if (!words.length) return "A";
        if (words.length === 1) return words[0].charAt(0).toUpperCase();
        return (words[0].charAt(0) + words[1].charAt(0)).toUpperCase();
    }

    function normalizedImage(source) {
        const src = String(source || "").trim();
        if (!src) return "";
        if (src.indexOf("://") !== -1 || src.indexOf("qrc:/") === 0 || src.indexOf("image://") === 0)
            return src;
        if (src.charAt(0) === "/") return "file://" + src;
        return src;
    }

    function detectKind(appName, title, body, image) {
        const haystack = (String(appName || "") + " " + String(title || "") + " " + String(body || "")).toLowerCase();
        if (haystack.indexOf("screenshot") !== -1 || haystack.indexOf("clipboard") !== -1) return "screenshot";
        if (haystack.indexOf("download") !== -1 || haystack.indexOf("saved") !== -1) return "file";
        if (haystack.indexOf("warning") !== -1 || haystack.indexOf("error") !== -1 || haystack.indexOf("failed") !== -1) return "alert";
        return "generic";
    }

    function glyphFor(kind) {
        switch (kind) {
        case "screenshot": return "\ue3b0";
        case "file": return "\ue2c7";
        case "alert": return "\ue002";
        default: return "\ue7f4";
        }
    }

    function tagFor(kind) {
        switch (kind) {
        case "screenshot": return "Screenshot";
        case "file": return "Saved";
        case "alert": return "Alert";
        default: return "Notification";
        }
    }

    function previewNotification() {
        const sample = {
            serial: ++sequence,
            id: -1,
            app: "RusticQ Preview",
            appInitials: "RQ",
            appIcon: "",
            title: "Notification UI preview",
            body: "Cleaner typography, better spacing and optional screenshot previews now match the rest of RusticQ.",
            when: Qt.formatTime(new Date(), "HH:mm"),
            image: "",
            urgency: 1,
            kind: "generic",
            glyph: "\ue7f4",
            tag: "Preview",
            reference: null,
            preview: true
        };
        history = [sample].concat(history).slice(0, 40);
        unread = Math.min(40, unread + 1);
        if (!doNotDisturb) {
            toast = sample;
            toastTimer.restart();
        }
    }

    Process {
        id: doctor
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text.trim());
                    root.serverState = result.state || "error";
                    root.serverOwner = result.owner || "Unknown";
                    root.serverPid = result.pid || 0;
                    root.serverAdvice = result.suggestion || "";
                } catch (e) {
                    root.serverState = "error";
                    root.serverAdvice = "Unable to read notification service diagnostic output.";
                }
            }
        }
    }

    Timer {
        interval: 7000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshServerStatus()
    }

    function receive(n) {
        n.tracked = true;
        if (n.lastGeneration) return;
        const appName = n.appName || "Application";
        const title = plain(n.summary) || "Notification";
        const body = plain(n.body);
        const image = normalizedImage(n.image || "");
        const kind = detectKind(appName, title, body, image);
        const entry = {
            serial: ++sequence,
            id: n.id,
            app: appName,
            appInitials: initials(appName),
            appIcon: n.appIcon || "",
            title: title,
            body: body,
            when: Qt.formatTime(new Date(), "HH:mm"),
            image: image,
            urgency: n.urgency !== undefined ? n.urgency : 1,
            kind: kind,
            glyph: glyphFor(kind),
            tag: tagFor(kind),
            reference: n
        };
        history = [entry].concat(history).slice(0, 40);
        unread = Math.min(40, unread + 1);
        if (!doNotDisturb) {
            toast = entry;
            toastTimer.restart();
        }
    }

    function dismiss(serial) {
        const item = history.find(e => e.serial === serial);
        if (item && item.reference) {
            try { item.reference.dismiss(); } catch (e) {}
        }
        history = history.filter(e => e.serial !== serial);
        if (toast && toast.serial === serial) toast = null;
    }

    function clear() {
        for (const item of history) {
            if (item.reference) {
                try { item.reference.dismiss(); } catch (e) {}
            }
        }
        history = [];
        unread = 0;
        toast = null;
    }

    function markRead() { unread = 0; }

    Timer { id: toastTimer; interval: 6200; onTriggered: root.toast = null }

    NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: false
        imageSupported: true
        onNotification: notification => root.receive(notification)
    }
}
